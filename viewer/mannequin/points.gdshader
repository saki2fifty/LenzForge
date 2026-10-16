shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 point_color : source_color = vec4(1.0);
void vertex() {
	// Billboard quads; the instance already carries its world position and size.
	VERTEX.z += .055;
}
void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	float coverage = clamp((1.0 - radius) / max(fwidth(radius), .001) + .5, 0.0, 1.0);
	if (coverage * point_color.a < .001) discard;
	ALBEDO = point_color.rgb;
	ALPHA = coverage * point_color.a;
}
