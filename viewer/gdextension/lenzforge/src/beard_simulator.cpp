#include "beard_simulator.h"
#include <godot_cpp/core/class_db.hpp>
#include <algorithm>
#include <cmath>
#include <condition_variable>
#include <mutex>
#include <numeric>
#include <thread>

using namespace godot;
namespace lenzforge {
// Independent strands share a read-only collider. Keep a small pool asleep
// between frames; never create threads or copy joint arrays per simulation step.
struct BeardSimulator::ParallelState {
    BeardSimulator *owner;
    std::mutex mutex;
    std::condition_variable ready, done;
    std::vector<std::thread> threads;
    bool stopping=false;
    unsigned generation=0;
    int remaining=0, steps=0;
    double start_time=0;
    explicit ParallelState(BeardSimulator *p_owner):owner(p_owner) {
        const unsigned count=std::min(3u,std::max(1u,std::thread::hardware_concurrency())-1);
        threads.reserve(count);
        for(unsigned i=0;i<count;++i) threads.emplace_back([this,i,count] {
            unsigned observed=0;
            std::unique_lock<std::mutex> lock(mutex);
            while(true) {
                ready.wait(lock,[&] { return stopping || generation!=observed; });
                if(stopping) return;
                observed=generation;
                const int n=steps, first=owner->count*(i+1)/(count+1), last=owner->count*(i+2)/(count+1);
                const double time=start_time;
                lock.unlock();
                owner->step_range(first,last,n,time);
                lock.lock();
                if(--remaining==0) done.notify_one();
            }
        });
    }
    ~ParallelState() {
        { std::lock_guard<std::mutex> lock(mutex); stopping=true; }
        ready.notify_all();
        for(auto &thread:threads) thread.join();
    }
    void run(int count, double time) {
        {
            std::lock_guard<std::mutex> lock(mutex);
            steps=count; start_time=time; remaining=int(threads.size()); ++generation;
        }
        ready.notify_all();
        owner->step_range(0,owner->count/(int(threads.size())+1),count,time);
        std::unique_lock<std::mutex> lock(mutex);
        done.wait(lock,[&] { return remaining==0; });
    }
};
BeardSimulator::BeardSimulator() = default;
BeardSimulator::~BeardSimulator() = default;
void BeardSimulator::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure", "strands", "segments", "settings", "attributes", "rest_steps", "strand_options"), &BeardSimulator::configure, DEFVAL(PackedVector2Array()), DEFVAL(PackedFloat32Array()));
    ClassDB::bind_method(D_METHOD("set_anchors", "roots", "face_width", "down", "mouth", "mouth_radii"), &BeardSimulator::set_anchors);
    ClassDB::bind_method(D_METHOD("set_anchors_3d", "roots", "face_width", "down", "right", "mouth", "mouth_radii"), &BeardSimulator::set_anchors_3d);
    ClassDB::bind_method(D_METHOD("set_head_surface", "vertices", "triangles"), &BeardSimulator::set_head_surface);
    ClassDB::bind_method(D_METHOD("get_strand_points_3d", "strand"), &BeardSimulator::get_strand_points_3d);
    ClassDB::bind_method(D_METHOD("advance", "delta"), &BeardSimulator::advance);
    ClassDB::bind_method(D_METHOD("set_parallel_enabled", "enabled"), &BeardSimulator::set_parallel_enabled);
    ClassDB::bind_method(D_METHOD("get_worker_count"), &BeardSimulator::get_worker_count);
    ClassDB::bind_method(D_METHOD("set_forces", "gravity", "wind", "turbulence", "damping"), &BeardSimulator::set_forces);
    ClassDB::bind_method(D_METHOD("set_mustache_forces", "gravity", "wind", "turbulence", "damping", "collisions"), &BeardSimulator::set_mustache_forces);
    ClassDB::bind_method(D_METHOD("reset"), &BeardSimulator::reset);
    ClassDB::bind_method(D_METHOD("set_render_order", "order"), &BeardSimulator::set_render_order);
    ClassDB::bind_method(D_METHOD("get_render_buffer"), &BeardSimulator::get_render_buffer);
    ClassDB::bind_method(D_METHOD("get_strand_points", "strand"), &BeardSimulator::get_strand_points);
    ClassDB::bind_method(D_METHOD("get_max_length_error"), &BeardSimulator::get_max_length_error);
    ClassDB::bind_method(D_METHOD("clip_line", "start", "finish", "occluder", "triangles", "head_to_pixels", "world_to_pixels", "pixel_size"), &BeardSimulator::clip_line);
    ClassDB::bind_method(D_METHOD("get_clippings_buffer", "world_to_pixels"), &BeardSimulator::get_clippings_buffer);
    ClassDB::bind_method(D_METHOD("get_clipping_count"), &BeardSimulator::get_clipping_count);
    ClassDB::bind_method(D_METHOD("clear_clippings"), &BeardSimulator::clear_clippings);
    ClassDB::bind_method(D_METHOD("set_clipping_projection", "projection"), &BeardSimulator::set_clipping_projection);
}

