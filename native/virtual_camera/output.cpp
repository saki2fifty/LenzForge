#include "common.h"
#include "color.h"
#include "gpu_transport.h"
namespace lenzcam {
// The main/render thread only hands off a frame. Conversion and publication run
// in this worker, with one replaceable pending frame instead of a growing FIFO.
class Output : public Tracked {
    std::thread worker;
    std::mutex mutex;
    std::condition_variable changed;
    bool quit = false, pending = false, converting = false;
    const std::wstring owner_sid = current_sid();
    const bool force_cpu = GetEnvironmentVariableW(L"LENZFORGE_CAMERA_CPU",nullptr,0)!=0;
    std::vector<uint8_t> inbox, working;
    std::atomic<int> state{1}, error{0};
    std::atomic<bool> consumer{false};
    std::atomic<uint64_t> sent{0}, replaced{0};
    std::atomic<double> conversion_ms{0};
    SharedFrames* frames = nullptr;
    HANDLE mapping = nullptr, exclusive = nullptr;
    ComPtr<IMFVirtualCamera> camera;
    GUID session{};
    std::unique_ptr<GpuPublisher> gpu;
    GUID gpu_session{};
    std::atomic<bool> gpu_active{false};
    HRESULT initialize(const std::wstring& sid) {
        if (sid.empty()) return E_ACCESSDENIED;
        exclusive = CreateMutexW(nullptr, FALSE, (L"Local\\LenzForge.Camera.Writer." + sid).c_str());
        if (!exclusive) return HRESULT_FROM_WIN32(GetLastError());
        // A named handle is kept for the whole session; do not wait on another viewer.
        if (GetLastError() == ERROR_ALREADY_EXISTS) return HRESULT_FROM_WIN32(ERROR_BUSY);
        ComPtr<IClassFactory> factory;
        LF_CHECK(CoGetClassObject(source_clsid, CLSCTX_INPROC_SERVER, nullptr, IID_PPV_ARGS(&factory)));
        LF_CHECK(MFCreateVirtualCamera(MFVirtualCameraType_SoftwareCameraSource, MFVirtualCameraLifetime_Session,
            MFVirtualCameraAccess_CurrentUser, L"LenzForge", clsid_text, nullptr, 0, &camera));
        LF_CHECK(camera->SetString(owner_sid_key, sid.c_str()));
        LF_CHECK(CoCreateGuid(&session));
        LF_CHECK(camera->SetGUID(session_key,session));
        LF_CHECK(camera->Start(nullptr));
        return S_OK;
    }
    void publish(const uint8_t* rgba) {
        auto began = std::chrono::steady_clock::now();
        const LONG index = static_cast<LONG>(sent.load() % 3);
        auto& slot = frames->slots[index];
        LONG64 previous = InterlockedCompareExchange64(&slot.sequence, 0, 0);
        LONG64 writing = (previous + 1) | 1;
        InterlockedExchange64(&slot.sequence, writing);
        rgba_to_nv12(rgba, slot.nv12, width, height);
        slot.timestamp_ms = GetTickCount64();
        InterlockedExchange64(&slot.sequence, writing + 1);
        InterlockedExchange(&frames->published, index);
        InterlockedExchange(&frames->gpu_published,-1);
        InterlockedExchange(&frames->producing, 1);
        ++sent;
        conversion_ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - began).count();
    }
    void run() {
        HRESULT co = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
        HRESULT mf = SUCCEEDED(co) ? MFStartup(MF_VERSION, MFSTARTUP_NOSOCKET) : co;
        const auto& sid = owner_sid;
        HRESULT hr = SUCCEEDED(mf) ? initialize(sid) : mf;
        error = hr;
        state = SUCCEEDED(hr) ? 2 : 3;
        if (SUCCEEDED(hr)) {
            std::unique_lock lock(mutex);
            while (!quit) {
                if (!mapping) {
                    mapping = OpenFileMappingW(FILE_MAP_ALL_ACCESS, FALSE, mapping_name(sid,session).c_str());
                    if (mapping) frames = static_cast<SharedFrames*>(MapViewOfFile(mapping, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(SharedFrames)));
                    if (mapping && (!frames || !valid(frames))) { error = E_UNEXPECTED; state = 3; break; }
                }
                uint64_t tick = frames ? static_cast<uint64_t>(InterlockedCompareExchange64(&frames->consumer_tick,0,0)) : 0;
                auto now = GetTickCount64();
                consumer = tick && tick <= now && now - tick < 250;
                if (pending && consumer) {
                    working.swap(inbox); pending = false; converting = true;
                    lock.unlock(); publish(working.data()); lock.lock(); converting = false;
                } else if (pending) pending = false;
                changed.wait_for(lock, std::chrono::milliseconds(50), [&] { return quit || pending; });
            }
        }
        consumer = false;
        { std::lock_guard guard(mutex);
          if (frames) { InterlockedExchange(&frames->producing, 0); UnmapViewOfFile(frames); frames = nullptr; } }
        if (mapping) { CloseHandle(mapping); mapping = nullptr; }
        if (camera) { camera->Stop(); camera->Shutdown(); camera.Reset(); }
        if (exclusive) { CloseHandle(exclusive); exclusive = nullptr; }
        if (SUCCEEDED(mf)) MFShutdown();
        if (SUCCEEDED(co)) CoUninitialize();
    }
public:
    void reset_texture() { gpu.reset(); gpu_active=false; }
    bool submit_texture(uint32_t texture) {
        if (force_cpu) return false;
        std::lock_guard guard(mutex);
        if (quit || converting || state!=2 || !consumer || !frames || !InterlockedCompareExchange(&frames->gpu_ready,0,0)) {
            gpu_active=false;
            return false;
        }
        if (!gpu || gpu_session!=frames->gpu_session) { gpu=std::make_unique<GpuPublisher>(); gpu_session=frames->gpu_session; }
        int submitted=gpu->submit(frames,owner_sid,texture);
        gpu_active=submitted!=0;
        if (gpu_active) {
            pending=false;
            if (submitted==1) {
                // GPU timestamps reuse slot metadata; never let CPU fallback
                // interpret an older NV12 payload as a fresh GPU publication.
                InterlockedExchange(&frames->published,-1);
                InterlockedExchange(&frames->producing,1); ++sent;
            }
            else ++replaced;
            conversion_ms=0;
        }
        return gpu_active;
    }
    Output() : inbox(pixels*4), working(pixels*4), worker() { worker = std::thread(&Output::run, this); }
    ~Output() {
        { std::lock_guard guard(mutex); quit = true; }
        changed.notify_one();
        if (worker.joinable()) worker.join();
    }
    bool submit(const uint8_t* data, uint32_t length) {
        if (!data || length != pixels * 4 || state != 2 || !consumer) return false;
        std::lock_guard guard(mutex);
        if (quit) return false;
        if (pending) ++replaced;
        memcpy(inbox.data(), data, length); pending = true;
        changed.notify_one(); return true;
    }
    void status(Status* out) {
        if (!out || out->size != sizeof(Status)) return;
        out->state = state; out->error = error; out->consumer = consumer;
        out->sent = sent; out->replaced = replaced; out->conversion_ms = conversion_ms;
        out->gpu = gpu_active;
        { std::lock_guard guard(mutex); out->gpu_error = frames ? frames->gpu_error : 0; }
    }
};
}
extern "C" __declspec(dllexport) void* __cdecl LFCameraStart() {
    try { return new lenzcam::Output(); } catch (...) { return nullptr; }
}
extern "C" __declspec(dllexport) void __cdecl LFCameraStop(void* output) { delete static_cast<lenzcam::Output*>(output); }
extern "C" __declspec(dllexport) bool __cdecl LFCameraTexture(void* output,uint32_t texture) {
    return output && static_cast<lenzcam::Output*>(output)->submit_texture(texture);
}
extern "C" __declspec(dllexport) void __cdecl LFCameraResetTexture(void* output) {
    if (output) static_cast<lenzcam::Output*>(output)->reset_texture();
}
extern "C" __declspec(dllexport) bool __cdecl LFCameraSubmit(void* output, const uint8_t* rgba, uint32_t length) {
    return output && static_cast<lenzcam::Output*>(output)->submit(rgba, length);
}
extern "C" __declspec(dllexport) void __cdecl LFCameraStatus(void* output, lenzcam::Status* status) {
    if (output) static_cast<lenzcam::Output*>(output)->status(status);
}
