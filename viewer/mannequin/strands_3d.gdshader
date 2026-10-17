shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D strand_data : filter_nearest, repeat_disable;
uniform int segments = 8;
uniform float units_per_pixel = .05;
uniform float camera_y = -2.0;
uniform vec2 frame_size = vec2(1280.0,720.0);
uniform int strand_count = 1;
uniform float layer_bias = 0.0;
uniform bool head_occlusion_enabled = false;
uniform sampler2D head_depth : filter_nearest, repeat_disable;
uniform float head_depth_bias = .004;
varying vec4 strand_color;
varying vec2 taper;
varying vec2 source_uv;
varying float physical_depth;
void vertex() {
	ivec2 at = ivec2((INSTANCE_ID % 64) * 4, INSTANCE_ID / 64);
	vec4 row_x = texelFetch(strand_data, at, 0);
	vec4 row_y = texelFetch(strand_data, at + ivec2(1, 0), 0);
	strand_color = texelFetch(strand_data, at + ivec2(2, 0), 0);
	vec4 segment = texelFetch(strand_data, at + ivec2(3, 0), 0);
	taper = segment.xy;
	// Native 2D MultiMesh output uses +Y down; QuadMesh uses +Y up.
	vec2 local = vec2(VERTEX.x, -VERTEX.y);
	vec2 pixel = vec2(dot(row_x.xy, local) + row_x.w, dot(row_y.xy, local) + row_y.w);
	physical_depth = mix(segment.z, segment.w, UV.y) / frame_size.x;
	source_uv = pixel/frame_size;
	// Cached root-height rank breaks near-equal depth ties only. Actual depth
	// wins on turns; the head mask continues to use the unmodified depth.
	float bias = layer_bias * float(INSTANCE_ID / segments) / max(float(strand_count-1),1.0);
	float depth = -(mix(segment.z, segment.w, UV.y)-bias) * units_per_pixel;
	VERTEX = vec3((pixel.x - frame_size.x*.5) * units_per_pixel, -(pixel.y - frame_size.y*.5) * units_per_pixel + camera_y, depth);
}
void fragment() {
	if (head_occlusion_enabled && physical_depth > texture(head_depth, source_uv).r + head_depth_bias) discard;
	float width = mix(taper.x, taper.y, UV.y);
	float edge = max(fwidth(UV.x * 2.0), .001);
	float coverage = clamp((width - abs(UV.x * 2.0 - 1.0)) / edge + .5, 0.0, 1.0);
	if (coverage * strand_color.a < .001) discard;
	ALBEDO = strand_color.rgb;
	ALPHA = coverage * strand_color.a;
}
