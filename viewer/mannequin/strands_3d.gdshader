shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D strand_data : filter_nearest, repeat_disable;
uniform sampler2D root_depth : filter_nearest, repeat_disable;
uniform int segments = 8;
uniform float units_per_pixel = .05;
uniform float camera_y = -2.0;
varying vec4 strand_color;
varying vec2 taper;
void vertex() {
	ivec2 at = ivec2((INSTANCE_ID % 64) * 4, INSTANCE_ID / 64);
	vec4 row_x = texelFetch(strand_data, at, 0);
	vec4 row_y = texelFetch(strand_data, at + ivec2(1, 0), 0);
	strand_color = texelFetch(strand_data, at + ivec2(2, 0), 0);
	taper = texelFetch(strand_data, at + ivec2(3, 0), 0).xy;
	// Native 2D MultiMesh output uses +Y down; QuadMesh uses +Y up.
	vec2 local = vec2(VERTEX.x, -VERTEX.y);
	vec2 pixel = vec2(dot(row_x.xy, local) + row_x.w, dot(row_y.xy, local) + row_y.w);
	float depth = texelFetch(root_depth, ivec2(0, INSTANCE_ID / segments), 0).r;
	VERTEX = vec3((pixel.x - 640.0) * units_per_pixel, -(pixel.y - 360.0) * units_per_pixel + camera_y, depth);
}
void fragment() {
	float width = mix(taper.x, taper.y, UV.y);
	float edge = max(fwidth(UV.x * 2.0), .001);
	float coverage = clamp((width - abs(UV.x * 2.0 - 1.0)) / edge + .5, 0.0, 1.0);
	if (coverage * strand_color.a < .001) discard;
	ALBEDO = strand_color.rgb;
	ALPHA = coverage * strand_color.a;
}
