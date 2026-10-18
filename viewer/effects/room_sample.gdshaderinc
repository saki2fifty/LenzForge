// Shared by the one-shot room capture and the live mask pass: identical sample
// locations and color conversion keep textured walls from defeating cleanup.
vec3 camera_rgb(vec2 p) {
	float y = 1.164383*(texture(y_texture,p).r-16.0/255.0);
	vec2 uv = texture(uv_texture,p).rg-vec2(128.0/255.0);
	return clamp(vec3(y+1.596027*uv.y,y-.391762*uv.x-.812968*uv.y,y+2.017232*uv.x),vec3(0),vec3(1));
}
vec3 room_sample(vec2 p, vec2 dimensions) {
	vec2 center = (floor(p*dimensions)+.5)/dimensions;
	vec2 step_uv = .25/dimensions;
	return .25*(camera_rgb(center+step_uv)+camera_rgb(center-step_uv)
		+camera_rgb(center+step_uv*vec2(-1,1))+camera_rgb(center+step_uv*vec2(1,-1)));
}
