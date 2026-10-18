shader_type canvas_item;
uniform sampler2D y_texture : filter_linear, repeat_disable;
uniform sampler2D uv_texture : filter_linear, repeat_disable;
uniform bool mirror = true;
uniform float saturation = 1.0;
uniform float exposure = 0.0;
uniform float contrast = 1.0;
uniform float warmth = 0.0;
uniform bool background_ready = false;
uniform sampler2D person_mask : filter_linear, repeat_disable;
uniform sampler2D background_horizontal : filter_linear, repeat_disable;
uniform float blur_strength = 20.0;
uniform float edge_softness = .12;
uniform float fx_saturation = 1.0;
uniform float fx_contrast = 1.0;
uniform float fx_warmth = 0.0;
uniform float fx_vignette = 0.0;
uniform int fx_filter = 0;
const float WEIGHTS[5] = float[5](.227027,.194595,.121622,.054054,.016216);
#include "res://effects/face_effects.gdshaderinc"

void fragment() {
    vec2 p = UV;
    if (mirror) { p.x = 1.0 - p.x; }
    float y = 1.164383 * (texture(y_texture, p).r - 16.0 / 255.0);
    vec2 uv = texture(uv_texture, p).rg - vec2(128.0 / 255.0);
    // BT.601 limited range, matching OpenCV's BGR -> I420 conversion.
    vec3 rgb = vec3(y + 1.596027 * uv.y, y - 0.391762 * uv.x - 0.812968 * uv.y, y + 2.017232 * uv.x);
    if (background_ready) {
        float foreground = texture(person_mask,p).r;
        if (foreground<.999) {
            vec4 sum = vec4(0);
            float step_y = blur_strength/(4.0*float(textureSize(y_texture,0).y));
            for (int i=-4;i<=4;i++) sum += texture(background_horizontal,p+vec2(0,float(i)*step_y))*WEIGHTS[abs(i)];
            vec3 blurred = sum.rgb/max(sum.a,.001);
            rgb = mix(rgb,blurred,(1.0-foreground)*smoothstep(.01,.15,sum.a));
        }
    }
    rgb = facial_effects(p,rgb);
    float gray = dot(rgb, vec3(0.299, 0.587, 0.114));
    rgb = mix(vec3(gray), rgb, saturation);
    rgb = (rgb - 0.5) * contrast + 0.5 + exposure;
    rgb += vec3(warmth, 0.0, -warmth);
    gray = dot(rgb,vec3(.299,.587,.114));
    rgb = mix(vec3(gray),rgb,fx_saturation);
    rgb = (rgb-.5)*fx_contrast+.5+vec3(fx_warmth,0,-fx_warmth);
    if (fx_filter==1) rgb = vec3(dot(rgb,vec3(.299,.587,.114)));
    else if (fx_filter==2) rgb = vec3(dot(rgb,vec3(.393,.769,.189)),dot(rgb,vec3(.349,.686,.168)),dot(rgb,vec3(.272,.534,.131)));
    else if (fx_filter==3) rgb = 1.0-rgb;
    else if (fx_filter==4) rgb = floor(clamp(rgb,vec3(0),vec3(1))*5.0+.5)/5.0;
    rgb *= 1.0-fx_vignette*smoothstep(.20,.72,length(UV-.5));
    COLOR = vec4(clamp(rgb, vec3(0.0), vec3(1.0)), 1.0);
}
