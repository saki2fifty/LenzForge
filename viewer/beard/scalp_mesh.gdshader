shader_type spatial;
render_mode cull_back, unshaded;
uniform vec4 base_color : source_color = vec4(.19,.125,.1,1);
uniform vec4 highlight_color : source_color = vec4(.47,.32,.23,1);
uniform int style = 0;
uniform bool sculpted = false;
uniform float sweep = .65;
uniform float curl = .08;
uniform bool head_occlusion_enabled = false;
uniform sampler2D head_depth : filter_nearest, repeat_disable;
uniform float head_depth_bias = .004;
uniform vec2 frame_size = vec2(1280,720);
varying vec3 local_point;
varying vec3 world_point;
varying vec3 world_normal;
void vertex() {
	local_point = VERTEX;
	world_point = (MODEL_MATRIX*vec4(VERTEX,1)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	if (head_occlusion_enabled) {
		vec2 uv = vec2(world_point.x+frame_size.x*.5,frame_size.y*.5-world_point.y)/frame_size;
		if (-world_point.z/frame_size.x > texture(head_depth,uv).r+head_depth_bias) discard;
	}
	vec3 p = local_point;
	float grain;
	if (sculpted) {
		// Flow UVs follow each sculpted lock; derivative filtering avoids shimmer.
		float phase = UV.x*180.0+sin(UV.y*8.0)*1.8;
		float fade = 1.0-smoothstep(.7,3.0,fwidth(phase));
		grain = .5+(.32*sin(phase)+.18*sin(phase*2.31+1.0))*fade;
	} else if (style==2) {
		vec3 phase = p*(110.0+curl*80.0)+sin(p.yzx*77.0);
		vec3 wave = sin(phase);
		float fade = 1.0-smoothstep(.7,3.0,length(fwidth(phase)));
		grain = .5+.5*wave.x*wave.y*wave.z*fade;
	} else {
		float phase = (p.x+sweep*p.z*.7)*520.0+p.y*32.0+sin(p.z*18.0)*curl*4.0;
		float fade = 1.0-smoothstep(.7,3.0,fwidth(phase));
		grain = .5+.5*sin(phase)*fade;
	}
	vec3 normal = normalize(world_normal);
	float key = max(dot(normal,normalize(vec3(-.5,.8,1))),0.0);
	float fill = max(dot(normal,normalize(vec3(.8,.15,-.6))),0.0);
	float shine = pow(max(dot(normal,normalize(vec3(-.3,.5,1))),0.0),sculpted ? 12.0 : 24.0)*(sculpted ? .085 : .045);
	vec3 tint = mix(base_color.rgb,highlight_color.rgb,.12+grain*.12);
	ALBEDO = tint*(.38+key*.7+fill*.22)*(.9+grain*.1)+vec3(shine);
}
