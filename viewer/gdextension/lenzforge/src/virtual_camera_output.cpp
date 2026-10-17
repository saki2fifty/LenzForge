#include "virtual_camera_output.h"
#include <godot_cpp/core/class_db.hpp>
using namespace godot;
namespace lenzforge {
void VirtualCameraOutput::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start", "library_path"), &VirtualCameraOutput::start);
    ClassDB::bind_method(D_METHOD("stop"), &VirtualCameraOutput::stop);
    ClassDB::bind_method(D_METHOD("submit", "image"), &VirtualCameraOutput::submit);
    ClassDB::bind_method(D_METHOD("submit_texture", "texture"), &VirtualCameraOutput::submit_texture);
    ClassDB::bind_method(D_METHOD("get_status"), &VirtualCameraOutput::get_status);
}
VirtualCameraOutput::~VirtualCameraOutput() {
    stop();
    if (stopping_thread.joinable()) stopping_thread.join();
    if (library) FreeLibrary(library);
}
bool VirtualCameraOutput::start(const String& path) {
    if (output) return true;
    last_error = "";
    if (!stopped) { last_error = "The virtual camera is still stopping. Try again in a moment."; return false; }
    if (stopping_thread.joinable()) stopping_thread.join();
    if (!library) {
        library = LoadLibraryExW(reinterpret_cast<LPCWSTR>(path.utf16().get_data()), nullptr,
            LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
        if (!library) { last_error = "Camera component is missing. Build native/virtual_camera/build.ps1."; return false; }
        start_fn = reinterpret_cast<lenzcam::StartFn>(GetProcAddress(library,"LFCameraStart"));
        stop_fn = reinterpret_cast<lenzcam::StopFn>(GetProcAddress(library,"LFCameraStop"));
        status_fn = reinterpret_cast<lenzcam::StatusFn>(GetProcAddress(library,"LFCameraStatus"));
        submit_fn = reinterpret_cast<lenzcam::SubmitFn>(GetProcAddress(library,"LFCameraSubmit"));
        texture_fn = reinterpret_cast<lenzcam::TextureFn>(GetProcAddress(library,"LFCameraTexture"));
        reset_texture_fn = reinterpret_cast<lenzcam::ResetTextureFn>(GetProcAddress(library,"LFCameraResetTexture"));
    }
    if (!start_fn || !stop_fn || !status_fn || !submit_fn || !texture_fn || !reset_texture_fn) { last_error = "Camera component version is incompatible. Rebuild it."; return false; }
    output = start_fn();
    if (!output) last_error = "Could not start the camera output worker.";
    return output != nullptr;
}
void VirtualCameraOutput::stop() {
    if (!output) return;
    if (reset_texture_fn) reset_texture_fn(output);
    if (stopping_thread.joinable()) stopping_thread.join();
    auto* closing = output; output = nullptr; stopped = false;
    stopping_thread = std::thread([this, closing] { stop_fn(closing); stopped = true; });
}
bool VirtualCameraOutput::submit(const Ref<Image>& image) {
    if (!output || image.is_null() || image->get_format() != Image::FORMAT_RGBA8 ||
        image->get_width() != lenzcam::width || image->get_height() != lenzcam::height) return false;
    auto data = image->get_data();
    return submit_fn(output, data.ptr(), static_cast<uint32_t>(data.size()));
}
bool VirtualCameraOutput::submit_texture(int64_t texture) {
    return output && texture_fn && texture>0 && texture<=UINT32_MAX && texture_fn(output,uint32_t(texture));
}
Dictionary VirtualCameraOutput::get_status() const {
    lenzcam::Status status;
    if (output) status_fn(output, &status);
    else if (!stopped) status.state = 4;
    Dictionary result;
    result["state"] = status.state;
    result["consumer"] = bool(status.consumer);
    result["sent"] = int64_t(status.sent);
    result["replaced"] = int64_t(status.replaced);
    result["conversion_ms"] = status.conversion_ms;
    result["gpu_transfer"] = bool(status.gpu);
    result["gpu_error"] = int64_t(uint32_t(status.gpu_error));
    result["error_code"] = int64_t(uint32_t(status.error));
    String detail = last_error;
    if (status.state == 3) {
        if (status.error == int32_t(0x80040154)) detail = "Install the LenzForge camera component once: run native/virtual_camera/Install.ps1 in Administrator PowerShell.";
        else if (status.error == int32_t(0x800700AA)) detail = "Another LenzForge window is already sending to the virtual camera.";
        else if (status.error == int32_t(0x80070005)) detail = "Windows denied camera access. Enable camera access for desktop apps in Windows Settings.";
        else detail = "Windows could not start LenzForge Virtual Camera (0x" + String::num_uint64(uint32_t(status.error),16) + "). Check the camera installation and Windows camera permissions.";
    }
    result["error"] = detail;
    return result;
}
}
