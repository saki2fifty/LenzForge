shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D y_texture : filter_linear, repeat_disable;
uniform sampler2D uv_texture : filter_linear, repeat_disable;
#include "res://effects/room_sample.gdshaderinc"
void fragment() { COLOR = vec4(room_sample(UV,vec2(256,144)),1); }
