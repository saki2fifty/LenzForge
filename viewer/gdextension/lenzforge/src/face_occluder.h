#ifndef LENZFORGE_FACE_OCCLUDER_H
#define LENZFORGE_FACE_OCCLUDER_H
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
namespace lenzforge {
class FaceOccluder : public godot::RefCounted {
    GDCLASS(FaceOccluder, godot::RefCounted)
public:
    godot::Ref<godot::Image> rasterize(const godot::PackedVector3Array &vertices,
        const godot::PackedInt32Array &indices, godot::Vector2 dimensions, int map_width = 384, double depth_scale = 1.0) const;
protected:
    static void _bind_methods();
};
}
#endif
