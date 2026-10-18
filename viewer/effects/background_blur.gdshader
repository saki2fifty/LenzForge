shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D background_small : filter_linear, repeat_disable;
uniform vec2 source_size = vec2(1280,720);
uniform float blur_strength = 20.0;
const float WEIGHTS[5] = float[5](.227027,.194595,.121622,.054054,.016216);
void fragment() {
	vec4 sum = vec4(0);
	float step_x = blur_strength/(4.0*source_size.x);
	for (int i=-4;i<=4;i++) {
		vec2 p = UV+vec2(float(i)*step_x,0);
		sum += texture(background_small,p)*WEIGHTS[abs(i)];
	}
	// Premultiplied background only: foreground colors do not bleed into blur.
	COLOR = sum;
}
