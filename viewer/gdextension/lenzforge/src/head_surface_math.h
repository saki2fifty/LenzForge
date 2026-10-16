#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
namespace lenzforge {
class HeadSurfaceMath : public godot::RefCounted {
    GDCLASS(HeadSurfaceMath, godot::RefCounted)
protected:
    static void _bind_methods();
public:
    godot::PackedVector3Array build(const godot::PackedVector3Array &face, const godot::PackedInt32Array &outline, int rings, double depth, double crown) const;
    godot::Dictionary bind_nearest(const godot::PackedVector3Array &vertices, const godot::PackedInt32Array &triangles, const godot::PackedVector3Array &targets) const;
    godot::PackedVector3Array sample(const godot::PackedVector3Array &vertices, const godot::PackedInt32Array &indices, const godot::PackedVector3Array &weights) const;
};
}
