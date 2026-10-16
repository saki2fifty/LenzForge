shader_type canvas_item;
render_mode unshaded;
varying vec2 taper;
void vertex() {
	taper = INSTANCE_CUSTOM.xy;
}
void fragment() {
	float width = mix(taper.x, taper.y, UV.y);
	float distance_from_center = abs(UV.x * 2.0 - 1.0);
	float edge = max(fwidth(UV.x * 2.0), .001);
	float coverage = clamp((width - distance_from_center) / edge + .5, 0.0, 1.0);
	COLOR.a *= coverage;
}
