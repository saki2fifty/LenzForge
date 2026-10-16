#include "beard_simulator.h"
#include <godot_cpp/core/class_db.hpp>
#include <algorithm>
#include <cmath>

using namespace godot;
namespace lenzforge {
void BeardSimulator::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure", "strands", "segments", "settings", "attributes", "rest_steps"), &BeardSimulator::configure, DEFVAL(PackedVector2Array()));
    ClassDB::bind_method(D_METHOD("set_anchors", "roots", "face_width", "down", "mouth", "mouth_radii"), &BeardSimulator::set_anchors);
    ClassDB::bind_method(D_METHOD("advance", "delta"), &BeardSimulator::advance);
    ClassDB::bind_method(D_METHOD("reset"), &BeardSimulator::reset);
    ClassDB::bind_method(D_METHOD("get_render_buffer"), &BeardSimulator::get_render_buffer);
    ClassDB::bind_method(D_METHOD("get_strand_points", "strand"), &BeardSimulator::get_strand_points);
    ClassDB::bind_method(D_METHOD("get_max_length_error"), &BeardSimulator::get_max_length_error);
}

bool BeardSimulator::configure(int p_count, int p_segments, const Dictionary &settings, const PackedFloat32Array &data, const PackedVector2Array &steps) {
    if (p_count < 1 || p_count > 1024 || p_segments < 2 || p_segments > 16 || data.size() != p_count * 12) return false;
    const char *keys[] = {"length", "gravity", "wind", "turbulence", "damping", "stiffness"};
    const double defaults[] = {.45, 3, 0, .25, .08, .35};
    const double minimum[] = {.02, 0, -10, 0, 0, 0}, maximum[] = {1.5, 12, 10, 5, .95, 1};
    double values[6];
    for (int i = 0; i < 6; ++i) {
        values[i] = double(settings.get(keys[i], defaults[i]));
        if (!std::isfinite(values[i]) || values[i] < minimum[i] || values[i] > maximum[i]) return false;
    }
    const float *src = data.ptr();
    for (int i = 0; i < data.size(); ++i) if (!std::isfinite(src[i])) return false;
    for (int s = 0; s < p_count; ++s) {
        const float *a = src + s * 12;
        if (a[0] < 0 || a[0] > 4 || a[1] < 0 || a[1] > 12 || a[2] < 0 || a[2] > 12 || a[3] < 0 || a[3] > 1) return false;
        for (int c = 4; c < 12; ++c) if (a[c] < 0 || a[c] > 1) return false;
    }
    if (!steps.is_empty()) {
        if (steps.size() != p_count * p_segments) return false;
        for (int i=0; i<steps.size(); ++i) if (!steps[i].is_finite() || steps[i].length() > 4) return false;
    }
    bool changed = count != p_count || segments != p_segments;
    count = p_count; segments = p_segments;
    length = values[0]; gravity = values[1]; wind = values[2]; turbulence = values[3]; damping = values[4]; stiffness = values[5];
    collisions = bool(settings.get("collisions", true));
    attributes.resize(count);
    roots.resize(count); positions.resize(count * (segments + 1)); previous.resize(positions.size());
    directions.resize(count * segments); rest_lengths.resize(count * segments);
    for (int s = 0; s < count; ++s) {
        auto &a = attributes[s]; const float *p = src + s * 12;
        a.length = p[0]; a.root_width = p[1]; a.tip_width = p[2]; a.curl = p[3];
        for (int c = 0; c < 4; ++c) { a.root[c] = p[4+c]; a.tip[c] = p[8+c]; }
        for (int j=1; j<=segments; ++j) {
            const int k=s*segments+j-1;
            const double angle=std::sin((double(j)/segments)*(2+a.curl*3)*6.283185307179586+std::sin(s*12.9898)*2)*a.curl*1.15;
            Vector2 step=steps.is_empty() ? Vector2(-std::sin(angle),std::cos(angle))/segments : steps[k];
            rest_lengths[k]=step.length();
            directions[k]=rest_lengths[k] > 1e-8 ? step/rest_lengths[k] : Vector2(0,1);
        }
    }
    if (changed) initialized = false;
    return true;
}

bool BeardSimulator::set_anchors(const PackedVector2Array &p_roots, double p_scale, const Vector2 &p_down, const Vector2 &p_mouth, const Vector2 &p_radii) {
    if (p_roots.size() != count || count == 0 || !std::isfinite(p_scale) || p_scale < 1 || p_scale > 10000 ||
        !p_down.is_finite() || p_down.length_squared() < .1 || !p_mouth.is_finite() || !p_radii.is_finite()) return false;
    for (int i = 0; i < count; ++i) if (!p_roots[i].is_finite()) return false;
    bool teleport = !initialized || std::abs(p_scale / scale - 1) > .25 || p_roots[0].distance_to(roots[0]) > p_scale * .6;
    scale = p_scale; down = p_down.normalized(); mouth = p_mouth;
    mouth_radii = Vector2(std::max(1.0f, float(p_radii.x)), std::max(1.0f, float(p_radii.y)));
    for (int i = 0; i < count; ++i) roots[i] = p_roots[i];
    if (teleport) reset();
    return true;
}

