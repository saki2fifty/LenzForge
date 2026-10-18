uniform bool face_ready = false;
uniform sampler2D face_mask : filter_linear, repeat_disable;
uniform vec4 face_bounds = vec4(0);
uniform float face_width = 200.0;
uniform vec2 face_right = vec2(1,0);
uniform vec4 cheeks = vec4(0);
uniform float fx_skin_smoothing = .35;
uniform float fx_skin_detail = .65;
uniform float fx_face_brightness = 0.0;
uniform float fx_face_warmth = 0.0;
uniform float fx_blush = 0.0;
uniform float fx_lip_tint = 0.0;
uniform vec4 fx_blush_color : source_color = vec4(.875,.471,.565,1);
uniform vec4 fx_lip_color : source_color = vec4(.722,.251,.333,1);
const vec2 SKIN_TAPS[8] = vec2[8](vec2(1,0),vec2(-1,0),vec2(0,1),vec2(0,-1),
    vec2(.707,.707),vec2(-.707,.707),vec2(.707,-.707),vec2(-.707,-.707));

vec3 facial_source(vec2 p) {
    float y = 1.164383*(texture(y_texture,p).r-16.0/255.0);
    vec2 uv = texture(uv_texture,p).rg-vec2(128.0/255.0);
    return clamp(vec3(y+1.596027*uv.y,y-.391762*uv.x-.812968*uv.y,y+2.017232*uv.x),vec3(0),vec3(1));
}
vec3 tint_with_detail(vec3 rgb, vec3 tint, float strength) {
    float luminance = dot(rgb,vec3(.299,.587,.114));
    vec3 target = tint*luminance/max(.05,dot(tint,vec3(.299,.587,.114)));
    return mix(rgb,target,strength);
}
float cheek_weight(vec2 pixels) {
    vec2 oriented = vec2(dot(pixels,face_right),dot(pixels,vec2(-face_right.y,face_right.x)));
    oriented /= vec2(.16,.12)*face_width;
    return exp(-2.5*dot(oriented,oriented));
}
vec3 facial_effects(vec2 p, vec3 rgb) {
    if (!face_ready || p.x<face_bounds.x || p.y<face_bounds.y || p.x>face_bounds.z || p.y>face_bounds.w) return rgb;
    vec2 texel = 1.0/vec2(textureSize(face_mask,0));
    // Feather just the anatomical boundary, not the camera's facial features.
    vec3 region = texture(face_mask,p).rgb*.5;
    region += .125*(texture(face_mask,p+vec2(texel.x,0)).rgb+texture(face_mask,p-vec2(texel.x,0)).rgb
        +texture(face_mask,p+vec2(0,texel.y)).rgb+texture(face_mask,p-vec2(0,texel.y)).rgb);
    vec2 dimensions = vec2(textureSize(y_texture,0));
    if (region.r>.001) {
        if (fx_skin_smoothing>0.0) {
            vec3 original = facial_source(p);
            vec3 sum = original*2.0;
            float total = 2.0;
            float sigma = mix(.20,.035,fx_skin_detail);
            float radius = clamp(face_width*.018,1.0,10.0);
            for (int i=0;i<8;i++) {
                vec2 q = p+SKIN_TAPS[i]*radius/dimensions;
                vec3 sample_rgb = facial_source(q);
                vec3 difference = sample_rgb-original;
                float weight = exp(-dot(difference,difference)/(2.0*sigma*sigma))*texture(face_mask,q).r;
                sum += sample_rgb*weight; total += weight;
            }
            rgb = mix(rgb,sum/total,fx_skin_smoothing*region.r);
        }
        rgb += region.r*(vec3(fx_face_brightness)+vec3(fx_face_warmth,0,-fx_face_warmth));
        if (fx_blush>0.0) {
            float cheeks_weight = max(cheek_weight((p-cheeks.xy)*dimensions),cheek_weight((p-cheeks.zw)*dimensions));
            rgb = tint_with_detail(rgb,fx_blush_color.rgb,fx_blush*.5*region.r*cheeks_weight);
        }
    }
    if (fx_lip_tint>0.0 && region.b>.001) rgb = tint_with_detail(rgb,fx_lip_color.rgb,fx_lip_tint*.85*region.b);
    return rgb;
}
