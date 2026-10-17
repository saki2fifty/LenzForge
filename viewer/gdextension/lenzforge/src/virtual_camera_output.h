#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include "../../../../native/virtual_camera/protocol.h"
#include <atomic>
#include <thread>

namespace lenzforge {
class VirtualCameraOutput : public godot::RefCounted {
    GDCLASS(VirtualCameraOutput, godot::RefCounted)
    HMODULE library = nullptr;
    void* output = nullptr;
    lenzcam::StartFn start_fn = nullptr;
    lenzcam::StopFn stop_fn = nullptr;
    lenzcam::SubmitFn submit_fn = nullptr;
    lenzcam::StatusFn status_fn = nullptr;
    lenzcam::TextureFn texture_fn = nullptr;
    lenzcam::ResetTextureFn reset_texture_fn = nullptr;
    godot::String last_error;
    std::thread stopping_thread;
    std::atomic<bool> stopped{true};
protected:
    static void _bind_methods();
public:
    ~VirtualCameraOutput();
    bool start(const godot::String& library_path);
    void stop();
    bool submit(const godot::Ref<godot::Image>& image);
    bool submit_texture(int64_t texture);
    godot::Dictionary get_status() const;
};
}
