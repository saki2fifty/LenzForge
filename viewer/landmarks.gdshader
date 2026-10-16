shader_type canvas_item;
render_mode unshaded;
#include "res://tracking/occlusion.gdshaderinc"

uniform vec4 point_color : source_color = vec4(0.408, 0.875, 0.765, 1.0);
void vertex() {
	occlusion_uv = depth_uv((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy);
	effect_depth = INSTANCE_CUSTOM.r;
}

void fragment() {
	if (behind_head(occlusion_uv, effect_depth)) discard;
	float radius = length(UV * 2.0 - 1.0);
	float edge = max(fwidth(radius), 0.001);
	float coverage = 1.0 - smoothstep(1.0 - edge, 1.0, radius);
	COLOR = vec4(point_color.rgb, point_color.a * coverage);
}
