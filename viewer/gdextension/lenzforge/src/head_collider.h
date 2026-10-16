#pragma once
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <vector>

namespace lenzforge {
// Refit the fixed head topology on tracking updates. Queries allocate nothing.
class HeadCollider {
public:
    bool update(const godot::PackedVector3Array &vertices, const godot::PackedInt32Array &indices);
    void clear();
    bool empty() const { return tree.empty(); }
    bool project(godot::Vector3 &point, float clearance, int &hint, godot::Vector3 &normal) const;
    bool sweep(const godot::Vector3 &from, godot::Vector3 &to, float clearance, godot::Vector3 &normal) const;
private:
    struct Triangle { godot::Vector3 a,b,c,normal,low,high,bary_u,bary_v; float plane; int ids[3]; };
    struct Branch { godot::Vector3 low,high; int start,count,left=-1,right=-1; };
    std::vector<Triangle> faces;
    std::vector<int> order;
    std::vector<Branch> tree;
    static constexpr int GRID=64, CELLS=6*GRID*GRID;
    struct Coverage { int triangle,side,x0,y0,x1,y1; };
    std::vector<Coverage> coverage;
    std::vector<int> cell_triangles;
    int cell_start[CELLS+1] = {};
    godot::Vector3 center;
    void build_grid();
    godot::PackedInt32Array topology;
    int partition(int start, int count);
    void refit(int index);
};
}
