shader_type canvas_item;
uniform sampler2D y_texture : filter_linear, repeat_disable;
uniform sampler2D uv_texture : filter_linear, repeat_disable;
uniform bool mirror = true;
uniform float saturation = 1.0;
uniform float exposure = 0.0;
uniform float contrast = 1.0;
uniform float warmth = 0.0;

void fragment() {
    vec2 p = UV;
    if (mirror) { p.x = 1.0 - p.x; }
    float y = 1.164383 * (texture(y_texture, p).r - 16.0 / 255.0);
    vec2 uv = texture(uv_texture, p).rg - vec2(128.0 / 255.0);
    // BT.601 limited range, matching OpenCV's BGR -> I420 conversion.
    vec3 rgb = vec3(y + 1.596027 * uv.y, y - 0.391762 * uv.x - 0.812968 * uv.y, y + 2.017232 * uv.x);
    float gray = dot(rgb, vec3(0.299, 0.587, 0.114));
    rgb = mix(vec3(gray), rgb, saturation);
    rgb = (rgb - 0.5) * contrast + 0.5 + exposure;
    rgb += vec3(warmth, 0.0, -warmth);
    COLOR = vec4(clamp(rgb, vec3(0.0), vec3(1.0)), 1.0);
}
