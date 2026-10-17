#pragma once
#include "common.h"
#include <d3d11_1.h>
#include <d3d10.h>
#include <dxgi1_2.h>
#include <GL/gl.h>
namespace lenzcam {
struct GpuSlot {
    ComPtr<ID3D11Texture2D> texture;
    ComPtr<IDXGIKeyedMutex> mutex;
    HANDLE shared = nullptr;
    ~GpuSlot() { if (shared) CloseHandle(shared); }
};
// Frame Server owns the named textures. A normal publisher only opens them.
class GpuReceiver {
    ComPtr<ID3D11Device> device;
    ComPtr<ID3D11DeviceContext> context;
    ComPtr<ID3D11VideoDevice> video;
    ComPtr<ID3D11VideoContext> video_context;
    ComPtr<ID3D11VideoProcessorEnumerator> enumerator;
    ComPtr<ID3D11VideoProcessor> processor;
    ComPtr<ID3D11VideoProcessorInputView> inputs[3];
    ComPtr<ID3D11Texture2D> converted, staging;
    ComPtr<ID3D11VideoProcessorOutputView> output;
    GpuSlot slots[3];
    uint64_t last_stamp = 0;
public:
    HRESULT initialize(SharedFrames* frames, const std::wstring& sid, IUnknown* manager);
    HRESULT copy(SharedFrames* frames, IMFSample* sample);
};
class GpuPublisher {
    ComPtr<ID3D11Device1> device;
    GpuSlot slots[3];
    GUID session{};
    HANDLE interop = nullptr, objects[3]{};
    GLuint textures[3]{}, fbos[2]{};
    HANDLE (WINAPI *open_device)(void*) = nullptr;
    BOOL (WINAPI *close_device)(HANDLE) = nullptr;
    HANDLE (WINAPI *register_object)(HANDLE,void*,GLuint,GLenum,GLenum) = nullptr;
    BOOL (WINAPI *unregister_object)(HANDLE,HANDLE) = nullptr;
    BOOL (WINAPI *lock_objects)(HANDLE,GLint,HANDLE*) = nullptr;
    BOOL (WINAPI *unlock_objects)(HANDLE,GLint,HANDLE*) = nullptr;
    void (APIENTRY *gen_fbos)(GLsizei,GLuint*) = nullptr;
    void (APIENTRY *delete_fbos)(GLsizei,const GLuint*) = nullptr;
    void (APIENTRY *bind_fbo)(GLenum,GLuint) = nullptr;
    void (APIENTRY *attach)(GLenum,GLenum,GLenum,GLuint,GLint) = nullptr;
    GLenum (APIENTRY *check_fbo)(GLenum) = nullptr;
    void (APIENTRY *blit)(GLint,GLint,GLint,GLint,GLint,GLint,GLint,GLint,GLbitfield,GLenum) = nullptr;
    bool attempted = false;
    uint64_t sequence = 0;
    bool initialize(const std::wstring& sid, const GUID& id);
public:
    ~GpuPublisher(); // Destroy on the same GL thread used by submit().
    // 0: unsupported, 1: published, 2: supported but busy (drop without waiting).
    int submit(SharedFrames* frames,const std::wstring& sid,GLuint texture);
};
}
