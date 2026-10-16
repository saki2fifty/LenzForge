shader_type canvas_item;
render_mode unshaded;
#include "res://tracking/occlusion.gdshaderinc"
uniform sampler2D root_depths : filter_nearest, repeat_disable;
uniform int strand_segments = 8;
varying vec2 taper;
void vertex() {
	taper = INSTANCE_CUSTOM.xy;
	occlusion_uv = depth_uv((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy);
	effect_depth = texelFetch(root_depths, ivec2(0, INSTANCE_ID / strand_segments), 0).r;
}
void fragment() {
	if (behind_head(occlusion_uv, effect_depth)) discard;
	float width = mix(taper.x, taper.y, UV.y);
	float distance_from_center = abs(UV.x * 2.0 - 1.0);
	float edge = max(fwidth(UV.x * 2.0), .001);
	float coverage = clamp((width - distance_from_center) / edge + .5, 0.0, 1.0);
	COLOR.a *= coverage;
}
