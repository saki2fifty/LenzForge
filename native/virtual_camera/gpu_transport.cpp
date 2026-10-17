#include "gpu_transport.h"
namespace lenzcam {
HRESULT GpuReceiver::initialize(SharedFrames* frames,const std::wstring& sid,IUnknown* manager) {
    if (manager) {
        ComPtr<IMFDXGIDeviceManager> dxgi;
        LF_CHECK(manager->QueryInterface(IID_PPV_ARGS(&dxgi)));
        HANDLE handle = nullptr;
        LF_CHECK(dxgi->OpenDeviceHandle(&handle));
        HRESULT hr = dxgi->LockDevice(handle,IID_PPV_ARGS(&device),TRUE);
        if (SUCCEEDED(hr)) dxgi->UnlockDevice(handle,FALSE);
        dxgi->CloseDeviceHandle(handle);
        LF_CHECK(hr);
    } else LF_CHECK(D3D11CreateDevice(nullptr,D3D_DRIVER_TYPE_HARDWARE,nullptr,D3D11_CREATE_DEVICE_VIDEO_SUPPORT,
        nullptr,0,D3D11_SDK_VERSION,&device,nullptr,&context));
    device->GetImmediateContext(&context);
    LF_CHECK(device.As(&video));
    LF_CHECK(context.As(&video_context));
    ComPtr<ID3D10Multithread> protection;
    if (SUCCEEDED(context.As(&protection))) protection->SetMultithreadProtected(TRUE);
    D3D11_VIDEO_PROCESSOR_CONTENT_DESC content{};
    content.InputFrameFormat=D3D11_VIDEO_FRAME_FORMAT_PROGRESSIVE;
    content.InputWidth=content.OutputWidth=width; content.InputHeight=content.OutputHeight=height;
    content.InputFrameRate=content.OutputFrameRate={60,1}; content.Usage=D3D11_VIDEO_USAGE_PLAYBACK_NORMAL;
    LF_CHECK(video->CreateVideoProcessorEnumerator(&content,&enumerator));
    UINT support=0;
    LF_CHECK(enumerator->CheckVideoProcessorFormat(DXGI_FORMAT_NV12,&support));
    if (!(support&D3D11_VIDEO_PROCESSOR_FORMAT_SUPPORT_OUTPUT)) return E_NOTIMPL;
    LF_CHECK(video->CreateVideoProcessor(enumerator.Get(),0,&processor));
    D3D11_VIDEO_PROCESSOR_COLOR_SPACE rgb{},yuv{};
    rgb.RGB_Range=0; rgb.YCbCr_Matrix=0; rgb.Nominal_Range=2;
    yuv.YCbCr_Matrix=0; yuv.Nominal_Range=1; // BT.601, studio range.
    video_context->VideoProcessorSetStreamColorSpace(processor.Get(),0,&rgb);
    video_context->VideoProcessorSetOutputColorSpace(processor.Get(),&yuv);
    video_context->VideoProcessorSetStreamAutoProcessingMode(processor.Get(),0,FALSE);
    video_context->VideoProcessorSetStreamFrameFormat(processor.Get(),0,D3D11_VIDEO_FRAME_FORMAT_PROGRESSIVE);
    GUID id{}; LF_CHECK(CoCreateGuid(&id));
    PSECURITY_DESCRIPTOR security=nullptr;
    std::wstring acl=L"D:P(A;;GA;;;SY)(A;;GA;;;LS)(A;;GA;;;"+sid+L")";
    if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(acl.c_str(),SDDL_REVISION_1,&security,nullptr)) return HRESULT_FROM_WIN32(GetLastError());
    SECURITY_ATTRIBUTES sa{sizeof(sa),security,FALSE};
    HRESULT hr=S_OK;
    for (int i=0;i<3 && SUCCEEDED(hr);++i) {
        D3D11_TEXTURE2D_DESC desc{};
        desc.Width=width; desc.Height=height; desc.MipLevels=desc.ArraySize=1; desc.SampleDesc.Count=1;
        desc.Format=DXGI_FORMAT_R8G8B8A8_UNORM; desc.Usage=D3D11_USAGE_DEFAULT;
        desc.BindFlags=D3D11_BIND_RENDER_TARGET|D3D11_BIND_SHADER_RESOURCE;
        desc.MiscFlags=D3D11_RESOURCE_MISC_SHARED_NTHANDLE|D3D11_RESOURCE_MISC_SHARED_KEYEDMUTEX;
        hr=device->CreateTexture2D(&desc,nullptr,&slots[i].texture);
        ComPtr<IDXGIResource1> resource;
        if (SUCCEEDED(hr)) hr=slots[i].texture.As(&resource);
        if (SUCCEEDED(hr)) hr=resource->CreateSharedHandle(&sa,DXGI_SHARED_RESOURCE_READ|DXGI_SHARED_RESOURCE_WRITE,
            texture_name(sid,id,i).c_str(),&slots[i].shared);
        if (SUCCEEDED(hr)) hr=slots[i].texture.As(&slots[i].mutex);
        D3D11_VIDEO_PROCESSOR_INPUT_VIEW_DESC input{}; input.ViewDimension=D3D11_VPIV_DIMENSION_TEXTURE2D;
        if (SUCCEEDED(hr)) hr=video->CreateVideoProcessorInputView(slots[i].texture.Get(),enumerator.Get(),&input,&inputs[i]);
    }
    LocalFree(security); LF_CHECK(hr);
    D3D11_TEXTURE2D_DESC desc{};
    desc.Width=width; desc.Height=height; desc.MipLevels=desc.ArraySize=1; desc.SampleDesc.Count=1;
    desc.Format=DXGI_FORMAT_NV12; desc.Usage=D3D11_USAGE_DEFAULT; desc.BindFlags=D3D11_BIND_RENDER_TARGET;
    LF_CHECK(device->CreateTexture2D(&desc,nullptr,&converted));
    D3D11_VIDEO_PROCESSOR_OUTPUT_VIEW_DESC view{}; view.ViewDimension=D3D11_VPOV_DIMENSION_TEXTURE2D;
    LF_CHECK(video->CreateVideoProcessorOutputView(converted.Get(),enumerator.Get(),&view,&output));
    desc.Usage=D3D11_USAGE_STAGING; desc.BindFlags=0; desc.CPUAccessFlags=D3D11_CPU_ACCESS_READ;
    LF_CHECK(device->CreateTexture2D(&desc,nullptr,&staging));
    frames->gpu_session=id; InterlockedExchange(&frames->gpu_published,-1);
    MemoryBarrier(); InterlockedExchange(&frames->gpu_ready,1);
    return S_OK;
}
HRESULT GpuReceiver::copy(SharedFrames* frames,IMFSample* sample) {
    LONG index=InterlockedCompareExchange(&frames->gpu_published,0,0);
    if (index<0 || index>=3) return S_FALSE;
    auto& slot=slots[index];
    auto now=GetTickCount64();
    HRESULT hr=S_OK;
    if (slot.mutex->AcquireSync(0,0)==S_OK) {
        auto stamp=frames->slots[index].timestamp_ms;
        if (stamp && stamp<=now && now-stamp<=500 && stamp!=last_stamp) {
            D3D11_VIDEO_PROCESSOR_STREAM input{}; input.Enable=TRUE; input.pInputSurface=inputs[index].Get();
            hr=video_context->VideoProcessorBlt(processor.Get(),output.Get(),0,1,&input);
            if (SUCCEEDED(hr)) last_stamp=stamp;
        }
        slot.mutex->ReleaseSync(0);
        LF_CHECK(hr);
    }
    // A busy producer can reuse the last converted frame, but never indefinitely.
    if (!last_stamp || last_stamp>now || now-last_stamp>500) return S_FALSE;
    ComPtr<IMFMediaBuffer> buffer; LF_CHECK(sample->GetBufferByIndex(0,&buffer));
    ComPtr<IMFDXGIBuffer> dxgi;
    if (SUCCEEDED(buffer.As(&dxgi))) {
        ComPtr<ID3D11Texture2D> target; UINT sub=0;
        LF_CHECK(dxgi->GetResource(IID_PPV_ARGS(&target))); LF_CHECK(dxgi->GetSubresourceIndex(&sub));
        context->CopySubresourceRegion(target.Get(),sub,0,0,0,converted.Get(),0,nullptr);
    } else {
        // CPU-only camera clients still work. Readback happens in Frame Server,
        // never on Godot's rendering thread, and the color conversion stays on GPU.
        context->CopyResource(staging.Get(),converted.Get());
        D3D11_MAPPED_SUBRESOURCE mapped{}; LF_CHECK(context->Map(staging.Get(),0,D3D11_MAP_READ,0,&mapped));
        ComPtr<IMF2DBuffer2> plane; hr=buffer.As(&plane);
        BYTE *scan=nullptr,*start=nullptr; LONG stride=0; DWORD length=0;
        if (SUCCEEDED(hr)) hr=plane->Lock2DSize(MF2DBuffer_LockFlags_Write,&scan,&stride,&start,&length);
        if (SUCCEEDED(hr)) {
            if (stride<LONG(width) || length<uint64_t(stride)*height*3/2) hr=E_UNEXPECTED;
            else for (UINT y=0;y<height*3/2;++y) memcpy(scan+y*stride,static_cast<BYTE*>(mapped.pData)+y*mapped.RowPitch,width);
            plane->Unlock2D();
        }
        context->Unmap(staging.Get(),0); LF_CHECK(hr);
    }
    return S_OK;
}
template<class T> static bool proc(T& out,const char* name) {
    out=reinterpret_cast<T>(wglGetProcAddress(name));
    auto value=reinterpret_cast<uintptr_t>(out);
    return value>3 && value!=uintptr_t(-1);
}
bool GpuPublisher::initialize(const std::wstring& sid,const GUID& id) {
    if (!wglGetCurrentContext()) { fprintf(stderr,"Camera GPU: no GL context on capture thread\n"); return false; }
    if (!proc(open_device,"wglDXOpenDeviceNV") || !proc(close_device,"wglDXCloseDeviceNV") ||
        !proc(register_object,"wglDXRegisterObjectNV") || !proc(unregister_object,"wglDXUnregisterObjectNV") ||
        !proc(lock_objects,"wglDXLockObjectsNV") || !proc(unlock_objects,"wglDXUnlockObjectsNV") ||
        !proc(gen_fbos,"glGenFramebuffers") || !proc(delete_fbos,"glDeleteFramebuffers") ||
        !proc(bind_fbo,"glBindFramebuffer") || !proc(attach,"glFramebufferTexture2D") ||
        !proc(check_fbo,"glCheckFramebufferStatus") || !proc(blit,"glBlitFramebuffer")) { fprintf(stderr,"Camera GPU: GL/DX interop unavailable\n"); return false; }
    ComPtr<ID3D11Device> base;
    if (FAILED(D3D11CreateDevice(nullptr,D3D_DRIVER_TYPE_HARDWARE,nullptr,0,nullptr,0,D3D11_SDK_VERSION,&base,nullptr,nullptr)) || FAILED(base.As(&device))) return false;
    interop=open_device(device.Get()); if (!interop) { fprintf(stderr,"Camera GPU: interop device %lu\n",GetLastError()); return false; }
    gen_fbos(2,fbos); glGenTextures(3,textures);
    for (int i=0;i<3;++i) {
        if (FAILED(device->OpenSharedResourceByName(texture_name(sid,id,i).c_str(),DXGI_SHARED_RESOURCE_READ|DXGI_SHARED_RESOURCE_WRITE,IID_PPV_ARGS(&slots[i].texture))) ||
            FAILED(slots[i].texture.As(&slots[i].mutex))) { fprintf(stderr,"Camera GPU: shared texture open failed\n"); return false; }
        objects[i]=register_object(interop,slots[i].texture.Get(),textures[i],GL_TEXTURE_2D,0x0002);
        if (!objects[i]) { fprintf(stderr,"Camera GPU: GL registration %lu\n",GetLastError()); return false; }
    }
    return true;
}
GpuPublisher::~GpuPublisher() {
    if (interop) {
        for (auto object:objects) if (object) unregister_object(interop,object);
        close_device(interop);
    }
    if (wglGetCurrentContext()) {
        if (delete_fbos && fbos[0]) delete_fbos(2,fbos);
        if (textures[0]) glDeleteTextures(3,textures);
    }
}
int GpuPublisher::submit(SharedFrames* frames,const std::wstring& sid,GLuint texture) {
    if (!texture || !frames || !InterlockedCompareExchange(&frames->gpu_ready,0,0)) return false;
    GUID id=frames->gpu_session;
    if (attempted && id!=session) return false; // Owner replaces us on generation changes.
    if (!attempted) { attempted=true; session=id; if (!initialize(sid,id)) return false; }
    if (!objects[2]) return false;
    int index=int(sequence%3);
    if (slots[index].mutex->AcquireSync(0,0)!=S_OK) return 2;
    if (!lock_objects(interop,1,&objects[index])) { slots[index].mutex->ReleaseSync(0); return false; }
    GLint read=0,draw=0; glGetIntegerv(0x8CAA,&read); glGetIntegerv(0x8CA6,&draw);
    GLboolean scissor=glIsEnabled(GL_SCISSOR_TEST); glDisable(GL_SCISSOR_TEST);
    bind_fbo(0x8CA8,fbos[0]); attach(0x8CA8,0x8CE0,GL_TEXTURE_2D,texture,0);
    bind_fbo(0x8CA9,fbos[1]); attach(0x8CA9,0x8CE0,GL_TEXTURE_2D,textures[index],0);
    bool valid=check_fbo(0x8CA8)==0x8CD5 && check_fbo(0x8CA9)==0x8CD5;
    // Godot already renders its canvas viewport in texture coordinates.
    if (valid) blit(0,0,width,height,0,0,width,height,GL_COLOR_BUFFER_BIT,GL_NEAREST);
    bind_fbo(0x8CA8,read); bind_fbo(0x8CA9,draw); if (scissor) glEnable(GL_SCISSOR_TEST);
    valid = unlock_objects(interop,1,&objects[index]) && valid;
    if (valid) { frames->slots[index].timestamp_ms=GetTickCount64(); MemoryBarrier(); InterlockedExchange(&frames->gpu_published,index); ++sequence; }
    slots[index].mutex->ReleaseSync(0);
    return valid;
}
}
