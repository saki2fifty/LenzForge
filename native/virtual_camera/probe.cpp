// A real Media Foundation consumer. --self-test needs no registration or webcam;
// --capture validates the installed camera through ordinary device enumeration.
#include "media_source.h"
#include "color.h"
#include <mfreadwrite.h>
#include <cstdio>
#include <fstream>

using namespace lenzcam;
static constexpr DWORD video_stream = static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM);
static HRESULT color_test() {
    uint8_t rgba[16] = {255,0,0,255, 0,255,0,255, 0,0,255,255, 255,255,255,255};
    uint8_t nv12[6]{};
    rgba_to_nv12(rgba,nv12,2,2);
    const uint8_t expected[6] = {82,144,41,235,128,128};
    if (memcmp(nv12,expected,6)) return E_FAIL;
    memset(rgba,0,sizeof(rgba));
    rgba_to_nv12(rgba,nv12,2,2);
    if (nv12[0] != 16 || nv12[4] != 128 || nv12[5] != 128) return E_FAIL;
    puts("{\"test\":\"rgba_nv12_color_and_chroma\",\"passed\":true}");
    return S_OK;
}
static HRESULT component_test(const wchar_t* path) {
    HMODULE library = LoadLibraryExW(path,nullptr,LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR|LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!library) return HRESULT_FROM_WIN32(GetLastError());
    auto factory_fn = reinterpret_cast<LPFNGETCLASSOBJECT>(GetProcAddress(library,"DllGetClassObject"));
    auto unload_fn = reinterpret_cast<LPFNCANUNLOADNOW>(GetProcAddress(library,"DllCanUnloadNow"));
    if (!factory_fn || !unload_fn || !GetProcAddress(library,"LFCameraStart") || !GetProcAddress(library,"LFCameraSubmit")) return E_FAIL;
    ComPtr<IClassFactory> factory;
    LF_CHECK(factory_fn(source_clsid,IID_PPV_ARGS(&factory)));
    ComPtr<IMFActivate> activation;
    LF_CHECK(factory->CreateInstance(nullptr,IID_PPV_ARGS(&activation)));
    ComPtr<IMFAttributes> attributes;
    LF_CHECK(activation.As(&attributes));
    LF_CHECK(attributes->SetString(owner_sid_key,L"S-1-5-18"));
    wchar_t sid[192]{};
    LF_CHECK(activation->GetString(owner_sid_key,sid,192,nullptr));
    if (wcscmp(sid,L"S-1-5-18") || unload_fn() != S_FALSE) return E_FAIL;
    LF_CHECK(activation->ShutdownObject());
    attributes.Reset(); activation.Reset(); factory.Reset();
    if (unload_fn() != S_OK) return E_FAIL;
    FreeLibrary(library);
    puts("{\"test\":\"com_factory_attributes_and_lifetime\",\"passed\":true}");
    return S_OK;
}
static HRESULT select_type(IMFSourceReader* reader, UINT32 fps) {
    for (DWORD index = 0; ; ++index) {
        ComPtr<IMFMediaType> type;
        HRESULT hr = reader->GetNativeMediaType(video_stream, index, &type);
        if (FAILED(hr)) return hr;
        UINT32 w = 0, h = 0, n = 0, d = 0; GUID subtype{};
        type->GetGUID(MF_MT_SUBTYPE, &subtype);
        MFGetAttributeSize(type.Get(), MF_MT_FRAME_SIZE, &w, &h);
        MFGetAttributeRatio(type.Get(), MF_MT_FRAME_RATE, &n, &d);
        if (w == width && h == height && n == fps && d == 1 && subtype == MFVideoFormat_NV12)
            return reader->SetCurrentMediaType(video_stream, nullptr, type.Get());
    }
}
static HRESULT read(IMFSourceReader* reader, std::vector<uint8_t>& output, LONGLONG& timestamp) {
    for (int retry = 0; retry < 10; ++retry) {
        DWORD flags = 0;
        ComPtr<IMFSample> sample; ComPtr<IMFMediaBuffer> buffer;
        LF_CHECK(reader->ReadSample(video_stream, 0, nullptr, &flags, &timestamp, &sample));
        if (!sample) continue;
        LF_CHECK(sample->ConvertToContiguousBuffer(&buffer));
        BYTE* data = nullptr; DWORD length = 0;
        LF_CHECK(buffer->Lock(&data, nullptr, &length));
        output.assign(data, data + length);
        buffer->Unlock();
        return length >= bytes ? S_OK : E_UNEXPECTED;
    }
    return E_FAIL;
}
static HRESULT self_test(UINT32 fps) {
    auto source = Make<Source>();
    ComPtr<IMFAttributes> attrs;
    LF_CHECK(MFCreateAttributes(&attrs,1));
    LF_CHECK(attrs->SetString(owner_sid_key, current_sid().c_str()));
    GUID session{};
    LF_CHECK(CoCreateGuid(&session));
    LF_CHECK(attrs->SetGUID(session_key,session));
    LF_CHECK(source->initialize(attrs.Get(), true));
    ComPtr<IMFMediaSource> source_interface;
    LF_CHECK(source.As(&source_interface));
    ComPtr<IMFMediaEventGenerator> event_interface;
    LF_CHECK(source.As(&event_interface));
    auto name = L"Local\\LenzForge.Camera.Test." + std::to_wstring(GetCurrentProcessId());
    HANDLE mapping = OpenFileMappingW(FILE_MAP_ALL_ACCESS,FALSE,name.c_str());
    if (!mapping) return HRESULT_FROM_WIN32(GetLastError());
    auto* frames = static_cast<SharedFrames*>(MapViewOfFile(mapping,FILE_MAP_ALL_ACCESS,0,0,sizeof(SharedFrames)));
    if (!valid(frames)) return E_FAIL;
    ComPtr<IMFSourceReader> reader;
    ComPtr<IMFAttributes> reader_attrs;
    LF_CHECK(MFCreateAttributes(&reader_attrs,1));
    LF_CHECK(reader_attrs->SetUINT32(MF_SOURCE_READER_DISCONNECT_MEDIASOURCE_ON_SHUTDOWN,TRUE));
    LF_CHECK(MFCreateSourceReaderFromMediaSource(source.Get(), reader_attrs.Get(), &reader));
    std::vector<uint8_t> data;
    LONGLONG last = -1, stamp = 0;
    double measured = 0;
    {
        LF_CHECK(select_type(reader.Get(),fps));
        auto began = std::chrono::steady_clock::now();
        for (int i = 0; i < 60; ++i) {
            auto& slot = frames->slots[i%3];
            InterlockedExchange64(&slot.sequence, i*2+1);
            memset(slot.nv12, 81, pixels); // red in BT.601 limited range
            for (uint32_t p = pixels; p < bytes; p += 2) { slot.nv12[p] = 90; slot.nv12[p+1] = 240; }
            slot.timestamp_ms = GetTickCount64();
            InterlockedExchange64(&slot.sequence, i*2+2);
            InterlockedExchange(&frames->published,i%3);
            InterlockedExchange(&frames->producing,1);
            LF_CHECK(read(reader.Get(),data,stamp));
            if (stamp <= last || data[0] != 81 || data[pixels] != 90 || data[pixels+1] != 240) return E_FAIL;
            last = stamp;
        }
        measured = std::chrono::duration<double>(std::chrono::steady_clock::now()-began).count();
        printf("{\"test\":\"source_samples\",\"fps\":%u,\"measured_fps\":%.2f,\"frames\":60}\n",fps,60/measured);
        // Release the reader and reopen it for a new negotiated format.
    }
    InterlockedExchange(&frames->producing,0);
    for (int i = 0; i < 10; ++i) LF_CHECK(read(reader.Get(),data,stamp));
    if (data[0] != 16 || data[pixels] != 128 || data[pixels+1] != 128) return E_FAIL;
    reader.Reset(); source->Shutdown();
    DWORD characteristics = 0;
    if (source->GetCharacteristics(&characteristics) != MF_E_SHUTDOWN) return E_FAIL;
    UnmapViewOfFile(frames); CloseHandle(mapping);
    puts("{\"test\":\"source_lifecycle_and_stale_frame\",\"passed\":true}");
    return S_OK;
}
static HRESULT capture(const wchar_t* output_path, UINT32 count) {
    ComPtr<IMFAttributes> attrs;
    LF_CHECK(MFCreateAttributes(&attrs,1));
    LF_CHECK(attrs->SetGUID(MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE,MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID));
    IMFActivate** devices = nullptr; UINT32 total = 0;
    LF_CHECK(MFEnumDeviceSources(attrs.Get(),&devices,&total));
    ComPtr<IMFActivate> selected;
    for (UINT32 i = 0; i < total; ++i) {
        wchar_t name[512]{};
        devices[i]->GetString(MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME,name,512,nullptr);
        if (wcsstr(name,L"LenzForge")) selected = devices[i];
        devices[i]->Release();
    }
    CoTaskMemFree(devices);
    if (!selected) return HRESULT_FROM_WIN32(ERROR_NOT_FOUND);
    ComPtr<IMFMediaSource> source;
    LF_CHECK(selected->ActivateObject(IID_PPV_ARGS(&source)));
    ComPtr<IMFSourceReader> reader;
    LF_CHECK(MFCreateSourceReaderFromMediaSource(source.Get(),nullptr,&reader));
    LF_CHECK(select_type(reader.Get(),60));
    std::vector<uint8_t> data;
    LONGLONG stamp = 0;
    for (int i = 0; i < 30; ++i) LF_CHECK(read(reader.Get(),data,stamp));
    auto began = std::chrono::steady_clock::now();
    for (UINT32 i = 0; i < count; ++i) LF_CHECK(read(reader.Get(),data,stamp));
    double seconds = std::chrono::duration<double>(std::chrono::steady_clock::now()-began).count();
    if (output_path) { std::ofstream file(output_path,std::ios::binary); file.write(reinterpret_cast<char*>(data.data()),data.size()); }
    printf("{\"test\":\"installed_camera\",\"frames\":%u,\"fps\":%.3f,\"bytes\":%zu}\n",count,count/seconds,data.size());
    reader.Reset(); source->Shutdown(); selected->ShutdownObject();
    return S_OK;
}
int wmain(int argc, wchar_t** argv) {
    setvbuf(stdout,nullptr,_IONBF,0);
    HRESULT hr = CoInitializeEx(nullptr,COINIT_MULTITHREADED);
    if (SUCCEEDED(hr)) hr = MFStartup(MF_VERSION);
    if (SUCCEEDED(hr)) {
        if (argc > 2 && wcscmp(argv[1],L"--component") == 0) hr = component_test(argv[2]);
        else if (argc > 1 && wcscmp(argv[1],L"--self-test") == 0) {
            hr = color_test();
            if (SUCCEEDED(hr)) hr = self_test(60);
            if (SUCCEEDED(hr)) hr = self_test(30);
        } else hr = capture(argc>1 && wcscmp(argv[1],L"--discard") != 0 ? argv[1] : nullptr,argc>2?wcstoul(argv[2],nullptr,10):120);
    }
    if (FAILED(hr)) printf("{\"error\":\"0x%08lx\"}\n",hr);
    MFShutdown(); CoUninitialize();
    return FAILED(hr) ? 1 : 0;
}
