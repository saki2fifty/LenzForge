#pragma once
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
namespace lenzforge {
class HeadSurfaceMath : public godot::RefCounted {
    GDCLASS(HeadSurfaceMath, godot::RefCounted)
    godot::PackedVector3Array reference, cached_shell;
    godot::PackedInt32Array cached_outline;
    int cached_rings = 0;
    double cached_shape[4]{};
protected:
    static void _bind_methods();
public:
    bool set_reference(const godot::PackedVector3Array &face);
    godot::PackedVector3Array build_stable(const godot::PackedVector3Array &face, const godot::PackedInt32Array &outline, int rings, double depth, double crown, double sides = 1, double jaw = 1);
    godot::PackedVector3Array build(const godot::PackedVector3Array &face, const godot::PackedInt32Array &outline, int rings, double depth, double crown, double sides = 1, double jaw = 1) const;
    godot::Dictionary bind_nearest(const godot::PackedVector3Array &vertices, const godot::PackedInt32Array &triangles, const godot::PackedVector3Array &targets) const;
    godot::PackedVector3Array sample(const godot::PackedVector3Array &vertices, const godot::PackedInt32Array &indices, const godot::PackedVector3Array &weights) const;
};
}
