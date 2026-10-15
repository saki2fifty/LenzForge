shader_type canvas_item;
render_mode unshaded;

uniform vec4 point_color : source_color = vec4(0.408, 0.875, 0.765, 1.0);

void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	float edge = max(fwidth(radius), 0.001);
	float coverage = 1.0 - smoothstep(1.0 - edge, 1.0, radius);
	COLOR = vec4(point_color.rgb, point_color.a * coverage);
}