double BeardSimulator::segment_length(int s, int j) const { return scale * length * attributes[s].length * rest_lengths[s*segments+j-1]; }
Vector2 BeardSimulator::rest_direction(int s, int j) const {
    const Vector2 local=directions[s*segments+j-1];
    return Vector2(down.y,-down.x)*local.x+down*local.y;
}
void BeardSimulator::reset() {
    for (int s = 0; s < count; ++s) {
        const int base = s * (segments + 1);
        positions[base] = roots[s];
        for (int j = 1; j <= segments; ++j) positions[base+j] = positions[base+j-1] + rest_direction(s,j) * segment_length(s,j);
    }
    previous = positions; initialized = count > 0; accumulator = 0;
}
void BeardSimulator::advance(double delta) {
    if (!initialized || !std::isfinite(delta) || delta <= 0) return;
    constexpr double dt = 1.0 / 120.0;
    accumulator = std::min(accumulator + delta, dt * 4);
    while (accumulator >= dt - 1e-9) { step(dt); accumulator -= dt; }
}
void BeardSimulator::step(double dt) {
    clock += dt;
    const Vector2 right(down.y, -down.x);
    for (int s = 0; s < count; ++s) {
        const int base = s * (segments + 1);
        if (attributes[s].length < .00001) { for (int j=0; j<=segments; ++j) positions[base+j] = previous[base+j] = roots[s]; continue; }
        // Share some root translation to keep rapid head movement bounded while
        // retaining inertia. A discontinuity is handled by set_anchors/reset.
        const Vector2 movement = roots[s] - positions[base];
        for (int j = 1; j <= segments; ++j) {
            const int k = base+j;
            const Vector2 velocity = (positions[k] - previous[k]) * (1.0 - damping);
            previous[k] = positions[k] + movement * .65;
            const double gust = turbulence * std::sin(clock * 2.1 + s * .17 + j * .3);
            positions[k] += movement * .65 + velocity + Vector2((wind + gust) * scale, gravity * scale) * (dt * dt);
        }
        positions[base] = previous[base] = roots[s];
        for (int iteration=0; iteration<4; ++iteration) {
            for (int j=1; j<=segments; ++j) {
                const int k=base+j;
                const double rest=segment_length(s,j);
                positions[k] = positions[k].lerp(positions[k-1] + rest_direction(s,j) * rest, stiffness * .12);
                Vector2 diff = positions[k] - positions[k-1];
                double distance = diff.length();
                if (distance > 1e-8) positions[k] = positions[k-1] + diff * (rest / distance);
                if (collisions) {
                    Vector2 offset = positions[k] - mouth;
                    Vector2 local(offset.dot(right) / mouth_radii.x, offset.dot(down) / mouth_radii.y);
                    const double radius = local.length();
                    if (radius < 1.0) {
                        local = radius > 1e-8 ? local / radius : Vector2(0, 1);
                        positions[k] = mouth + right * (local.x * mouth_radii.x) + down * (local.y * mouth_radii.y);
                    }
                }
            }
        }
    }
}

PackedFloat32Array BeardSimulator::get_render_buffer() const {
    PackedFloat32Array buffer;
    if (!initialized) return buffer;
    buffer.resize(count * segments * 16);
    float *out = buffer.ptrw();
    for (int s=0; s<count; ++s) {
        const auto &a=attributes[s]; const int base=s*(segments+1);
        for (int j=0; j<segments; ++j) {
            const float t0=float(j)/segments, t1=float(j+1)/segments, t=(t0+t1)*.5f;
            const Vector2 p=positions[base+j], q=positions[base+j+1], diff=q-p;
            const float distance=diff.length();
            const Vector2 tangent=distance > .0001f ? diff/distance : down;
            const Vector2 normal(-tangent.y, tangent.x);
            const Vector2 midpoint=(p+q)*.5;
            float w0=(a.root_width+(a.tip_width-a.root_width)*t0)*scale/300.0;
            float w1=(a.root_width+(a.tip_width-a.root_width)*t1)*scale/300.0;
            float width=std::max(w0,w1)+1.5f; // Room for analytic edge antialiasing.
            // Godot 2D transform: xx,yx,0,tx, xy,yy,0,ty; then color/custom.
            *out++=normal.x*width; *out++=tangent.x*(distance+.5f); *out++=0; *out++=midpoint.x;
            *out++=normal.y*width; *out++=tangent.y*(distance+.5f); *out++=0; *out++=midpoint.y;
            for(int c=0;c<4;++c) *out++=(a.root[c]+(a.tip[c]-a.root[c])*t) * (c==3 && a.length==0 ? 0 : 1);
            *out++=w0/width; *out++=w1/width; *out++=0; *out++=0;
        }
    }
    return buffer;
}
PackedVector2Array BeardSimulator::get_strand_points(int strand) const {
    PackedVector2Array result;
    if (!initialized || strand < 0 || strand >= count) return result;
    result.resize(segments+1);
    for(int j=0;j<=segments;++j) result.set(j,positions[strand*(segments+1)+j]);
    return result;
}
double BeardSimulator::get_max_length_error() const {
    double error=0;
    if (!initialized) return error;
    for(int s=0;s<count;++s) for(int j=1;j<=segments;++j)
        error=std::max(error,std::abs(double(positions[s*(segments+1)+j].distance_to(positions[s*(segments+1)+j-1]))-segment_length(s,j)));
    return error;
}
}
