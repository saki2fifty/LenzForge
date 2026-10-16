// Shared depth test for 2D effects, measured points and generated guides.
uniform bool occlusion_enabled = false;
uniform sampler2D head_depth : filter_nearest, repeat_disable;
uniform vec2 video_origin = vec2(0.0);
uniform vec2 video_extent = vec2(1.0);
uniform bool occlusion_mirror = false;
uniform float depth_bias = 0.004;
varying vec2 occlusion_uv;
varying float effect_depth;

vec2 depth_uv(vec2 canvas_position) {
    vec2 uv = (canvas_position - video_origin) / video_extent;
    if (occlusion_mirror) uv.x = 1.0 - uv.x;
    return uv;
}
bool behind_head(vec2 uv, float depth) {
    if (!occlusion_enabled || any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return false;
    return depth > texture(head_depth, uv).r + depth_bias;
}
