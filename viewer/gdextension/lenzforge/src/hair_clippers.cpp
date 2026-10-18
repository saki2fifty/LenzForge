#include "beard_simulator.h"
#include <godot_cpp/variant/array.hpp>
#include <algorithm>
#include <cmath>
#include <limits>
using namespace godot;
namespace lenzforge {
namespace {
bool valid_projection(const Transform3D& transform) {
    return transform.origin.is_finite() && transform.basis[0].is_finite() &&
        transform.basis[1].is_finite() && transform.basis[2].is_finite() &&
        std::isfinite(transform.basis.determinant()) && std::abs(transform.basis.determinant())>1e-10;
}
Vector2 xy(const Vector3& p) { return Vector2(p.x,p.y); }
struct Hit { int strand,link; double t,line,depth; };
constexpr int MAX_CLIPPINGS=2048;
constexpr double LIFETIME=2.5;

void write_segment(float*& out,const Vector3& p3,const Vector3& q3,float w0,float w1,const Color& color) {
    const Vector2 p=xy(p3),q=xy(q3),diff=q-p;
    const double distance=diff.length();
    const Vector2 tangent=distance>.0001 ? diff/distance : Vector2(0,1),normal(-tangent.y,tangent.x),midpoint=(p+q)*.5;
    const float width=std::max(w0,w1)+1.5f;
    *out++=normal.x*width; *out++=tangent.x*(distance+.5); *out++=0; *out++=midpoint.x;
    *out++=normal.y*width; *out++=tangent.y*(distance+.5); *out++=0; *out++=midpoint.y;
    *out++=color.r; *out++=color.g; *out++=color.b; *out++=color.a;
    *out++=w0/width; *out++=w1/width; *out++=p3.z; *out++=q3.z;
}
}

void BeardSimulator::set_clipping_projection(const Transform3D& projection) {
    if(valid_projection(projection)) clipping_projection=projection;
}

Dictionary BeardSimulator::clip_line(const Vector2& start,const Vector2& finish,
    const PackedVector3Array& occluder,const PackedInt32Array& triangles,
    const Transform3D& head_to_pixels,const Transform3D& world_to_pixels,double pixel_size) {
    Dictionary result;
    if(!initialized || !start.is_finite() || !finish.is_finite() || !std::isfinite(pixel_size) || pixel_size<.05 || pixel_size>100 ||
        !valid_projection(head_to_pixels) || !valid_projection(world_to_pixels) || occluder.size()>100000 || triangles.size()>600000 || triangles.size()%3) return result;
    const Vector2 line=finish-start;
    const double line_length=line.length();
    if(line_length<pixel_size*2 || line_length>16384) return result;
    for(int i=0;i<occluder.size();++i) if(!occluder[i].is_finite()) return result;
    for(int i=0;i<triangles.size();++i) if(triangles[i]<0 || triangles[i]>=occluder.size()) return result;
    const Vector2 axis=line/line_length,normal(-axis.y,axis.x);
    const int bins=std::min(8192,int(std::ceil(line_length/std::max(.25,pixel_size*.5)))+1);
    const double spacing=line_length/(bins-1);
    const double infinity=std::numeric_limits<double>::infinity();
    std::vector<double> front(bins,infinity),head_depth(bins,infinity);
    std::vector<int> owner(bins,-1),rank(count);
    std::vector<Hit> hits;
    for(int i=0;i<count;++i) rank[render_order[i]]=i;
    // Only a one-dimensional depth strip under the blade, not a full-frame
    // readback or a per-hair scene object. Work happens on release, never idle.
    for(int s=0;s<count;++s) {
        const auto& a=attributes[s];
        if(a.length<1e-5 || std::max(a.root[3],a.tip[3])<.001) continue;
        const int base=s*(segments+1);
        const double bias=scale*.0005*rank[s]/std::max(count-1,1);
        for(int j=0;j<segments;++j) {
            const Vector3 p3=positions[base+j],q3=positions[base+j+1];
            const Vector2 p=xy(p3),q=xy(q3),delta=q-p;
            const double square=delta.length_squared();
            if(square<1e-10) continue;
            const double w0=(a.root_width+(a.tip_width-a.root_width)*double(j)/segments)*scale/600;
            const double w1=(a.root_width+(a.tip_width-a.root_width)*double(j+1)/segments)*scale/600;
            const double radius=std::max(w0,w1)+pixel_size*.25;
            const double side0=(p-start).dot(normal),side1=(q-start).dot(normal);
            if(std::min(side0,side1)>radius || std::max(side0,side1)<-radius) continue;
            const double u0=(p-start).dot(axis),u1=(q-start).dot(axis);
            const int first=std::max(0,int(std::floor((std::min(u0,u1)-radius)/spacing)));
            const int last=std::min(bins-1,int(std::ceil((std::max(u0,u1)+radius)/spacing)));
            for(int b=first;b<=last;++b) {
                const Vector2 at=start+axis*(b*spacing);
                const double t=std::clamp(double((at-p).dot(delta))/square,0.0,1.0);
                const double along=(j+t)/segments;
                if(a.root[3]+(a.tip[3]-a.root[3])*along<.001) continue;
                const double width=w0+(w1-w0)*t+pixel_size*.25;
                if(at.distance_squared_to(p+delta*t)>width*width) continue;
                const double z=p3.z+(q3.z-p3.z)*t-bias;
                if(z<front[b]) { front[b]=z; owner[b]=s; }
            }
            const double denominator=line.cross(delta);
            if(std::abs(denominator)<1e-8) continue;
            const double u=(p-start).cross(delta)/denominator;
            const double t=(p-start).cross(line)/denominator;
            if(u>=0 && u<=1 && t>=0 && t<=1 && a.root[3]+(a.tip[3]-a.root[3])*(j+t)/segments>=.001)
                hits.push_back({s,j,t,u,p3.z+(q3.z-p3.z)*t});
        }
    }
    // Rasterize the actual mannequin (including ears/neck) along the same
    // blade. Hidden far-side hairs cannot be cut through the solid head.
    std::vector<Vector3> mesh(occluder.size());
    for(int i=0;i<occluder.size();++i) mesh[i]=head_to_pixels.xform(occluder[i]);
    for(int i=0;i<triangles.size();i+=3) {
        const Vector3 a=mesh[triangles[i]],b=mesh[triangles[i+1]],c=mesh[triangles[i+2]];
        const Vector2 ab=xy(b-a),ac=xy(c-a);
        const double determinant=ab.cross(ac);
        if(std::abs(determinant)<1e-9) continue;
        const double da=(xy(a)-start).dot(normal),db=(xy(b)-start).dot(normal),dc=(xy(c)-start).dot(normal);
        if(std::min({da,db,dc})>0 || std::max({da,db,dc})<0) continue;
        const double ua=(xy(a)-start).dot(axis),ub=(xy(b)-start).dot(axis),uc=(xy(c)-start).dot(axis);
        const int first=std::max(0,int(std::floor(std::min({ua,ub,uc})/spacing)));
        const int last=std::min(bins-1,int(std::ceil(std::max({ua,ub,uc})/spacing)));
        for(int k=first;k<=last;++k) {
            const Vector2 p=start+axis*(k*spacing)-xy(a);
            const double v=p.cross(ac)/determinant,w=ab.cross(p)/determinant;
            if(v>=0 && w>=0 && v+w<=1) head_depth[k]=std::min(head_depth[k],a.z+(b.z-a.z)*v+(c.z-a.z)*w);
        }
    }
    std::vector<Hit> chosen(count,Hit{-1,0,0,0,0});
    for(const auto& hit:hits) {
        const int b=std::clamp(int(std::round(hit.line*(bins-1))),0,bins-1);
        if(owner[b]!=hit.strand || hit.depth>head_depth[b]+scale*.001) continue;
        auto& best=chosen[hit.strand];
        if(best.strand<0 || hit.link+hit.t<best.link+best.t) best=hit;
    }
    const Transform3D pixels_to_world=world_to_pixels.affine_inverse();
    const double unit=pixels_to_world.basis.get_column(0).length();
    clipping_projection=world_to_pixels;
    Array cuts;
    for(const auto& hit:chosen) {
        if(hit.strand<0 || hit.link+hit.t>=segments-.0001) continue;
        const int s=hit.strand,base=s*(segments+1),offset=s*segments;
        auto& a=attributes[s];
        const auto old=a;
        double cumulative[17]{};
        Vector2 guide[17];
        for(int j=0;j<segments;++j) {
            cumulative[j+1]=cumulative[j]+rest_lengths[offset+j];
            guide[j+1]=guide[j]+directions[offset+j]*rest_lengths[offset+j];
        }
        const double kept=cumulative[hit.link]+rest_lengths[offset+hit.link]*hit.t;
        const double total=cumulative[segments];
        if(total<1e-8) continue;
        const double fraction=std::clamp(kept/total,0.0,1.0),color_fraction=(hit.link+hit.t)/segments;
        const Vector3 cut=positions[base+hit.link].lerp(positions[base+hit.link+1],hit.t);
        const Vector3 cut_previous=previous[base+hit.link].lerp(previous[base+hit.link+1],hit.t);
        Clipping piece;
        piece.gravity=a.mustache ? mustache_gravity : gravity;
        piece.wind=a.mustache ? mustache_wind : wind;
        piece.turbulence=a.mustache ? mustache_turbulence : turbulence;
        piece.damping=a.mustache ? mustache_damping : damping;
        piece.face_width=scale*unit; piece.collision=head_collision(s);
        auto append=[&](const Vector3& p,const Vector3& prior,double t) {
            piece.points.push_back(pixels_to_world.xform(p)); piece.previous.push_back(pixels_to_world.xform(prior));
            piece.widths.push_back((old.root_width+(old.tip_width-old.root_width)*t)*scale/300*unit);
            piece.colors.emplace_back(old.root[0]+(old.tip[0]-old.root[0])*t,old.root[1]+(old.tip[1]-old.root[1])*t,
                old.root[2]+(old.tip[2]-old.root[2])*t,old.root[3]+(old.tip[3]-old.root[3])*t);
        };
        append(cut,cut_previous,color_fraction);
        for(int j=hit.link+1;j<=segments;++j) if(positions[base+j].distance_squared_to(cut)>1e-10 || j>hit.link+1)
            append(positions[base+j],previous[base+j],double(j)/segments);
        for(size_t j=1;j<piece.points.size();++j) piece.lengths.push_back(piece.points[j].distance_to(piece.points[j-1]));
        piece.hints.assign(piece.points.size(),-1);
        if(piece.points.size()>1) {
            if(clippings.size()>=MAX_CLIPPINGS) clippings.pop_front();
            clippings.push_back(std::move(piece));
        }
        // Resample the retained material and its previous positions with the
        // original segment count. Other strands and their velocities stay intact.
        Vector3 now[17],prior[17]; Vector2 rest[17];
        int cursor=0;
        for(int j=0;j<=segments;++j) {
            const double target=kept*double(j)/segments;
            while(cursor<segments-1 && cumulative[cursor+1]<target) ++cursor;
            const double t=std::clamp((target-cumulative[cursor])/std::max(cumulative[cursor+1]-cumulative[cursor],1e-12),0.0,1.0);
            now[j]=positions[base+cursor].lerp(positions[base+cursor+1],t);
            prior[j]=previous[base+cursor].lerp(previous[base+cursor+1],t);
            rest[j]=guide[cursor].lerp(guide[cursor+1],t);
        }
        double guide_length=0;
        for(int j=1;j<=segments;++j) guide_length+=rest[j].distance_to(rest[j-1]);
        Array saved_guide;
        for(int j=0;j<=segments;++j) {
            positions[base+j]=now[j]; previous[base+j]=prior[j]; contact_hint[base+j]=-1;
            Array point; point.push_back(rest[j].x/std::max(guide_length,1e-12)); point.push_back(rest[j].y/std::max(guide_length,1e-12)); saved_guide.push_back(point);
            if(j) {
                const Vector2 step=rest[j]-rest[j-1];
                rest_lengths[offset+j-1]=guide_length>1e-8 ? step.length()/guide_length : 1.0/segments;
                directions[offset+j-1]=step.length_squared()>1e-12 ? step.normalized() : Vector2(0,1);
            }
        }
        a.length*=fraction;
        a.tip_width=old.root_width+(old.tip_width-old.root_width)*color_fraction;
        for(int c=0;c<4;++c) a.tip[c]=old.root[c]+(old.tip[c]-old.root[c])*color_fraction;
        Dictionary edit; edit["index"]=s; edit["fraction"]=fraction; edit["tip_width"]=a.tip_width;
        edit["tip_color"]=Color(a.tip[0],a.tip[1],a.tip[2],a.tip[3]);
        if(guide_length>1e-8) edit["guide"]=saved_guide;
        cuts.push_back(edit);
    }
    result["cuts"]=cuts;
    return result;
}

void BeardSimulator::advance_clippings(double dt) {
    const Transform3D inverse=clipping_projection.affine_inverse();
    const double pixels=clipping_projection.basis.get_column(0).length();
    for(auto& piece:clippings) {
        piece.age+=dt;
        const double gust=piece.wind!=0 ? piece.turbulence*std::sin(clock*2.1+piece.age*3) : 0;
        const Vector3 acceleration((piece.wind+gust)*piece.face_width*dt*dt,-piece.gravity*piece.face_width*dt*dt,0);
        for(size_t j=0;j<piece.points.size();++j) {
            const Vector3 p=piece.points[j];
            piece.points[j]+=(p-piece.previous[j])*(1-piece.damping)+acceleration;
            piece.previous[j]=p;
        }
        for(int iteration=0;iteration<3;++iteration) for(size_t j=1;j<piece.points.size();++j) {
            const Vector3 diff=piece.points[j]-piece.points[j-1];
            const double distance=diff.length();
            if(distance>1e-9) {
                const Vector3 correction=diff*(.5*(1-piece.lengths[j-1]/distance));
                piece.points[j-1]+=correction; piece.points[j]-=correction;
            }
        }
        if(piece.collision && !head.empty()) for(size_t j=0;j<piece.points.size();++j) {
            Vector3 point=clipping_projection.xform(piece.points[j]),normal;
            const Vector3 before=clipping_projection.xform(piece.previous[j]);
            const float radius=(piece.widths[j]*.5+piece.face_width*.002)*pixels;
            bool collided=head.sweep(before,point,radius,normal);
            collided=head.project(point,radius,piece.hints[j],normal)||collided;
            if(collided) {
                piece.points[j]=inverse.xform(point);
                piece.previous[j]=piece.points[j];
            }
        }
    }
    // Creation order equals expiry order. Bounded storage and no lingering nodes.
    while(!clippings.empty() && clippings.front().age>=LIFETIME) clippings.pop_front();
}

PackedFloat32Array BeardSimulator::get_clippings_buffer(const Transform3D& world_to_pixels) const {
    PackedFloat32Array buffer;
    if(clippings.empty() || !valid_projection(world_to_pixels)) return buffer;
    int links=0;
    for(const auto& piece:clippings) links+=int(piece.lengths.size());
    buffer.resize(links*16); float* out=buffer.ptrw();
    const double pixels=world_to_pixels.basis.get_column(0).length();
    for(const auto& piece:clippings) for(size_t j=1;j<piece.points.size();++j) {
        Color color=piece.colors[j-1].lerp(piece.colors[j],.5);
        color.a*=std::clamp((LIFETIME-piece.age)/.4,0.0,1.0);
        write_segment(out,world_to_pixels.xform(piece.points[j-1]),world_to_pixels.xform(piece.points[j]),
            piece.widths[j-1]*pixels,piece.widths[j]*pixels,color);
    }
    return buffer;
}
}
