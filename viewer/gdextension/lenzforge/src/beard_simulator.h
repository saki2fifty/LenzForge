#ifndef LENZFORGE_BEARD_SIMULATOR_H
#define LENZFORGE_BEARD_SIMULATOR_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <vector>

namespace lenzforge {
// Bounded 2D strand solver. Coordinates are unmirrored video pixels.
class BeardSimulator : public godot::RefCounted {
    GDCLASS(BeardSimulator, godot::RefCounted)
public:
    bool configure(int strands, int segments, const godot::Dictionary &settings,
                   const godot::PackedFloat32Array &attributes,
                   const godot::PackedVector2Array &rest_steps = godot::PackedVector2Array());
    bool set_anchors(const godot::PackedVector2Array &roots, double face_width,
                     const godot::Vector2 &down, const godot::Vector2 &mouth,
                     const godot::Vector2 &mouth_radii);
    void advance(double delta);
    void reset();
    godot::PackedFloat32Array get_render_buffer() const;
    godot::PackedVector2Array get_strand_points(int strand) const;
    double get_max_length_error() const;
protected:
    static void _bind_methods();
private:
    struct Strand { float length, root_width, tip_width, curl; float root[4], tip[4]; };
    int count = 0, segments = 0;
    double length = .45, gravity = 3, wind = 0, turbulence = 0, damping = .025, stiffness = .4;
    double scale = 300, accumulator = 0, clock = 0;
    bool initialized = false, collisions = true, preserve_shape = false;
    godot::Vector2 down = godot::Vector2(0, 1), mouth, mouth_radii;
    std::vector<Strand> attributes;
    std::vector<godot::Vector2> roots, positions, previous;
    std::vector<godot::Vector2> directions;
    std::vector<float> rest_lengths;
    godot::Vector2 rest_direction(int strand, int segment) const;
    double segment_length(int strand, int segment) const;
    void step(double dt, double root_fraction);
};
}
#endif
