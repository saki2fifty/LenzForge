#include "head_collider.h"
#include <algorithm>
#include <cmath>
#include <limits>
#include <numeric>
using namespace godot;
namespace lenzforge {
namespace {
Vector3 closest(const Vector3 &p,const Vector3 &a,const Vector3 &b,const Vector3 &c,Vector3 &weights) {
    const Vector3 ab=b-a, ac=c-a, ap=p-a;
    const float d1=ab.dot(ap), d2=ac.dot(ap);
    if(d1<=0 && d2<=0) { weights=Vector3(1,0,0); return a; }
    const Vector3 bp=p-b;
    const float d3=ab.dot(bp), d4=ac.dot(bp);
    if(d3>=0 && d4<=d3) { weights=Vector3(0,1,0); return b; }
    const float vc=d1*d4-d3*d2;
    if(vc<=0 && d1>=0 && d3<=0) { float v=d1/(d1-d3); weights=Vector3(1-v,v,0); return a+ab*v; }
    const Vector3 cp=p-c;
    const float d5=ab.dot(cp), d6=ac.dot(cp);
    if(d6>=0 && d5<=d6) { weights=Vector3(0,0,1); return c; }
    const float vb=d5*d2-d1*d6;
    if(vb<=0 && d2>=0 && d6<=0) { float w=d2/(d2-d6); weights=Vector3(1-w,0,w); return a+ac*w; }
    const float va=d3*d6-d5*d4;
    if(va<=0 && d4-d3>=0 && d5-d6>=0) { float w=(d4-d3)/((d4-d3)+(d5-d6)); weights=Vector3(0,1-w,w); return b+(c-b)*w; }
    const float inverse=1/(va+vb+vc);
    weights=Vector3(1-(vb+vc)*inverse,vb*inverse,vc*inverse);
    return a+ab*weights.y+ac*weights.z;
}
float box_distance(const Vector3 &p,const Vector3 &low,const Vector3 &high) {
    Vector3 d=(low-p).max(p-high).max(Vector3()); return d.length_squared();
}
bool crosses_box(const Vector3 &p,const Vector3 &delta,const Vector3 &low,const Vector3 &high,float limit) {
    float begin=0,end=limit;
    for(int axis=0;axis<3;++axis) {
        if(std::abs(delta[axis])<1e-8) { if(p[axis]<low[axis] || p[axis]>high[axis]) return false; }
        else {
            float a=(low[axis]-p[axis])/delta[axis], b=(high[axis]-p[axis])/delta[axis];
            if(a>b) std::swap(a,b);
            begin=std::max(begin,a); end=std::min(end,b);
            if(begin>end) return false;
        }
    }
    return true;
}
}
void HeadCollider::clear() { tree.clear(); faces.clear(); order.clear(); topology.clear(); }
bool HeadCollider::update(const PackedVector3Array &vertices,const PackedInt32Array &indices) {
    const int vertex_count=vertices.size(), index_count=indices.size();
    if(!vertex_count && !index_count) { clear(); return true; }
    if(vertex_count>10000 || !vertex_count || !index_count || index_count>100000 || index_count%3) return false;
    const auto *vp=vertices.ptr(); const auto *ip=indices.ptr();
    for(int i=0;i<vertex_count;++i) if(!vp[i].is_finite()) return false;
    for(int i=0;i<index_count;++i) if(ip[i]<0 || ip[i]>=vertex_count) return false;
    const bool rebuild=tree.empty() || topology!=indices;
    topology=indices;
    faces.resize(index_count/3);
    for(int i=0;i<int(faces.size());++i) {
        auto &f=faces[i];
        for(int j=0;j<3;++j) f.ids[j]=ip[i*3+j];
        f.a=vp[f.ids[0]]; f.b=vp[f.ids[1]]; f.c=vp[f.ids[2]];
        f.low=f.a.min(f.b).min(f.c); f.high=f.a.max(f.b).max(f.c);
        const Vector3 cross=(f.b-f.a).cross(f.c-f.a);
        const float area=cross.length();
        f.normal=area>1e-6 ? cross/area : Vector3();
        f.bary_u=area>1e-6 ? (f.c-f.a).cross(f.normal)/area : Vector3();
        f.bary_v=area>1e-6 ? f.normal.cross(f.b-f.a)/area : Vector3();

    }
    if(rebuild) {
        order.resize(faces.size()); std::iota(order.begin(),order.end(),0);
        tree.clear(); tree.reserve(faces.size()*2); partition(0,int(faces.size()));
    } else refit(0);
    center=(tree[0].low+tree[0].high)*.5;
    for(auto &f:faces) f.plane=(f.a-center).dot(f.normal);
    build_grid();
    return true;
}
int HeadCollider::partition(int start,int count) {
    Branch node; node.start=start; node.count=count;
    node.low=faces[order[start]].low; node.high=faces[order[start]].high;
    for(int i=start+1;i<start+count;++i) { node.low=node.low.min(faces[order[i]].low); node.high=node.high.max(faces[order[i]].high); }
    const int index=int(tree.size()); tree.push_back(node);
    if(count<=6) return index;
    const Vector3 extent=node.high-node.low;
    const int axis=extent.x>extent.y ? (extent.x>extent.z ? 0 : 2) : (extent.y>extent.z ? 1 : 2);
    const int middle=start+count/2;
    std::nth_element(order.begin()+start,order.begin()+middle,order.begin()+start+count,[&](int a,int b) {
        return faces[a].low[axis]+faces[a].high[axis]<faces[b].low[axis]+faces[b].high[axis];
    });
    tree[index].left=partition(start,count/2); tree[index].right=partition(middle,count-count/2);
    return index;
}
void HeadCollider::refit(int index) {
    auto &node=tree[index];
    if(node.left>=0) {
        refit(node.left); refit(node.right);
        node.low=tree[node.left].low.min(tree[node.right].low); node.high=tree[node.left].high.max(tree[node.right].high);
    } else {
        node.low=faces[order[node.start]].low; node.high=faces[order[node.start]].high;
        for(int i=node.start+1;i<node.start+node.count;++i) { node.low=node.low.min(faces[order[i]].low); node.high=node.high.max(faces[order[i]].high); }
    }
}
// Six directional grids map a ray from the interior to a short list of
// actual mesh triangles. Unlike a voxel/SDF proxy this retains triangle-level
// detail, and collision queries are independent of total mesh size.
void HeadCollider::build_grid() {
    coverage.clear();
    std::fill(cell_start,cell_start+CELLS+1,0);
    for(int index=0;index<int(faces.size());++index) {
        const auto &f=faces[index];
        if(f.normal.length_squared()<.5) continue;
        for(int side=0;side<6;++side) {
            const int axis=side/2, u=(axis+1)%3,v=(axis+2)%3;
            const float sign=side%2 ? -1.f : 1.f;
            Vector3 polygon[16],clipped[16];
            int count=3;
            polygon[0]=f.a-center; polygon[1]=f.b-center; polygon[2]=f.c-center;
            // Clip to the four sides of the cube-face pyramid. z>0 follows
            // from these planes; reject the degenerate apex during projection.
            for(int plane=0;plane<4 && count;++plane) {
                auto distance=[&](const Vector3 &p) { return sign*p[axis]+(plane%2 ? -1.f : 1.f)*p[plane<2 ? u:v]; };
                int next=0;
                Vector3 a=polygon[count-1]; float da=distance(a);
                for(int j=0;j<count;++j) {
                    const Vector3 b=polygon[j]; const float db=distance(b);
                    if((da>=0)!=(db>=0)) clipped[next++]=a.lerp(b,da/(da-db));
                    if(db>=0) clipped[next++]=b;
                    a=b; da=db;
                }
                count=next;
                for(int j=0;j<count;++j) polygon[j]=clipped[j];
            }
            if(count<3) continue;
            float min_u=1,min_v=1,max_u=-1,max_v=-1;
            for(int j=0;j<count;++j) {
                float depth=sign*polygon[j][axis];
                if(depth<1e-6) continue;
                float x=polygon[j][u]/depth,y=polygon[j][v]/depth;
                min_u=std::min(min_u,x); max_u=std::max(max_u,x);
                min_v=std::min(min_v,y); max_v=std::max(max_v,y);
            }
            if(min_u>max_u || min_v>max_v) continue;
            auto cell=[](float value) { return std::clamp(int((value+1)*.5f*GRID),0,GRID-1); };
            // Include shared cell boundaries to avoid cracks in the lookup.
            Coverage c={index,side,cell(min_u-1e-6f),cell(min_v-1e-6f),cell(max_u+1e-6f),cell(max_v+1e-6f)};
            coverage.push_back(c);
            for(int y=c.y0;y<=c.y1;++y) for(int x=c.x0;x<=c.x1;++x) ++cell_start[side*GRID*GRID+y*GRID+x+1];
        }
    }
    for(int i=1;i<=CELLS;++i) cell_start[i]+=cell_start[i-1];
    cell_triangles.resize(cell_start[CELLS]);
    int cursor[CELLS]; std::copy(cell_start,cell_start+CELLS,cursor);
    for(const auto &c:coverage)
        for(int y=c.y0;y<=c.y1;++y) for(int x=c.x0;x<=c.x1;++x) cell_triangles[cursor[c.side*GRID*GRID+y*GRID+x]++]=c.triangle;
}
bool HeadCollider::project(Vector3 &point,float clearance,int &hint,Vector3 &normal) const {
    if(tree.empty() || box_distance(point,tree[0].low,tree[0].high)>clearance*clearance) return false;
    Vector3 ray=point-center;
    const Vector3 absolute=ray.abs();
    const int axis=absolute.x>absolute.y ? (absolute.x>absolute.z ? 0:2) : (absolute.y>absolute.z ? 1:2);
    const float major=absolute[axis];
    if(major<1e-6) ray=Vector3(0,0,-1);
    const int side=axis*2+(ray[axis]<0 ? 1:0),u=(axis+1)%3,v=(axis+2)%3;
    auto cell=[](float value) { return std::clamp(int((value+1)*.5f*GRID),0,GRID-1); };
    const int bucket=side*GRID*GRID+cell(ray[v]/std::max(major,1e-6f))*GRID+cell(ray[u]/std::max(major,1e-6f));
    float best=-1;
    int found=-1;
    for(int i=cell_start[bucket];i<cell_start[bucket+1];++i) {
        const int index=cell_triangles[i]; const auto &f=faces[index];
        const float denominator=ray.dot(f.normal);
        if(denominator<1e-7) continue;
        const float t=f.plane/denominator;
        if(t<0 || t<=best) continue;
        const Vector3 offset=center+ray*t-f.a;
        const float a=offset.dot(f.bary_u),b=offset.dot(f.bary_v);
        if(a>=-.00001f && b>=-.00001f && a+b<=1.00001f) { best=t; found=index; }
    }
    // Bridge only small numerical cracks at degenerate tracked triangles. Reject remote
    // extrapolated planes at grazing angles: they cause violent false pushes.
    if(found<0) {
        float nearest=std::numeric_limits<float>::infinity();
        const float gap=(tree[0].high-tree[0].low).length()*.025f;
        const int x=bucket%GRID,y=(bucket/GRID)%GRID;
        for(int dy=std::max(0,y-1);dy<=std::min(GRID-1,y+1);++dy)
            for(int dx=std::max(0,x-1);dx<=std::min(GRID-1,x+1);++dx) {
                const int cell=side*GRID*GRID+dy*GRID+dx;
                for(int i=cell_start[cell];i<cell_start[cell+1];++i) {
                    const int index=cell_triangles[i]; const auto &f=faces[index];
                    const float denominator=ray.dot(f.normal);
                    if(denominator<1e-7) continue;
                    const float t=f.plane/denominator;
                    if(t<0) continue;
                    const Vector3 q=center+ray*t;
                    if(box_distance(q,tree[0].low,tree[0].high)>gap*gap) continue;
                    Vector3 w; const float distance=closest(q,f.a,f.b,f.c,w).distance_squared_to(q);
                    if(distance<nearest && distance<gap*gap) { nearest=distance; found=index; best=t; }
                }
            }
    }
    if(found<0) return false;
    hint=found;
    normal=faces[found].normal;
    const float signed_distance=(1-best)*ray.dot(normal);
    if(signed_distance>=clearance) return false;
    // Project along the ray to the actual surface, then lift by hair radius.
    // This remains outside the head even for a deeply embedded point after a
    // tracking jump. Normal velocity is handled separately by the solver.
    if(signed_distance > -clearance*4) point+=normal*(clearance-signed_distance);
    else point=center+ray*best+normal*clearance;
    return true;
}
bool HeadCollider::sweep(const Vector3 &from,Vector3 &to,float clearance,Vector3 &normal) const {
    if(tree.empty()) return false;
    const Vector3 delta=to-from;
    if(!crosses_box(from,delta,tree[0].low,tree[0].high,1)) return false;
    float nearest=1; bool hit=false;
    auto inspect=[&](int index) {
        const auto &f=faces[index];
        const float denominator=delta.dot(f.normal);
        if(denominator>=-1e-7) return;
        const float t=(f.a-from).dot(f.normal)/denominator;
        if(t<0 || t>nearest) return;
        const Vector3 offset=from+delta*t-f.a;
        const float a=offset.dot(f.bary_u),b=offset.dot(f.bary_v);
        if(a<-.00001f || b<-.00001f || a+b>1.00001f) return;
        nearest=t; normal=f.normal; hit=true;
    };
    auto side_for=[](const Vector3 &p) {
        const Vector3 a=p.abs();
        int axis=a.x>a.y ? (a.x>a.z ? 0:2) : (a.y>a.z ? 1:2);
        return axis*2+(p[axis]<0 ? 1:0);
    };
    const Vector3 a=from-center,b=to-center;
    const int side=side_for(a),axis=side/2,u=(axis+1)%3,v=(axis+2)%3;
    if(side==side_for(b) && std::abs(a[axis])>1e-5 && std::abs(b[axis])>1e-5) {
        // Perspective maps a 3D segment onto a straight line in a cube face.
        // Walk only its crossed cells, reusing the point-contact lookup. Most
        // strand links cross just a few cells; long/seam sweeps use the BVH.
        const float x0=std::clamp((a[u]/std::abs(a[axis])+1)*.5f*GRID,0.f,GRID-.0001f);
        const float y0=std::clamp((a[v]/std::abs(a[axis])+1)*.5f*GRID,0.f,GRID-.0001f);
        const float x1=std::clamp((b[u]/std::abs(b[axis])+1)*.5f*GRID,0.f,GRID-.0001f);
        const float y1=std::clamp((b[v]/std::abs(b[axis])+1)*.5f*GRID,0.f,GRID-.0001f);
        int x=int(x0),y=int(y0),end_x=int(x1),end_y=int(y1);
        const int sx=x1>=x0 ? 1:-1,sy=y1>=y0 ? 1:-1;
        const float dx=std::abs(x1-x0),dy=std::abs(y1-y0);
        const float step_x=dx>1e-8 ? 1/dx:1e20f,step_y=dy>1e-8 ? 1/dy:1e20f;
        float next_x=(sx>0 ? x+1-x0:x0-x)*step_x;
        float next_y=(sy>0 ? y+1-y0:y0-y)*step_y;
        for(int visited=0;visited<GRID*2+1;++visited) {
            const int cell=side*GRID*GRID+y*GRID+x;
            for(int i=cell_start[cell];i<cell_start[cell+1];++i) inspect(cell_triangles[i]);
            if(x==end_x && y==end_y) break;
            if(next_x<next_y) { x+=sx; next_x+=step_x; }
            else { y+=sy; next_y+=step_y; }
            if(x<0 || y<0 || x>=GRID || y>=GRID) break;
        }
    } else {
        int pending[64],count=1; pending[0]=0;
        while(count) {
            const auto &node=tree[pending[--count]];
            if(!crosses_box(from,delta,node.low,node.high,nearest)) continue;
            if(node.left>=0) { pending[count++]=node.left; pending[count++]=node.right; continue; }
            for(int i=node.start;i<node.start+node.count;++i) inspect(order[i]);
        }
    }
    if(hit) to=from+delta*nearest+normal*clearance;
    return hit;
}
}
