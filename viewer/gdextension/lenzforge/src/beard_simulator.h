#ifndef LENZFORGE_BEARD_SIMULATOR_H
#define LENZFORGE_BEARD_SIMULATOR_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include "head_collider.h"
#include <vector>
#include <memory>

namespace lenzforge {
// Bounded 3D strand solver. Camera-pixel coordinates: X right, Y down, Z away.
class BeardSimulator : public godot::RefCounted {
    GDCLASS(BeardSimulator, godot::RefCounted)
public:
    BeardSimulator();
    ~BeardSimulator();
    bool configure(int strands, int segments, const godot::Dictionary &settings,
                   const godot::PackedFloat32Array &attributes,
                   const godot::PackedVector2Array &rest_steps = godot::PackedVector2Array(),
                   const godot::PackedFloat32Array &strand_options = godot::PackedFloat32Array());
    bool set_anchors(const godot::PackedVector2Array &roots, double face_width,
                     const godot::Vector2 &down, const godot::Vector2 &mouth,
                     const godot::Vector2 &mouth_radii);
    bool set_anchors_3d(const godot::PackedVector3Array &roots, double face_width,
                       const godot::Vector3 &down, const godot::Vector3 &right,
                       const godot::Vector2 &mouth, const godot::Vector2 &mouth_radii);
    bool set_head_surface(const godot::PackedVector3Array &vertices, const godot::PackedInt32Array &triangles);
    void advance(double delta);
    void set_parallel_enabled(bool enabled) { parallel_enabled = enabled; }
    int get_worker_count() const { return last_worker_count; }
    bool set_forces(double gravity, double wind, double turbulence, double damping);
    bool set_mustache_forces(double gravity, double wind, double turbulence, double damping, bool collisions);
    void reset();
    bool set_render_order(const godot::PackedInt32Array &order);
    godot::PackedFloat32Array get_render_buffer() const;
    godot::PackedVector2Array get_strand_points(int strand) const;
    godot::PackedVector3Array get_strand_points_3d(int strand) const;
    double get_max_length_error() const;
protected:
    static void _bind_methods();
private:
    struct Strand { float length, root_width, tip_width, curl; float root[4], tip[4]; int mode; float hold; bool collision, mustache; };
    int count = 0, segments = 0;
    double length = .45, gravity = 3, wind = 0, turbulence = 0, damping = .025, stiffness = .4;
    double mustache_gravity = 12, mustache_wind = 0, mustache_turbulence = 0, mustache_damping = .045;
    bool mustache_collisions = true;
    double scale = 300, accumulator = 0, clock = 0;
    bool initialized = false, collisions = true, preserve_shape = false;
    godot::Vector3 down = godot::Vector3(0, 1, 0), right = godot::Vector3(1, 0, 0);
    godot::Vector2 mouth, mouth_radii;
    std::vector<Strand> attributes;
    std::vector<godot::Vector3> roots, positions, previous;
    std::vector<godot::Vector2> directions;
    std::vector<float> rest_lengths;
    HeadCollider head;
    std::vector<int> contact_hint;
    std::vector<int> render_order;
    godot::Vector3 rest_direction(int strand, int segment) const;
    double segment_length(int strand, int segment) const;
    float clearance(int strand, int segment) const;
    bool head_collision(int strand) const;
    void collide_head(int point, float radius, bool swept);
    void collide_link(int point, float radius);
    void collide_mouth(int point);
    void step_strand(int strand, double dt, double root_fraction, double step_time);
    void step_range(int first, int last, int steps, double start_time);
    struct ParallelState;
    std::unique_ptr<ParallelState> workers;
    bool parallel_enabled = true;
    int last_worker_count = 1;
};
}
#endif
