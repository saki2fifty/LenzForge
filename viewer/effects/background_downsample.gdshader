shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D y_texture : filter_linear, repeat_disable;
uniform sampler2D uv_texture : filter_linear, repeat_disable;
uniform sampler2D person_mask : filter_linear, repeat_disable;
uniform float edge_softness = .12;
vec4 background(vec2 p) {
	float y = 1.164383*(texture(y_texture,p).r-16.0/255.0);
	vec2 uv = texture(uv_texture,p).rg-vec2(128.0/255.0);
	vec3 rgb = clamp(vec3(y+1.596027*uv.y,y-.391762*uv.x-.812968*uv.y,y+2.017232*uv.x),vec3(0),vec3(1));
	float weight = 1.0-texture(person_mask,p).r;
	return vec4(rgb*weight,weight);
}
void fragment() {
	// Four bilinear samples prefilter the 4x reduction before the wide blur.
	vec2 step_uv = 1.0/vec2(textureSize(y_texture,0));
	COLOR = .25*(background(UV+step_uv)+background(UV-step_uv)
		+background(UV+step_uv*vec2(-1,1))+background(UV+step_uv*vec2(1,-1)));
}
