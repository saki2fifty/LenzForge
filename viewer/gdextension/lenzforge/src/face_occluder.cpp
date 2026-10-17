#include "face_occluder.h"
#include <godot_cpp/core/class_db.hpp>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>
using namespace godot;
namespace lenzforge {
void FaceOccluder::_bind_methods() {
    ClassDB::bind_method(D_METHOD("rasterize", "vertices", "indices", "dimensions", "map_width", "depth_scale"), &FaceOccluder::rasterize, DEFVAL(384), DEFVAL(1.0));
}
Ref<Image> FaceOccluder::rasterize(const PackedVector3Array &vertices, const PackedInt32Array &indices,
                                  Vector2 dimensions, int map_width, double depth_scale) const {
    const int vertex_count=vertices.size(), index_count=indices.size();
    if (!dimensions.is_finite() || dimensions.x <= 0 || dimensions.y <= 0 ||
        !std::isfinite(depth_scale) || depth_scale <= 0 || map_width < 16 || map_width > 768 ||
        vertex_count > 10000 || index_count > 100000 || index_count % 3) return {};
    const int height = std::clamp(int(std::ceil(map_width * dimensions.y / dimensions.x)), 1, 1024);
    const auto *vp=vertices.ptr(); const auto *ip=indices.ptr();
    std::vector<Vector3> points(vertex_count);
    for (int i=0;i<vertex_count;++i) {
        if (!vp[i].is_finite()) return {};
        points[i] = Vector3(vp[i].x * map_width / dimensions.x, vp[i].y * height / dimensions.y, vp[i].z * depth_scale);
        if (!points[i].is_finite()) return {};
    }
    for (int i=0;i<index_count;++i) if (ip[i] < 0 || ip[i] >= vertex_count) return {};
    std::vector<float> depth(map_width*height, 1e10f);
    for (int i=0;i<index_count;i+=3) {
        const Vector3 a=points[ip[i]], b=points[ip[i+1]], c=points[ip[i+2]];
        const float bx=b.x-a.x, by=b.y-a.y, cx=c.x-a.x, cy=c.y-a.y, determinant=bx*cy-by*cx;
        if (std::abs(determinant)<1e-7f) continue;
        const int x0=std::clamp(int(std::floor(std::min({a.x,b.x,c.x}))),0,map_width-1);
        const int x1=std::clamp(int(std::ceil(std::max({a.x,b.x,c.x}))),0,map_width-1);
        const int y0=std::clamp(int(std::floor(std::min({a.y,b.y,c.y}))),0,height-1);
        const int y1=std::clamp(int(std::ceil(std::max({a.y,b.y,c.y}))),0,height-1);
        for(int y=y0;y<=y1;++y) for(int x=x0;x<=x1;++x) {
            const float px=x+.5f-a.x, py=y+.5f-a.y;
            const float u=(px*cy-py*cx)/determinant, v=(bx*py-by*px)/determinant;
            if(u>=0 && v>=0 && u+v<=1) {
                float &at=depth[y*map_width+x];
                at=std::min(at,float(a.z+u*(b.z-a.z)+v*(c.z-a.z)));
            }
        }
    }
    PackedByteArray bytes;
    bytes.resize(depth.size()*sizeof(float));
    std::memcpy(bytes.ptrw(),depth.data(),bytes.size());
    return Image::create_from_data(map_width,height,false,Image::FORMAT_RF,bytes);
}
}
