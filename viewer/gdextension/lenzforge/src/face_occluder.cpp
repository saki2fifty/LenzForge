#include "face_occluder.h"
#include <godot_cpp/core/class_db.hpp>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <vector>
using namespace godot;
namespace lenzforge {
void FaceOccluder::_bind_methods() {
    ClassDB::bind_method(D_METHOD("rasterize", "vertices", "indices", "dimensions", "map_width"), &FaceOccluder::rasterize, DEFVAL(384));
}
Ref<Image> FaceOccluder::rasterize(const PackedVector3Array &vertices, const PackedInt32Array &indices,
                                  Vector2 dimensions, int map_width) const {
    if (!dimensions.is_finite() || dimensions.x <= 0 || dimensions.y <= 0 ||
        map_width < 16 || map_width > 768 || vertices.size() > 10000 || indices.size() % 3) return {};
    const int height = std::clamp(int(std::ceil(map_width * dimensions.y / dimensions.x)), 1, 1024);
    std::vector<Vector3> points(vertices.size());
    for (int i=0;i<vertices.size();++i) {
        if (!vertices[i].is_finite()) return {};
        points[i] = Vector3(vertices[i].x * map_width / dimensions.x, vertices[i].y * height / dimensions.y, vertices[i].z);
    }
    for (int i=0;i<indices.size();++i) if (indices[i] < 0 || indices[i] >= vertices.size()) return {};
    std::vector<float> depth(map_width*height, 1e10f);
    for (int i=0;i<indices.size();i+=3) {
        const Vector3 a=points[indices[i]], b=points[indices[i+1]], c=points[indices[i+2]];
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
