#include "beard_simulator.h"
#include <algorithm>
#include <cmath>
#include <limits>
using namespace godot;
namespace lenzforge {
namespace {
Vector2 xy(const Vector3& p) { return Vector2(p.x,p.y); }
bool valid(const Transform3D& t) {
    return t.origin.is_finite() && t.basis[0].is_finite() && t.basis[1].is_finite() && t.basis[2].is_finite() &&
        std::isfinite(t.basis.determinant()) && std::abs(t.basis.determinant())>1e-10;
}
// Convex hull of the blade at both ends of a mouse movement. Sweeping the
// entire contact area prevents gaps even when input skips across thin hairs.
std::vector<Vector2> blade_hull(Vector2 a,Vector2 b,double width,double thickness) {
    std::vector<Vector2> points,hull;
    for(auto center:{a,b}) for(int x:{-1,1}) for(int y:{-1,1}) points.push_back(center+Vector2(x*width*.5,y*thickness*.5));
    std::sort(points.begin(),points.end(),[](auto a,auto b) {return a.x==b.x ? a.y<b.y : a.x<b.x;});
    points.erase(std::unique(points.begin(),points.end()),points.end());
    for(const auto& p:points) {
        while(hull.size()>1 && (hull.back()-hull[hull.size()-2]).cross(p-hull.back())<=0) hull.pop_back();
        hull.push_back(p);
    }
    const size_t lower=hull.size();
    for(int i=int(points.size())-2;i>=0;--i) {
        while(hull.size()>lower && (hull.back()-hull[hull.size()-2]).cross(points[i]-hull.back())<=0) hull.pop_back();
        hull.push_back(points[i]);
    }
    hull.pop_back(); return hull;
}
bool entry(const std::vector<Vector2>& hull,Vector2 p,Vector2 q,double padding,double& first) {
    double low=0,high=1;
    for(size_t i=0;i<hull.size();++i) {
        const Vector2 edge=hull[(i+1)%hull.size()]-hull[i];
        const double origin=edge.cross(p-hull[i])+padding*edge.length(),rate=edge.cross(q-p);
        if(std::abs(rate)<1e-10) {if(origin<0) return false; continue;}
        if(rate>0) low=std::max(low,-origin/rate); else high=std::min(high,-origin/rate);
        if(low>high) return false;
    }
    first=low; return true;
}
}

Dictionary BeardSimulator::clip_buzz(const Vector2& from,const Vector2& to,double width,
    const PackedVector3Array& occluder,const PackedInt32Array& triangles,
    const Transform3D& head_to_pixels,const Transform3D& world_to_pixels,double pixel_size) {
    if(!initialized || !from.is_finite() || !to.is_finite() || !std::isfinite(width) || !std::isfinite(pixel_size) ||
        pixel_size<.05 || pixel_size>100 || width<2*pixel_size || width>256*pixel_size ||
        from.distance_to(to)>16384 || !valid(head_to_pixels) || !valid(world_to_pixels) ||
        occluder.size()>100000 || triangles.size()>600000 || triangles.size()%3) return {};
    for(int i=0;i<occluder.size();++i) if(!occluder[i].is_finite()) return {};
    for(int i=0;i<triangles.size();++i) if(triangles[i]<0 || triangles[i]>=occluder.size()) return {};
    const auto hull=blade_hull(from,to,width,4*pixel_size);
    Vector2 low=hull[0],high=low;
    for(auto p:hull) {low=low.min(p);high=high.max(p);}
    // Small local depth tile; cap storage for unusually large/fast sweeps.
    double spacing=std::max(.25,pixel_size*.75);
    const Vector2 extent=high-low;
    spacing=std::max(spacing,std::sqrt(double(extent.x)*extent.y/65536.0));
    const int columns=int(std::ceil(extent.x/spacing))+1,rows=int(std::ceil(extent.y/spacing))+1;
    if(columns>65538 || rows>65538 || int64_t(columns)*rows>200000) return {};
    const double infinity=std::numeric_limits<double>::infinity();
    std::vector<double> depth(columns*rows,infinity),head_depth(columns*rows,infinity);
    std::vector<int> owner(columns*rows,-1),rank(count);
    for(int i=0;i<count;++i) rank[render_order[i]]=i;
    auto cell=[&](Vector2 p) {return std::clamp(int(std::round((p.y-low.y)/spacing)),0,rows-1)*columns+
        std::clamp(int(std::round((p.x-low.x)/spacing)),0,columns-1);};
    auto raster=[&](Vector2 a,Vector2 b,auto visit) {
        const int x0=std::max(0,int(std::floor((a.x-low.x)/spacing))),x1=std::min(columns-1,int(std::ceil((b.x-low.x)/spacing)));
        const int y0=std::max(0,int(std::floor((a.y-low.y)/spacing))),y1=std::min(rows-1,int(std::ceil((b.y-low.y)/spacing)));
        for(int y=y0;y<=y1;++y) for(int x=x0;x<=x1;++x) visit(y*columns+x,low+Vector2(x*spacing,y*spacing));
    };
    std::vector<CutHit> hits;
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
            const double radius=std::max(w0,w1)+spacing*.75;
            const Vector2 margin(radius,radius);
            if((p.max(q)+margin).x<low.x || (p.min(q)-margin).x>high.x ||
               (p.max(q)+margin).y<low.y || (p.min(q)-margin).y>high.y) continue;
            raster(p.min(q)-margin,p.max(q)+margin,[&](int k,Vector2 at) {
                const double t=std::clamp(double((at-p).dot(delta))/square,0.0,1.0);
                const double w=w0+(w1-w0)*t+spacing*.75;
                if(at.distance_squared_to(p+delta*t)>w*w || a.root[3]+(a.tip[3]-a.root[3])*(j+t)/segments<.001) return;
                const double z=p3.z+(q3.z-p3.z)*t-bias;
                if(z<depth[k]) {depth[k]=z;owner[k]=s;}
            });
            double t=0;
            if(entry(hull,p,q,std::max(w0,w1),t) && a.root[3]+(a.tip[3]-a.root[3])*(j+t)/segments>=.001)
                hits.push_back({s,j,t,0,p3.z+(q3.z-p3.z)*t});
        }
    }
    if(hits.empty()) return {};
    std::vector<Vector3> mesh(occluder.size());
    for(int i=0;i<occluder.size();++i) mesh[i]=head_to_pixels.xform(occluder[i]);
    for(int i=0;i<triangles.size();i+=3) {
        const Vector3 a=mesh[triangles[i]],b=mesh[triangles[i+1]],c=mesh[triangles[i+2]];
        const Vector2 ab=xy(b-a),ac=xy(c-a);
        const double determinant=ab.cross(ac);
        if(std::abs(determinant)<1e-9) continue;
        raster(xy(a).min(xy(b)).min(xy(c)),xy(a).max(xy(b)).max(xy(c)),[&](int k,Vector2 at) {
            const Vector2 p=at-xy(a);
            const double v=p.cross(ac)/determinant,w=ab.cross(p)/determinant;
            if(v>=0 && w>=0 && v+w<=1) head_depth[k]=std::min(head_depth[k],a.z+(b.z-a.z)*v+(c.z-a.z)*w);
        });
    }
    std::vector<CutHit> chosen(count,CutHit{-1,0,0,0,0});
    for(const auto& hit:hits) {
        const int base=hit.strand*(segments+1)+hit.link;
        const int k=cell(xy(positions[base].lerp(positions[base+1],hit.t)));
        if(owner[k]!=hit.strand || hit.depth>head_depth[k]+scale*.001) continue;
        auto& best=chosen[hit.strand];
        if(best.strand<0 || hit.link+hit.t<best.link+best.t) best=hit;
    }
    return apply_clips(chosen,world_to_pixels);
}
}