static bool valid_forces(double g, double w, double t, double d) {
    return std::isfinite(g) && std::isfinite(w) && std::isfinite(t) && std::isfinite(d) &&
        g>=0 && g<=12 && w>=-10 && w<=10 && t>=0 && t<=5 && d>=0 && d<=.95;
}
bool BeardSimulator::set_forces(double g, double w, double t, double d) {
    if (!valid_forces(g,w,t,d)) return false;
    gravity=g; wind=w; turbulence=t; damping=d;
    return true;
}
bool BeardSimulator::set_mustache_forces(double g, double w, double t, double d, bool collision) {
    if (!valid_forces(g,w,t,d)) return false;
    mustache_gravity=g; mustache_wind=w; mustache_turbulence=t; mustache_damping=d;
    mustache_collisions=collision;
    return true;
}
bool BeardSimulator::head_collision(int s) const {
    return attributes[s].mustache ? mustache_collisions : collisions;
}

bool BeardSimulator::configure(int p_count, int p_segments, const Dictionary &settings, const PackedFloat32Array &data, const PackedVector2Array &steps, const PackedFloat32Array &options) {
    if (p_count < 1 || p_count > 2048 || p_segments < 2 || p_segments > 16 || data.size() != p_count * 12) return false;
    const char *keys[] = {"length", "gravity", "wind", "turbulence", "damping", "stiffness"};
    const double defaults[] = {.45, 3, 0, 0, .025, .4};
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
        if (a[0] < 0 || a[0] > 8 || a[1] < 0 || a[1] > 12 || a[2] < 0 || a[2] > 12 || a[3] < 0 || a[3] > 1) return false;
        for (int c = 4; c < 12; ++c) if (a[c] < 0 || a[c] > 1) return false;
    }
    if (!steps.is_empty()) {
        if (steps.size() != p_count * p_segments) return false;
        for (int i=0; i<steps.size(); ++i) if (!steps[i].is_finite() || steps[i].length() > 4) return false;
    }
    const int option_stride=options.size()==p_count*4 ? 4 : 3;
    if (!options.is_empty()) {
        if (options.size() != p_count*option_stride) return false;
        for (int s=0; s<p_count; ++s) {
            float mode=options[s*option_stride], hold=options[s*option_stride+1], collision=options[s*option_stride+2];
            if (!std::isfinite(mode) || mode < 0 || mode > 2 || mode != std::floor(mode) ||
                !std::isfinite(hold) || hold < 0 || hold > 1 || (collision != 0 && collision != 1)) return false;
            if (option_stride==4 && options[s*4+3]!=0 && options[s*4+3]!=1) return false;
        }
    }
    const double mg=double(settings.get("mustache_gravity",values[1])), mw=double(settings.get("mustache_wind",values[2]));
    const double mt=double(settings.get("mustache_turbulence",values[3])), md=double(settings.get("mustache_damping",values[4]));
    if (!valid_forces(mg,mw,mt,md)) return false;
    bool changed = count != p_count || segments != p_segments;
    count = p_count; segments = p_segments;
    length = values[0]; gravity = values[1]; wind = values[2]; turbulence = values[3]; damping = values[4]; stiffness = values[5];
    collisions = bool(settings.get("collisions", true));
    set_mustache_forces(mg,mw,mt,md,bool(settings.get("mustache_collisions",collisions)));
    preserve_shape = bool(settings.get("preserve_shape", false));
    attributes.resize(count);
    render_order.resize(count);
    std::iota(render_order.begin(),render_order.end(),0);
    roots.resize(count); positions.resize(count * (segments + 1)); previous.resize(positions.size());
    contact_hint.assign(positions.size(), -1);
    directions.resize(count * segments); rest_lengths.resize(count * segments);
    for (int s = 0; s < count; ++s) {
        auto &a = attributes[s]; const float *p = src + s * 12;
        a.length = p[0]; a.root_width = p[1]; a.tip_width = p[2]; a.curl = p[3];
        a.mode=options.is_empty() ? (preserve_shape ? 1 : 0) : int(options[s*option_stride]);
        a.hold=options.is_empty() ? stiffness : options[s*option_stride+1];
        a.collision=options.is_empty() ? collisions : options[s*option_stride+2] != 0;
        a.mustache=option_stride==4 && options[s*4+3]!=0;
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

bool BeardSimulator::set_head_surface(const PackedVector3Array &vertices, const PackedInt32Array &triangles) {
    return head.update(vertices,triangles);
}
bool BeardSimulator::set_anchors(const PackedVector2Array &p_roots, double p_scale, const Vector2 &p_down, const Vector2 &p_mouth, const Vector2 &p_radii) {
    PackedVector3Array spatial;
    spatial.resize(p_roots.size());
    for(int i=0;i<p_roots.size();++i) spatial.set(i,Vector3(p_roots[i].x,p_roots[i].y,0));
    return set_anchors_3d(spatial,p_scale,Vector3(p_down.x,p_down.y,0),Vector3(p_down.y,-p_down.x,0),p_mouth,p_radii);
}
bool BeardSimulator::set_anchors_3d(const PackedVector3Array &p_roots, double p_scale, const Vector3 &p_down, const Vector3 &p_right, const Vector2 &p_mouth, const Vector2 &p_radii) {
    if (p_roots.size() != count || count == 0 || !std::isfinite(p_scale) || p_scale < 1 || p_scale > 10000 ||
        !p_down.is_finite() || p_down.length_squared() < .1 || !p_right.is_finite() || p_right.length_squared()<.1 || !p_mouth.is_finite() || !p_radii.is_finite()) return false;
    for (int i = 0; i < count; ++i) if (!p_roots[i].is_finite()) return false;
    bool teleport = !initialized || std::abs(p_scale / scale - 1) > .25 || p_roots[0].distance_to(roots[0]) > p_scale * .6;
    scale = p_scale; down = p_down.normalized(); right=p_right.normalized(); mouth = p_mouth;
    mouth_radii = Vector2(std::max(1.0f, float(p_radii.x)), std::max(1.0f, float(p_radii.y)));
    for (int i = 0; i < count; ++i) {
        roots[i] = p_roots[i];
        if(head_collision(i) && !head.empty()) {
            Vector3 normal;
            head.project(roots[i],clearance(i,0),contact_hint[i*(segments+1)],normal);
        }
    }
    if (teleport) reset();
    else for (int s=0; s<count; ++s) {
        // A pinned root is the measured attachment, even when this render
        // frame has no fixed physics step. Free joints keep their momentum.
        const int base=s*(segments+1);
        positions[base]=roots[s];
    }
    return true;
}

double BeardSimulator::segment_length(int s, int j) const { return scale * length * attributes[s].length * rest_lengths[s*segments+j-1]; }
Vector3 BeardSimulator::rest_direction(int s, int j) const {
    const Vector2 local=directions[s*segments+j-1];
    return right*local.x+down*local.y;
}
void BeardSimulator::reset() {
    for (int s = 0; s < count; ++s) {
        const int base = s * (segments + 1);
        positions[base] = roots[s];
        for (int j = 1; j <= segments; ++j) {
            const Vector3 direction = attributes[s].mode != 0 ? rest_direction(s,j) : Vector3(0,1,0);
            positions[base+j] = previous[base+j] = positions[base+j-1] + direction * segment_length(s,j);
            if(head_collision(s) && !head.empty()) collide_link(base+j,clearance(s,j));
        }
    }
    previous = positions; initialized = count > 0; accumulator = 0;
}
void BeardSimulator::advance(double delta) {
    if (!initialized || !std::isfinite(delta) || delta <= 0) return;
    constexpr double dt = 1.0 / 120.0;
    accumulator = std::min(accumulator + delta, dt * 4);
    // Rendered roots already match the displayed face. Retain the last physics
    // root in previous[base] to distribute its motion over fixed substeps.
    const int steps = std::min(4, int((accumulator + 1e-9) / dt));
    if(steps==0) return;
    last_worker_count=1;
    if(parallel_enabled && count*segments*steps>=8192) {
        if(!workers) workers=std::make_unique<ParallelState>(this);
        last_worker_count=int(workers->threads.size())+1;
        workers->run(steps,clock);
    } else step_range(0,count,steps,clock);
    if (!clippings.empty()) for (int tick=0;tick<steps;++tick) advance_clippings(dt);
    clock+=steps*dt;
    accumulator-=steps*dt;
}
void BeardSimulator::step_range(int first,int last,int steps,double start_time) {
    constexpr double dt=1.0/120.0;
    for(int tick=0;tick<steps;++tick)
        for(int s=first;s<last;++s) step_strand(s,dt,1.0/(steps-tick),start_time+(tick+1)*dt);
}
void BeardSimulator::step_strand(int s,double dt,double root_fraction,double step_time) {
        const int base = s * (segments + 1);
        if (attributes[s].length < .00001) { for (int j=0; j<=segments; ++j) positions[base+j] = previous[base+j] = roots[s]; return; }
        const Vector3 root = previous[base].lerp(roots[s], root_fraction);
        const auto &attribute=attributes[s];
        const bool solid_head=head_collision(s) && !head.empty();
        const bool mouth_collision=(attribute.mustache ? mustache_collisions : attribute.collision) && head.empty();
        if (attribute.mode == 2) {
            positions[base]=previous[base]=root;
            for (int j=1; j<=segments; ++j) {
                positions[base+j]=positions[base+j-1]+rest_direction(s,j)*segment_length(s,j);
                if(solid_head) collide_link(base+j,clearance(s,j));
                previous[base+j]=positions[base+j];
            }
            return;
        }
        // Select once per strand; no dictionary reads or allocations per joint.
        const double g=attribute.mustache ? mustache_gravity : gravity, w=attribute.mustache ? mustache_wind : wind;
        const double t=attribute.mustache ? mustache_turbulence : turbulence, d=attribute.mustache ? mustache_damping : damping;
        const Vector3 acceleration(w*scale*dt*dt,g*scale*dt*dt,0);
        for (int j = 1; j <= segments; ++j) {
            const int k = base+j;
            const Vector3 velocity = (positions[k] - previous[k]) * (1.0 - d);
            previous[k] = positions[k];
            const double gust = w != 0 && t > 0 ? t * std::sin(step_time * 2.1 + s * .17 + j * .3)*scale*dt*dt : 0;
            positions[k] += velocity + acceleration + Vector3(gust,0,0);
        }
        if(solid_head) for(int j=1;j<=segments;++j) {
            const int k=base+j;
            if(positions[k].distance_squared_to(previous[k])>scale*scale*.0025) collide_head(k,clearance(s,j),true);
        }
        positions[base] = previous[base] = root;
        for (int iteration=0; iteration<4; ++iteration) {
            for (int j=1; j<=segments; ++j) {
                const int k=base+j;
                const double rest=segment_length(s,j);
                if (attribute.mode == 1 && attribute.hold > 0)
                    positions[k] = positions[k].lerp(positions[k-1] + rest_direction(s,j) * rest, attribute.hold * .12);
                Vector3 diff = positions[k] - positions[k-1];
                double distance = diff.length();
                if (distance > 1e-8) {
                    // Distribute tension between neighboring free points. Moving
                    // only the child injects energy down the chain during a turn.
                    const Vector3 correction = diff * (1.0 - rest / distance);
                    if (j == 1) positions[k] -= correction;
                    else { positions[k-1] += correction * .5; positions[k] -= correction * .5; }
                }
                if (mouth_collision) collide_mouth(k);
            }
        }
        // Remove the small remaining stretch after the bounded solver passes.
        // Keep collision projection last so the solid head wins over residual stretch.
        for (int j=1; j<=segments; ++j) {
            const int k=base+j;
            const Vector3 diff=positions[k]-positions[k-1];
            const double distance=diff.length();
            if (distance > 1e-8) positions[k]=positions[k-1]+diff*(segment_length(s,j)/distance);
            if (mouth_collision) collide_mouth(k);
            if(solid_head) collide_link(k,clearance(s,j));
        }
}

bool BeardSimulator::set_render_order(const PackedInt32Array &order) {
    if(order.size()!=count) return false;
    const auto *ids=order.ptr();
    std::vector<bool> seen(count,false);
    for(int i=0;i<count;++i) {
        if(ids[i]<0 || ids[i]>=count || seen[ids[i]]) return false;
        seen[ids[i]]=true;
    }
    // Only output placement changes. Simulation, collision hints, selection
    // and exported strand IDs retain their original stable indices.
    for(int i=0;i<count;++i) render_order[i]=ids[i];
    return true;
}
PackedFloat32Array BeardSimulator::get_render_buffer() const {
    PackedFloat32Array buffer;
    if (!initialized) return buffer;
    buffer.resize(count * segments * 16);
    float *out = buffer.ptrw();
    for (int slot=0; slot<count; ++slot) {
        const int s=render_order[slot];
        const auto &a=attributes[s]; const int base=s*(segments+1);
        for (int j=0; j<segments; ++j) {
            const float t0=float(j)/segments, t1=float(j+1)/segments, t=(t0+t1)*.5f;
            const Vector3 p3=positions[base+j],q3=positions[base+j+1];
            const Vector2 p(p3.x,p3.y),q(q3.x,q3.y),diff=q-p;
            const float distance=diff.length();
            const Vector2 tangent=distance > .0001f ? diff/distance : Vector2(0,1);
            const Vector2 normal(-tangent.y, tangent.x);
            const Vector2 midpoint=(p+q)*.5;
            float w0=(a.root_width+(a.tip_width-a.root_width)*t0)*scale/300.0;
            float w1=(a.root_width+(a.tip_width-a.root_width)*t1)*scale/300.0;
            float width=std::max(w0,w1)+1.5f; // Room for analytic edge antialiasing.
            // Godot 2D transform: xx,yx,0,tx, xy,yy,0,ty; then color/custom.
            *out++=normal.x*width; *out++=tangent.x*(distance+.5f); *out++=0; *out++=midpoint.x;
            *out++=normal.y*width; *out++=tangent.y*(distance+.5f); *out++=0; *out++=midpoint.y;
            for(int c=0;c<4;++c) *out++=(a.root[c]+(a.tip[c]-a.root[c])*t) * (c==3 && a.length==0 ? 0 : 1);
            *out++=w0/width; *out++=w1/width; *out++=p3.z; *out++=q3.z;
        }
    }
    return buffer;
}
PackedVector2Array BeardSimulator::get_strand_points(int strand) const {
    PackedVector2Array result;
    if (!initialized || strand < 0 || strand >= count) return result;
    result.resize(segments+1);
    for(int j=0;j<=segments;++j) { const auto &p=positions[strand*(segments+1)+j]; result.set(j,Vector2(p.x,p.y)); }
    return result;
}
PackedVector3Array BeardSimulator::get_strand_points_3d(int strand) const {
    PackedVector3Array result;
    if(!initialized || strand<0 || strand>=count) return result;
    result.resize(segments+1);
    for(int j=0;j<=segments;++j) result.set(j,positions[strand*(segments+1)+j]);
    return result;
}
float BeardSimulator::clearance(int s,int j) const {
    const auto &a=attributes[s];
    return float((a.root_width+(a.tip_width-a.root_width)*double(j)/segments)*scale/600 + scale*.002);
}
void BeardSimulator::collide_head(int k,float radius,bool swept) {
    Vector3 normal;
    Vector3 velocity=positions[k]-previous[k];
    bool hit=false;
    // Ordinary small steps need only a closest-surface query. Sweep long
    // displacements to stop a fast point crossing the whole head in one step.
    if(swept && positions[k].distance_squared_to(previous[k])>scale*scale*.0025)
        hit=head.sweep(previous[k],positions[k],radius,normal);
    Vector3 projected_normal;
    if(head.project(positions[k],radius,contact_hint[k],projected_normal)) { normal=projected_normal; hit=true; }
    if(hit) {
        // Use a non-bouncing contact response, retaining damped tangential sliding.
        velocity-=normal*velocity.dot(normal);
        previous[k]=positions[k]-velocity*.8;
    }
}
void BeardSimulator::collide_link(int k,float radius) {
    collide_head(k,radius,false);
    // Sweep the entire link, not just its endpoints, so even sparse strands
    // cannot cut through a sharp corner between two exterior joints.
    for(int pass=0;pass<3;++pass) {
        Vector3 contact=positions[k],normal;
        if(!head.sweep(positions[k-1],contact,radius,normal)) break;
        const Vector3 shift=normal*std::max(0.0f,(contact-positions[k]).dot(normal));
        positions[k]+=shift; previous[k]+=shift;
        collide_head(k,radius,false);
    }
}
void BeardSimulator::collide_mouth(int k) {
    Vector2 screen_down(down.x,down.y),screen_right(right.x,right.y);
    Vector2 offset=Vector2(positions[k].x,positions[k].y)-mouth;
    Vector2 local(offset.dot(screen_right)/mouth_radii.x,offset.dot(screen_down)/mouth_radii.y);
    const double radius=local.length();
    if(radius<1) {
        local=radius>1e-8 ? local/radius : Vector2(0,1);
        const Vector2 q=mouth+screen_right*(local.x*mouth_radii.x)+screen_down*(local.y*mouth_radii.y);
        positions[k].x=q.x; positions[k].y=q.y;
    }
}
double BeardSimulator::get_max_length_error() const {
    double error=0;
    if (!initialized) return error;
    for(int s=0;s<count;++s) for(int j=1;j<=segments;++j)
        error=std::max(error,std::abs(double(positions[s*(segments+1)+j].distance_to(positions[s*(segments+1)+j-1]))-segment_length(s,j)));
    return error;
}
}
