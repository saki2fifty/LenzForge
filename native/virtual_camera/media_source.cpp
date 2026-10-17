#include "media_source.h"
namespace lenzcam {
static HRESULT stream_attributes(IMFAttributes* a) {
    LF_CHECK(a->SetGUID(MF_DEVICESTREAM_STREAM_CATEGORY, PINNAME_VIDEO_CAPTURE));
    LF_CHECK(a->SetUINT32(MF_DEVICESTREAM_STREAM_ID, 0));
    LF_CHECK(a->SetUINT32(MF_DEVICESTREAM_FRAMESERVER_SHARED, TRUE));
    return a->SetUINT32(MF_DEVICESTREAM_ATTRIBUTE_FRAMESOURCE_TYPES, MFFrameSourceTypes_Color);
}
static HRESULT media_type(UINT32 fps, IMFMediaType** out) {
    ComPtr<IMFMediaType> type;
    LF_CHECK(MFCreateMediaType(&type));
    LF_CHECK(type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video));
    LF_CHECK(type->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_NV12));
    LF_CHECK(type->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive));
    LF_CHECK(type->SetUINT32(MF_MT_ALL_SAMPLES_INDEPENDENT, TRUE));
    LF_CHECK(type->SetUINT32(MF_MT_FIXED_SIZE_SAMPLES, TRUE));
    LF_CHECK(type->SetUINT32(MF_MT_SAMPLE_SIZE, bytes));
    LF_CHECK(type->SetUINT32(MF_MT_DEFAULT_STRIDE, width));
    LF_CHECK(type->SetUINT32(MF_MT_YUV_MATRIX, MFVideoTransferMatrix_BT601));
    LF_CHECK(type->SetUINT32(MF_MT_VIDEO_NOMINAL_RANGE, MFNominalRange_16_235));
    LF_CHECK(MFSetAttributeSize(type.Get(), MF_MT_FRAME_SIZE, width, height));
    LF_CHECK(MFSetAttributeRatio(type.Get(), MF_MT_FRAME_RATE, fps, 1));
    LF_CHECK(MFSetAttributeRatio(type.Get(), MF_MT_PIXEL_ASPECT_RATIO, 1, 1));
    return type.CopyTo(out);
}
HRESULT Stream::initialize(IMFMediaSource* source, const std::wstring& sid, const GUID& session, bool local_test) {
    LF_CHECK(MFCreateEventQueue(&events));
    LF_CHECK(MFCreateAttributes(&attributes, 4));
    LF_CHECK(stream_attributes(attributes.Get()));
    ComPtr<IMFMediaType> fast, standard;
    LF_CHECK(media_type(60, &fast));
    LF_CHECK(media_type(30, &standard));
    IMFMediaType* types[] = {fast.Get(), standard.Get()};
    LF_CHECK(MFCreateStreamDescriptor(0, 2, types, &descriptor));
    LF_CHECK(stream_attributes(descriptor.Get()));
    ComPtr<IMFMediaTypeHandler> handler;
    LF_CHECK(descriptor->GetMediaTypeHandler(&handler));
    LF_CHECK(handler->SetCurrentMediaType(fast.Get()));
    owner_sid = sid;
    allow_gpu = !local_test;
    transport_name = local_test ? L"Local\\LenzForge.Camera.Test." + std::to_wstring(GetCurrentProcessId()) : mapping_name(sid,session);
    wake = CreateEventW(nullptr,FALSE,FALSE,nullptr);
    if (!wake) return HRESULT_FROM_WIN32(GetLastError());
    parent = source;
    return S_OK;
}
HRESULT Stream::open_transport() {
    if (frames) return S_OK;
    // Windows also instantiates the source in the unelevated publisher while
    // discovering its formats. Only the streaming Frame Server in session 0
    // creates the global transport; metadata queries need no global privilege.
    // Only this camera's user, SYSTEM and Local Service can access its transport.
    PSID parsed = nullptr;
    if (!ConvertStringSidToSidW(owner_sid.c_str(), &parsed)) return E_INVALIDARG;
    LocalFree(parsed);
    std::wstring acl = L"D:P(A;;GA;;;SY)(A;;GA;;;LS)(A;;GA;;;" + owner_sid + L")";
    PSECURITY_DESCRIPTOR security = nullptr;
    if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(acl.c_str(), SDDL_REVISION_1, &security, nullptr)) return HRESULT_FROM_WIN32(GetLastError());
    SECURITY_ATTRIBUTES sa{sizeof(sa), security, FALSE};
    mapping = CreateFileMappingW(INVALID_HANDLE_VALUE, &sa, PAGE_READWRITE, 0, sizeof(SharedFrames), transport_name.c_str());
    DWORD error = GetLastError();
    LocalFree(security);
    if (!mapping) return HRESULT_FROM_WIN32(error);
    frames = static_cast<SharedFrames*>(MapViewOfFile(mapping, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(SharedFrames)));
    if (!frames) {
        HRESULT hr = HRESULT_FROM_WIN32(GetLastError());
        CloseHandle(mapping); mapping = nullptr;
        return hr;
    }
    if (error != ERROR_ALREADY_EXISTS) {
        frames->version = 1; frames->frame_width = width; frames->frame_height = height;
        frames->published = -1;
        MemoryBarrier();
        frames->signature = magic;
    }
    if (!valid(frames)) return E_UNEXPECTED;
    snapshot.resize(bytes);
    return S_OK;
}
HRESULT Stream::GetMediaSource(IMFMediaSource** out) {
    std::lock_guard guard(mutex);
    return shutdown ? MF_E_SHUTDOWN : parent.CopyTo(out);
}
HRESULT Stream::GetStreamDescriptor(IMFStreamDescriptor** out) {
    std::lock_guard guard(mutex);
    return shutdown ? MF_E_SHUTDOWN : descriptor.CopyTo(out);
}
HRESULT Stream::set_device_manager(IUnknown* manager) {
    std::lock_guard guard(mutex);
    if (shutdown) return MF_E_SHUTDOWN;
    if (state != MF_STREAM_STATE_STOPPED) return MF_E_INVALID_STATE_TRANSITION;
    if (device_manager.Get() != manager) {
        if (frames) InterlockedExchange(&frames->gpu_ready,0);
        gpu.reset();
        device_manager=manager;
    }
    return S_OK;
}
HRESULT Stream::start(IMFMediaType* type, bool event) {
    std::lock_guard guard(mutex);
    if (shutdown) return MF_E_SHUTDOWN;
    ComPtr<IMFMediaTypeHandler> handler;
    LF_CHECK(descriptor->GetMediaTypeHandler(&handler));
    ComPtr<IMFMediaType> selected;
    if (type) selected = type; else LF_CHECK(handler->GetCurrentMediaType(&selected));
    UINT32 w = 0, h = 0, numerator = 0, denominator = 0;
    GUID subtype{};
    LF_CHECK(selected->GetGUID(MF_MT_SUBTYPE, &subtype));
    LF_CHECK(MFGetAttributeSize(selected.Get(), MF_MT_FRAME_SIZE, &w, &h));
    LF_CHECK(MFGetAttributeRatio(selected.Get(), MF_MT_FRAME_RATE, &numerator, &denominator));
    if (w != width || h != height || subtype != MFVideoFormat_NV12 || denominator != 1 || (numerator != 30 && numerator != 60)) return MF_E_INVALIDMEDIATYPE;
    LF_CHECK(open_transport());
    if (state == MF_STREAM_STATE_RUNNING) {
        if (duration != 10000000 / numerator) return MF_E_INVALID_STATE_TRANSITION;
    } else {
        if (allocator) allocator->UninitializeSampleAllocator();
        LF_CHECK(MFCreateVideoSampleAllocatorEx(IID_PPV_ARGS(&allocator)));
        if (device_manager) LF_CHECK(allocator->SetDirectXManager(device_manager.Get()));
        LF_CHECK(allocator->InitializeSampleAllocator(8, selected.Get()));
        if (allow_gpu && !gpu) {
            gpu = std::make_unique<GpuReceiver>();
            HRESULT result=gpu->initialize(frames,owner_sid,device_manager.Get());
            InterlockedExchange(&frames->gpu_error,result);
            if (FAILED(result)) gpu.reset();
        }
    }
    LF_CHECK(handler->SetCurrentMediaType(selected.Get()));
    duration = 10000000 / numerator;
    state = MF_STREAM_STATE_RUNNING;
    if (!worker.joinable()) worker = std::thread(&Stream::run, this);
    if (event) LF_CHECK(events->QueueEventParamVar(MEStreamStarted, GUID_NULL, S_OK, nullptr));
    changed.notify_one();
    return S_OK;
}
HRESULT Stream::stop(bool event) {
    std::lock_guard guard(mutex);
    if (shutdown) return MF_E_SHUTDOWN;
    state = MF_STREAM_STATE_STOPPED;
    requests.clear();
    SetEvent(wake);
    changed.notify_one();
    return event ? events->QueueEventParamVar(MEStreamStopped, GUID_NULL, S_OK, nullptr) : S_OK;
}
HRESULT Stream::close() {
    {
        std::lock_guard guard(mutex);
        if (shutdown) return S_OK;
        shutdown = quit = true;
        state = MF_STREAM_STATE_STOPPED;
        requests.clear();
        if (events) events->Shutdown();
        events.Reset();
        parent.Reset();
    }
    changed.notify_one();
    if (wake) SetEvent(wake);
    if (worker.joinable()) worker.join();
    if (allocator) allocator->UninitializeSampleAllocator();
    allocator.Reset();
    if (frames) InterlockedExchange(&frames->gpu_ready,0);
    gpu.reset();
    if (frames) { UnmapViewOfFile(frames); frames = nullptr; }
    if (mapping) { CloseHandle(mapping); mapping = nullptr; }
    if (wake) { CloseHandle(wake); wake = nullptr; }
    return S_OK;
}
HRESULT Stream::RequestSample(IUnknown* token) {
    std::lock_guard guard(mutex);
    if (shutdown) return MF_E_SHUTDOWN;
    if (state != MF_STREAM_STATE_RUNNING) return MF_E_INVALIDREQUEST;
    if (requests.size() >= 8) return MF_E_NOTACCEPTING;
    requests.emplace_back(token);
    changed.notify_one();
    return S_OK;
}
HRESULT Stream::SetStreamState(MF_STREAM_STATE next) {
    if (next == MF_STREAM_STATE_RUNNING) return start(nullptr, false);
    if (next == MF_STREAM_STATE_STOPPED) return stop(false);
    std::lock_guard guard(mutex);
    if (shutdown) return MF_E_SHUTDOWN;
    if (next != MF_STREAM_STATE_PAUSED || state != MF_STREAM_STATE_RUNNING) return MF_E_INVALID_STATE_TRANSITION;
    state = next; requests.clear(); SetEvent(wake); changed.notify_one();
    return S_OK;
}
HRESULT Stream::GetStreamState(MF_STREAM_STATE* out) {
    if (!out) return E_POINTER;
    std::lock_guard guard(mutex);
    if (shutdown) return MF_E_SHUTDOWN;
    *out = state; return S_OK;
}
void Stream::run() {
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    HANDLE timer = CreateWaitableTimerExW(nullptr,nullptr,CREATE_WAITABLE_TIMER_HIGH_RESOLUTION,TIMER_ALL_ACCESS);
    if (!timer) timer = CreateWaitableTimerW(nullptr,FALSE,nullptr);
    auto next = std::chrono::steady_clock::now();
    std::unique_lock lock(mutex);
    while (!quit) {
        changed.wait(lock, [&] { return quit || (state == MF_STREAM_STATE_RUNNING && !requests.empty()); });
        if (quit) break;
        auto remaining = std::chrono::duration_cast<std::chrono::nanoseconds>(next-std::chrono::steady_clock::now()).count()/100;
        if (remaining > 0 && timer) {
            LARGE_INTEGER due; due.QuadPart = -remaining;
            HANDLE waits[] = {wake,timer};
            SetWaitableTimer(timer,&due,0,nullptr,nullptr,FALSE);
            lock.unlock();
            DWORD result = WaitForMultipleObjects(2,waits,FALSE,INFINITE);
            lock.lock();
            if (result != WAIT_OBJECT_0+1 || quit || state != MF_STREAM_STATE_RUNNING) continue;
        }
        auto token = requests.front(); requests.pop_front();
        HRESULT hr = deliver(token.Get());
        if (FAILED(hr) && events) events->QueueEventParamVar(MEError, GUID_NULL, hr, nullptr);
        // Never catch up by sending a burst of old frames.
        next = std::max(next + std::chrono::nanoseconds(duration * 100),std::chrono::steady_clock::now());
    }
    lock.unlock();
    if (timer) CloseHandle(timer);
    CoUninitialize();
}
HRESULT Stream::deliver(IUnknown* token) {
    auto now = GetTickCount64();
    InterlockedExchange64(&frames->consumer_tick, static_cast<LONG64>(now));
    ComPtr<IMFSample> sample;
    LF_CHECK(allocator->AllocateSample(&sample));
    HRESULT copied = gpu && InterlockedCompareExchange(&frames->producing,0,0) ? gpu->copy(frames,sample.Get()) : S_FALSE;
    if (FAILED(copied)) {
        InterlockedExchange(&frames->gpu_error,copied);
        InterlockedExchange(&frames->gpu_ready,0); // Device loss falls back to CPU publication.
        gpu.reset();
    }
    bool on_gpu = copied == S_OK;
    if (!on_gpu) {
    bool fresh = false;
    if (InterlockedCompareExchange(&frames->producing, 0, 0)) {
        for (int retry = 0; retry < 2; ++retry) {
            LONG index = InterlockedCompareExchange(&frames->published, 0, 0);
            if (index < 0 || index >= 3) break;
            auto& slot = frames->slots[index];
            LONG64 sequence = InterlockedCompareExchange64(&slot.sequence, 0, 0);
            if (!sequence || (sequence & 1)) continue;
            auto stamp = slot.timestamp_ms;
            if (stamp > now || now - stamp > 500) break;
            memcpy(snapshot.data(), slot.nv12, bytes);
            MemoryBarrier();
            if (sequence == InterlockedCompareExchange64(&slot.sequence, 0, 0)) { fresh = true; break; }
        }
    }
    if (!fresh) { memset(snapshot.data(), 16, pixels); memset(snapshot.data() + pixels, 128, pixels / 2); }
    ComPtr<IMFMediaBuffer> buffer;
    ComPtr<IMF2DBuffer2> plane;
    LF_CHECK(sample->GetBufferByIndex(0, &buffer));
    LF_CHECK(buffer.As(&plane));
    BYTE* scan = nullptr; BYTE* start = nullptr; LONG stride = 0; DWORD length = 0;
    LF_CHECK(plane->Lock2DSize(MF2DBuffer_LockFlags_Write, &scan, &stride, &start, &length));
    HRESULT hr = S_OK;
    if (stride < static_cast<LONG>(width) || length < static_cast<uint64_t>(stride) * height * 3 / 2) hr = E_UNEXPECTED;
    else for (uint32_t y = 0; y < height * 3 / 2; ++y) memcpy(scan + y * stride, snapshot.data() + y * width, width);
    plane->Unlock2D();
    LF_CHECK(hr);
    }
    LF_CHECK(sample->SetSampleTime(MFGetSystemTime()));
    LF_CHECK(sample->SetSampleDuration(duration));
    if (token) LF_CHECK(sample->SetUnknown(MFSampleExtension_Token, token));
    else sample->DeleteItem(MFSampleExtension_Token);
    return events->QueueEventParamUnk(MEMediaSample, GUID_NULL, S_OK, sample.Get());
}
HRESULT Source::initialize(IMFAttributes* activation, bool local_test) {
    LF_CHECK(MFCreateAttributes(&attributes, 8));
    LF_CHECK(activation->CopyAllItems(attributes.Get()));
    wchar_t sid[192]{};
    LF_CHECK(attributes->GetString(owner_sid_key, sid, 192, nullptr));
    GUID session{};
    LF_CHECK(attributes->GetGUID(session_key,&session));
    if (session == GUID_NULL) return E_INVALIDARG;
    LF_CHECK(MFCreateEventQueue(&events));
    stream = Make<Stream>();
    if (!stream) return E_OUTOFMEMORY;
    HRESULT hr = stream->initialize(this, sid, session, local_test);
    if (FAILED(hr)) { stream->close(); stream.Reset(); return hr; }
    IMFStreamDescriptor* descriptions[] = {stream->descriptor.Get()};
    LF_CHECK(MFCreatePresentationDescriptor(1, descriptions, &descriptor));
    LF_CHECK(descriptor->SelectStream(0));
    ComPtr<IMFSensorProfileCollection> profiles;
    ComPtr<IMFSensorProfile> profile;
    LF_CHECK(MFCreateSensorProfileCollection(&profiles));
    LF_CHECK(MFCreateSensorProfile(KSCAMERAPROFILE_Legacy, 0, nullptr, &profile));
    LF_CHECK(profile->AddProfileFilter(0, L"((RES==;FRT<=60,1;SUT==))"));
    LF_CHECK(profiles->AddProfile(profile.Get()));
    return attributes->SetUnknown(MF_DEVICEMFT_SENSORPROFILE_COLLECTION, profiles.Get());
}
HRESULT Source::GetCharacteristics(DWORD* out) {
    if (!out) return E_POINTER;
    std::lock_guard guard(mutex);
    if (shutdown) return MF_E_SHUTDOWN;
    *out = MFMEDIASOURCE_IS_LIVE; return S_OK;
}
HRESULT Source::CreatePresentationDescriptor(IMFPresentationDescriptor** out) {
    std::lock_guard guard(mutex);
    return shutdown ? MF_E_SHUTDOWN : descriptor->Clone(out);
}
HRESULT Source::Start(IMFPresentationDescriptor* pd, const GUID* format, const PROPVARIANT* position) {
    if (!pd || !position) return E_INVALIDARG;
    if (format && *format != GUID_NULL) return MF_E_UNSUPPORTED_TIME_FORMAT;
    if (position->vt != VT_EMPTY && !(position->vt == VT_I8 && position->hVal.QuadPart == 0)) return MF_E_INVALIDREQUEST;
    std::lock_guard guard(mutex);
    if (shutdown) return MF_E_SHUTDOWN;
    DWORD count = 0, id = 0; BOOL selected = FALSE;
    ComPtr<IMFStreamDescriptor> desc;
    ComPtr<IMFMediaTypeHandler> handler;
    ComPtr<IMFMediaType> type;
    LF_CHECK(pd->GetStreamDescriptorCount(&count));
    if (count != 1) return E_INVALIDARG;
    LF_CHECK(pd->GetStreamDescriptorByIndex(0, &selected, &desc));
    LF_CHECK(desc->GetStreamIdentifier(&id));
    if (!selected || id != 0) return E_INVALIDARG;
    LF_CHECK(desc->GetMediaTypeHandler(&handler));
    LF_CHECK(handler->GetCurrentMediaType(&type));
    LF_CHECK(stream->start(type.Get(), false));
    LF_CHECK(events->QueueEventParamUnk(announced ? MEUpdatedStream : MENewStream, GUID_NULL, S_OK, static_cast<IMFMediaStream2*>(stream.Get())));
    announced = true;
    LF_CHECK(stream->QueueEvent(MEStreamStarted, GUID_NULL, S_OK, nullptr));
    return events->QueueEventParamVar(MESourceStarted, GUID_NULL, S_OK, nullptr);
}
HRESULT Source::Stop() {
    std::lock_guard guard(mutex);
    if (shutdown) return MF_E_SHUTDOWN;
    LF_CHECK(stream->stop());
    return events->QueueEventParamVar(MESourceStopped, GUID_NULL, S_OK, nullptr);
}
HRESULT Source::Shutdown() {
    ComPtr<Stream> closing;
    {
        std::lock_guard guard(mutex);
        if (shutdown) return MF_E_SHUTDOWN;
        shutdown = true;
        if (events) events->Shutdown();
        events.Reset(); closing = stream; stream.Reset();
    }
    if (closing) closing->close();
    return S_OK;
}
HRESULT Source::GetSourceAttributes(IMFAttributes** out) {
    std::lock_guard guard(mutex);
    return shutdown ? MF_E_SHUTDOWN : attributes.CopyTo(out);
}
HRESULT Source::GetStreamAttributes(DWORD id, IMFAttributes** out) {
    std::lock_guard guard(mutex);
    if (shutdown) return MF_E_SHUTDOWN;
    return id == 0 ? stream->attributes.CopyTo(out) : MF_E_INVALIDSTREAMNUMBER;
}
HRESULT Source::SetD3DManager(IUnknown* manager) {
    std::lock_guard guard(mutex);
    if (shutdown) return MF_E_SHUTDOWN;
    if (!stream) return E_UNEXPECTED;
    return stream->set_device_manager(manager);
}
HRESULT Source::GetAllocatorUsage(DWORD id, DWORD* input, MFSampleAllocatorUsage* usage) {
    if (!input || !usage) return E_POINTER;
    if (id != 0) return MF_E_INVALIDSTREAMNUMBER;
    *input = 0; *usage = MFSampleAllocatorUsage_UsesCustomAllocator; return S_OK;
}
HRESULT Source::KsProperty(PKSPROPERTY, ULONG, LPVOID, ULONG, ULONG* count) { if (count) *count = 0; return HRESULT_FROM_WIN32(ERROR_SET_NOT_FOUND); }
HRESULT Source::KsMethod(PKSMETHOD, ULONG, LPVOID, ULONG, ULONG* count) { if (count) *count = 0; return HRESULT_FROM_WIN32(ERROR_SET_NOT_FOUND); }
HRESULT Source::KsEvent(PKSEVENT, ULONG, LPVOID, ULONG, ULONG* count) { if (count) *count = 0; return HRESULT_FROM_WIN32(ERROR_SET_NOT_FOUND); }
}
