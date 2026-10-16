shader_type canvas_item;
render_mode unshaded;
#include "res://tracking/occlusion.gdshaderinc"
uniform float frame_width = 1280.0;
varying vec2 taper;
void vertex() {
	taper = INSTANCE_CUSTOM.xy;
	occlusion_uv = depth_uv((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy);
	// QuadMesh has spatial UVs: +Y points down on this 2D canvas, so the
	// root is UV.y == 1. The mannequin shader explicitly flips local Y.
	effect_depth = mix(INSTANCE_CUSTOM.z, INSTANCE_CUSTOM.w, 1.0 - UV.y) / frame_width;
}
void fragment() {
	if (behind_head(occlusion_uv, effect_depth)) discard;
	float width = mix(taper.x, taper.y, 1.0 - UV.y);
	float distance_from_center = abs(UV.x * 2.0 - 1.0);
	float edge = max(fwidth(UV.x * 2.0), .001);
	float coverage = clamp((width - distance_from_center) / edge + .5, 0.0, 1.0);
	COLOR.a *= coverage;
}
