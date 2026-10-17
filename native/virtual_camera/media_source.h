#pragma once
#include "common.h"
#include "gpu_transport.h"
namespace lenzcam {
class Stream final : public RuntimeClass<RuntimeClassFlags<ClassicCom>, Microsoft::WRL::ChainInterfaces<IMFMediaStream2, IMFMediaStream, IMFMediaEventGenerator>, FtmBase>, public Tracked {
    std::mutex mutex;
    std::condition_variable changed;
    std::thread worker;
    bool shutdown = false, quit = false;
    MF_STREAM_STATE state = MF_STREAM_STATE_STOPPED;
    ComPtr<IMFMediaSource> parent;
    ComPtr<IMFMediaEventQueue> events;
    ComPtr<IMFVideoSampleAllocator> allocator;
    std::deque<ComPtr<IUnknown>> requests;
    LONGLONG duration = 166667;
    HANDLE mapping = nullptr;
    HANDLE wake = nullptr;
    SharedFrames* frames = nullptr;
    std::wstring owner_sid, transport_name;
    std::vector<uint8_t> snapshot;
    std::unique_ptr<GpuReceiver> gpu;
    bool allow_gpu = true;
    ComPtr<IUnknown> device_manager;
    HRESULT open_transport();
    void run();
    HRESULT deliver(IUnknown* token);
public:
    HRESULT set_device_manager(IUnknown* manager);
    ComPtr<IMFStreamDescriptor> descriptor;
    ComPtr<IMFAttributes> attributes;
    HRESULT initialize(IMFMediaSource* source, const std::wstring& sid, const GUID& session, bool local_test = false);
    HRESULT start(IMFMediaType* type, bool event = true);
    HRESULT stop(bool event = true);
    HRESULT close();
    ~Stream() { close(); }
    ComPtr<IMFMediaEventQueue> queue() { std::lock_guard guard(mutex); return events; }
    LF_EVENTS
    HRESULT STDMETHODCALLTYPE GetMediaSource(IMFMediaSource** out) override;
    HRESULT STDMETHODCALLTYPE GetStreamDescriptor(IMFStreamDescriptor** out) override;
    HRESULT STDMETHODCALLTYPE RequestSample(IUnknown* token) override;
    HRESULT STDMETHODCALLTYPE SetStreamState(MF_STREAM_STATE next) override;
    HRESULT STDMETHODCALLTYPE GetStreamState(MF_STREAM_STATE* out) override;
};

class Source final : public RuntimeClass<RuntimeClassFlags<ClassicCom>, Microsoft::WRL::ChainInterfaces<IMFMediaSourceEx, IMFMediaSource, IMFMediaEventGenerator>, IMFGetService,
    IKsControl, IMFSampleAllocatorControl, FtmBase>, public Tracked {
    std::mutex mutex;
    bool shutdown = false, announced = false;
    ComPtr<IMFMediaEventQueue> events;
    ComPtr<IMFAttributes> attributes;
    ComPtr<IMFPresentationDescriptor> descriptor;
    ComPtr<Stream> stream;
public:
    HRESULT initialize(IMFAttributes* activation, bool local_test = false);
    ComPtr<IMFMediaEventQueue> queue() { std::lock_guard guard(mutex); return events; }
    LF_EVENTS
    HRESULT STDMETHODCALLTYPE GetCharacteristics(DWORD* out) override;
    HRESULT STDMETHODCALLTYPE CreatePresentationDescriptor(IMFPresentationDescriptor** out) override;
    HRESULT STDMETHODCALLTYPE Start(IMFPresentationDescriptor* pd, const GUID* format, const PROPVARIANT* position) override;
    HRESULT STDMETHODCALLTYPE Stop() override;
    HRESULT STDMETHODCALLTYPE Pause() override { return MF_E_INVALID_STATE_TRANSITION; }
    HRESULT STDMETHODCALLTYPE Shutdown() override;
    HRESULT STDMETHODCALLTYPE GetSourceAttributes(IMFAttributes** out) override;
    HRESULT STDMETHODCALLTYPE GetStreamAttributes(DWORD id, IMFAttributes** out) override;
    HRESULT STDMETHODCALLTYPE SetD3DManager(IUnknown* manager) override;
    HRESULT STDMETHODCALLTYPE GetService(REFGUID, REFIID, LPVOID* out) override { if (out) *out = nullptr; return MF_E_UNSUPPORTED_SERVICE; }
    HRESULT STDMETHODCALLTYPE SetDefaultAllocator(DWORD id, IUnknown*) override { return id == 0 ? S_OK : MF_E_INVALIDSTREAMNUMBER; }
    HRESULT STDMETHODCALLTYPE GetAllocatorUsage(DWORD id, DWORD* input, MFSampleAllocatorUsage* usage) override;
    HRESULT STDMETHODCALLTYPE KsProperty(PKSPROPERTY, ULONG, LPVOID, ULONG, ULONG* count) override;
    HRESULT STDMETHODCALLTYPE KsMethod(PKSMETHOD, ULONG, LPVOID, ULONG, ULONG* count) override;
    HRESULT STDMETHODCALLTYPE KsEvent(PKSEVENT, ULONG, LPVOID, ULONG, ULONG* count) override;
};
}
