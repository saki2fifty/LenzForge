#include "head_surface_math.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>
using namespace godot;
namespace lenzforge {
void HeadSurfaceMath::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_reference", "face"), &HeadSurfaceMath::set_reference);
    ClassDB::bind_method(D_METHOD("build_stable", "face", "outline", "rings", "depth", "crown", "sides", "jaw"), &HeadSurfaceMath::build_stable, DEFVAL(1.0), DEFVAL(1.0));
    ClassDB::bind_method(D_METHOD("build", "face", "outline", "rings", "depth", "crown", "sides", "jaw"), &HeadSurfaceMath::build, DEFVAL(1.0), DEFVAL(1.0));
    ClassDB::bind_method(D_METHOD("bind_nearest", "vertices", "triangles", "targets"), &HeadSurfaceMath::bind_nearest);
    ClassDB::bind_method(D_METHOD("sample", "vertices", "indices", "weights"), &HeadSurfaceMath::sample);
}
namespace {
constexpr int pose_anchors[] = {4,5,6,122,127,195,197,234,351,356,454,117,119,121,198,346,348,350,420};
constexpr int pose_count = sizeof(pose_anchors)/sizeof(int);

bool align_head(const Vector3* reference, const Vector3* measured, Transform3D& pose) {
    double weights[pose_count]; std::fill_n(weights,pose_count,1.0);
    const double threshold=std::max(double(measured[234].distance_to(measured[454]))*.015,1e-6);
    for (int iteration=0;iteration<3;++iteration) {
        Vector3 ca,cb; double total=0;
        for (int i=0;i<pose_count;++i) { ca+=reference[pose_anchors[i]]*weights[i]; cb+=measured[pose_anchors[i]]*weights[i]; total+=weights[i]; }
        ca/=total; cb/=total;
        double s[3][3]{},denominator=0;
        for (int i=0;i<pose_count;++i) {
            Vector3 a=reference[pose_anchors[i]]-ca,b=measured[pose_anchors[i]]-cb;
            denominator+=weights[i]*a.length_squared();
            for (int j=0;j<3;++j) for (int k=0;k<3;++k) s[j][k]+=weights[i]*a[j]*b[k];
        }
        if (denominator<1e-12) return false;
        // Horn's symmetric quaternion system. Jacobi finds the largest algebraic
        // eigenvalue, including at 180-degree turns (power iteration can fail).
        double n[4][4] = {
            {s[0][0]+s[1][1]+s[2][2],s[1][2]-s[2][1],s[2][0]-s[0][2],s[0][1]-s[1][0]},
            {s[1][2]-s[2][1],s[0][0]-s[1][1]-s[2][2],s[0][1]+s[1][0],s[2][0]+s[0][2]},
            {s[2][0]-s[0][2],s[0][1]+s[1][0],-s[0][0]+s[1][1]-s[2][2],s[1][2]+s[2][1]},
            {s[0][1]-s[1][0],s[2][0]+s[0][2],s[1][2]+s[2][1],-s[0][0]-s[1][1]+s[2][2]}};
        double v[4][4]{}; for (int i=0;i<4;++i) v[i][i]=1;
        for (int sweep=0;sweep<32;++sweep) {
            int p=0,q=1;
            for (int j=0;j<4;++j) for (int k=j+1;k<4;++k) if (std::abs(n[j][k])>std::abs(n[p][q])) {p=j;q=k;}
            if (std::abs(n[p][q])<denominator*1e-12) break;
            const double angle=.5*std::atan2(2*n[p][q],n[q][q]-n[p][p]),c=std::cos(angle),sn=std::sin(angle);
            const double pp=n[p][p],qq=n[q][q],pq=n[p][q];
            for (int k=0;k<4;++k) if (k!=p && k!=q) {
                const double kp=n[k][p],kq=n[k][q];
                n[k][p]=n[p][k]=c*kp-sn*kq; n[k][q]=n[q][k]=sn*kp+c*kq;
            }
            n[p][p]=c*c*pp-2*c*sn*pq+sn*sn*qq;
            n[q][q]=sn*sn*pp+2*c*sn*pq+c*c*qq; n[p][q]=n[q][p]=0;
            for (int k=0;k<4;++k) {const double kp=v[k][p],kq=v[k][q];v[k][p]=c*kp-sn*kq;v[k][q]=sn*kp+c*kq;}
        }
        int best=0; for (int i=1;i<4;++i) if (n[i][i]>n[best][best]) best=i;
        Basis rotation(Quaternion(v[1][best],v[2][best],v[3][best],v[0][best]).normalized());
        double scale=0;
        for (int i=0;i<pose_count;++i) scale+=weights[i]*(rotation.xform(reference[pose_anchors[i]]-ca)).dot(measured[pose_anchors[i]]-cb);
        scale/=denominator;
        if (!std::isfinite(scale) || scale<=1e-8) return false;
        pose=Transform3D(rotation.scaled(Vector3(scale,scale,scale)),cb-rotation.xform(ca)*scale);
        for (int i=0;i<pose_count;++i) weights[i]=std::min(1.0,threshold/std::max(double(pose.xform(reference[pose_anchors[i]]).distance_to(measured[pose_anchors[i]])),1e-9));
    }
    return true;
}
}
bool HeadSurfaceMath::set_reference(const PackedVector3Array& face) {
    if (!face.is_empty()) {
        if (face.size()!=478) return false;
        for (int i=0;i<478;++i) if (!face[i].is_finite()) return false;
        const Vector3 right=face[454]-face[234],down=face[152]-face[10];
        if (right.length_squared()<1e-10 || right.normalized().cross(down).length_squared()<1e-10) return false;
        Transform3D pose; if (!align_head(face.ptr(),face.ptr(),pose)) return false;
    }
    reference=face; cached_shell.clear(); return true;
}
PackedVector3Array HeadSurfaceMath::build_stable(const PackedVector3Array& face,const PackedInt32Array& outline,int rings,double depth,double crown,double sides,double jaw) {
    if (face.size()!=478) return {};
    const auto* fp=face.ptr();
    for (int i=0;i<478;++i) if (!fp[i].is_finite()) return {};
    if (reference.is_empty() && !set_reference(face)) return {};
    Transform3D pose;
    if (!align_head(reference.ptr(),fp,pose)) return {};
    if (cached_shell.is_empty() || cached_outline!=outline || cached_rings!=rings ||
        cached_shape[0]!=depth || cached_shape[1]!=crown || cached_shape[2]!=sides || cached_shape[3]!=jaw) {
        cached_shell=build(reference,outline,rings,depth,crown,sides,jaw);
        cached_outline=outline; cached_rings=rings;
        cached_shape[0]=depth; cached_shape[1]=crown; cached_shape[2]=sides; cached_shape[3]=jaw;
    }
    if (cached_shell.is_empty()) return {};
    auto result=face; result.resize(cached_shell.size()); auto* out=result.ptrw();
    const auto* shape=cached_shell.ptr(); const auto* rp=reference.ptr(); const auto* op=outline.ptr();
    for (int c=0;c<36;++c) {
        Vector3 delta=fp[op[c]]-pose.xform(rp[op[c]]);
        for (int r=1;r<=rings;++r) {
            const int i=478+(r-1)*36+c;
            // A narrow seam follows skin deformation; the cranium stays rigid.
            const double blend=r==1 ? 4.0/9 : (r==2 ? 1.0/9 : 0.0);
            out[i]=pose.xform(shape[i])+delta*blend;
        }
    }
    return result;
}
PackedVector3Array HeadSurfaceMath::build(const PackedVector3Array &face, const PackedInt32Array &outline, int rings, double depth, double crown, double sides, double jaw) const {
    if (!std::isfinite(sides) || !std::isfinite(jaw) || sides<.8 || sides>1.25 || jaw<.8 || jaw>1.2) return {};
    if (face.size()!=478 || outline.size()!=36 || rings<2 || rings>32 || !std::isfinite(depth) || !std::isfinite(crown) || depth<0 || depth>2 || crown<0 || crown>1) return {};
    const auto *fp=face.ptr(); const auto *op=outline.ptr();
    for (int i=0;i<478;++i) if (!fp[i].is_finite()) return {};
    for (int i=0;i<36;++i) if (op[i]<0 || op[i]>=468) return {};
    Vector3 right=fp[454]-fp[234], down=fp[152]-fp[10];
    const double width=right.length();
    if (width<1e-5) return {};
    right/=width;
    down-=right*down.dot(right);
    if (down.length_squared()<1e-10) return {};
    down.normalize();
    const Vector3 back=right.cross(down), center=(fp[234]+fp[454])*.5;
    PackedVector3Array result=face;
    result.resize(478+rings*36);
    auto *out=result.ptrw();
    for (int r=1;r<=rings;++r) {
        const double t=double(r)/rings, radial=std::cos(t*1.5707963267948966), reach=std::sin(t*1.5707963267948966);
        for (int c=0;c<36;++c) {
            const Vector3 local=fp[op[c]]-center;
            const double upper=std::max(-local.dot(down)/width,0.0);
            const double bend=std::sin(t*3.141592653589793);
            out[478+(r-1)*36+c]=center+(right*local.dot(right)*(1+(sides-1)*bend)+down*(local.dot(down)+std::max(double(local.dot(down)),0.0)*(jaw-1)*bend))*radial
                +back*(local.dot(back)*(1-reach)+depth*width*reach)
                -down*(upper*upper*crown*4*width*std::sin(t*3.141592653589793));
        }
    }
    return result;
}
// Closest point barycentrics, including edges and vertices. Called only when
// bindings change; animation uses the packed, linear-time sample() below.
static Vector3 closest_weights(const Vector3 &p,const Vector3 &a,const Vector3 &b,const Vector3 &c) {
    const Vector3 ab=b-a, ac=c-a, ap=p-a;
    const double d1=ab.dot(ap), d2=ac.dot(ap);
    if (d1<=0 && d2<=0) return Vector3(1,0,0);
    const Vector3 bp=p-b;
    const double d3=ab.dot(bp), d4=ac.dot(bp);
    if (d3>=0 && d4<=d3) return Vector3(0,1,0);
    const double vc=d1*d4-d3*d2;
    if (vc<=0 && d1>=0 && d3<=0) { const double v=d1/(d1-d3); return Vector3(1-v,v,0); }
    const Vector3 cp=p-c;
    const double d5=ab.dot(cp), d6=ac.dot(cp);
    if (d6>=0 && d5<=d6) return Vector3(0,0,1);
    const double vb=d5*d2-d1*d6;
    if (vb<=0 && d2>=0 && d6<=0) { const double w=d2/(d2-d6); return Vector3(1-w,0,w); }
    const double va=d3*d6-d5*d4;
    if (va<=0 && d4-d3>=0 && d5-d6>=0) { const double w=(d4-d3)/((d4-d3)+(d5-d6)); return Vector3(0,1-w,w); }
    const double sum=va+vb+vc;
    if (std::abs(sum)<1e-20) return Vector3(1,0,0);
    return Vector3(1-(vb+vc)/sum,vb/sum,vc/sum);
}
namespace {
struct Triangle { Vector3 a,b,c,low,high,center; int offset; };
struct Branch { Vector3 low,high; int start,count,left=-1,right=-1; };
double box_distance(const Vector3 &p,const Branch &box) {
    double squared=0;
    for (int axis=0;axis<3;++axis) {
        const double d=std::max({double(box.low[axis]-p[axis]),double(p[axis]-box.high[axis]),0.0});
        squared+=d*d;
    }
    return squared;
}
int partition(std::vector<Triangle> &triangles,std::vector<Branch> &tree,int start,int count) {
    Branch node; node.start=start; node.count=count;
    node.low=triangles[start].low; node.high=triangles[start].high;
    for (int i=start+1;i<start+count;++i) {
        node.low=node.low.min(triangles[i].low); node.high=node.high.max(triangles[i].high);
    }
    const int index=int(tree.size()); tree.push_back(node);
    if (count<=8) return index;
    const Vector3 extent=node.high-node.low;
    const int axis=extent.x>extent.y ? (extent.x>extent.z ? 0 : 2) : (extent.y>extent.z ? 1 : 2);
    const int middle=start+count/2;
    std::nth_element(triangles.begin()+start,triangles.begin()+middle,triangles.begin()+start+count,
        [axis](const Triangle &a,const Triangle &b) { return a.center[axis]<b.center[axis]; });
    tree[index].left=partition(triangles,tree,start,count/2);
    tree[index].right=partition(triangles,tree,middle,count-count/2);
    return index;
}
}
Dictionary HeadSurfaceMath::bind_nearest(const PackedVector3Array &vertices, const PackedInt32Array &triangles, const PackedVector3Array &targets) const {
    // Includes at most 768 scalp guides x 16 joints, fitted once per edit.
    if (vertices.size()>10000 || vertices.is_empty() || triangles.is_empty() || triangles.size()>100000 || triangles.size()%3 || targets.size()>16384) return {};
    for (int i=0;i<vertices.size();++i) if (!vertices[i].is_finite()) return {};
    for (int i=0;i<triangles.size();++i) if (triangles[i]<0 || triangles[i]>=vertices.size()) return {};
    PackedInt32Array ids; ids.resize(targets.size()*3);
    PackedVector3Array weights; weights.resize(targets.size());
    auto *ip=ids.ptrw(); auto *wp=weights.ptrw();
    // Exact nearest-point queries with bounding-volume pruning. This tree is
    // built only on placement edits, never on the tracking/render path.
    std::vector<Triangle> faces; faces.reserve(triangles.size()/3);
    for (int t=0;t<triangles.size();t+=3) {
        const Vector3 a=vertices[triangles[t]], b=vertices[triangles[t+1]], c=vertices[triangles[t+2]];
        if ((b-a).cross(c-a).length_squared()<1e-14) continue;
        faces.push_back({a,b,c,a.min(b).min(c),a.max(b).max(c),(a+b+c)/3,t});
    }
    if (faces.empty()) return {};
    std::vector<Branch> tree; tree.reserve(faces.size()*2);
    partition(faces,tree,0,int(faces.size()));
    for (int p=0;p<targets.size();++p) {
        if (!targets[p].is_finite()) return {};
        double best=std::numeric_limits<double>::infinity();
        int best_triangle=std::numeric_limits<int>::max();
        // Median splitting bounds the depth to < 17 at the accepted mesh limit.
        int pending[64], count=1; pending[0]=0;
        while (count) {
            const Branch &node=tree[pending[--count]];
            if (box_distance(targets[p],node)>best+1e-10) continue;
            if (node.left>=0) {
                int near=node.left, far=node.right;
                if (box_distance(targets[p],tree[near])>box_distance(targets[p],tree[far])) std::swap(near,far);
                pending[count++]=far; pending[count++]=near;
                continue;
            }
            for (int j=node.start;j<node.start+node.count;++j) {
                const Triangle &f=faces[j];
                const Vector3 w=closest_weights(targets[p],f.a,f.b,f.c);
                const double distance=targets[p].distance_squared_to(f.a*w.x+f.b*w.y+f.c*w.z);
                if (distance<best || (distance==best && f.offset<best_triangle)) {
                    best=distance; best_triangle=f.offset; wp[p]=w;
                    for (int k=0;k<3;++k) ip[p*3+k]=triangles[f.offset+k];
                }
            }
        }
        if (!std::isfinite(best)) return {};
    }
    Dictionary result; result["indices"]=ids; result["weights"]=weights; return result;
}
PackedVector3Array HeadSurfaceMath::sample(const PackedVector3Array &vertices, const PackedInt32Array &indices, const PackedVector3Array &weights) const {
    const int count=weights.size(), vertex_count=vertices.size();
    if (indices.size()!=count*3 || count>16384) return {};
    const auto *vp=vertices.ptr(); const auto *ip=indices.ptr(); const auto *wp=weights.ptr();
    PackedVector3Array result; result.resize(count); auto *out=result.ptrw();
    for (int i=0;i<count;++i) {
        const int a=ip[i*3],b=ip[i*3+1],c=ip[i*3+2];
        if (a<0 || b<0 || c<0 || a>=vertex_count || b>=vertex_count || c>=vertex_count || !wp[i].is_finite()) return {};
        out[i]=vp[a]*wp[i].x+vp[b]*wp[i].y+vp[c]*wp[i].z;
    }
    return result;
}
}
