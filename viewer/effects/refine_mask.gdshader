shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D raw_mask : filter_linear, repeat_disable;
uniform sampler2D y_texture : filter_linear, repeat_disable;
uniform sampler2D uv_texture : filter_linear, repeat_disable;
uniform sampler2D room_reference : filter_nearest, repeat_disable;
uniform float person_confidence = .65;
uniform float edge_softness = .12;
uniform float edge_inset = .5;
uniform bool room_ready = false;
uniform float room_tolerance = .10;
#include "res://effects/room_sample.gdshaderinc"
void fragment() {
	float confidence = texture(raw_mask,UV).r;
	if (edge_inset>0.0) {
		vec2 step_uv = vec2(edge_inset)/vec2(textureSize(raw_mask,0));
		for (int y=-1;y<=1;y++) for (int x=-1;x<=1;x++)
			confidence = min(confidence,texture(raw_mask,UV+vec2(float(x),float(y))*step_uv).r);
	}
	float person = smoothstep(max(.0,person_confidence-edge_softness),min(1.0,person_confidence+edge_softness),confidence);
	if (room_ready) {
		vec3 difference = abs(room_sample(UV,vec2(textureSize(room_reference,0)))-texture(room_reference,UV).rgb);
		float changed = max(difference.r,max(difference.g,difference.b));
		// Re-evaluate every video frame, so newly exposed wall is blurred even
		// while an older AI mask still identifies a hand in that position.
		person *= smoothstep(room_tolerance*.5,room_tolerance,changed);
	}
	COLOR = vec4(vec3(person),1);
}
