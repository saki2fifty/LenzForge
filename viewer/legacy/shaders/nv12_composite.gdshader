shader_type canvas_item;

// NV12 Textures
uniform sampler2D y_texture : filter_linear, repeat_disable;
uniform sampler2D uv_texture : filter_linear, repeat_disable;

// Landmark buffer (478 face landmarks + 10 iris landmarks = 488 total)
uniform vec2 landmarks[488];
uniform int landmark_count = 0;
uniform bool show_landmarks = true;
uniform float landmark_radius = 3.0;
uniform vec4 landmark_color : source_color = vec4(0.0, 1.0, 0.0, 0.8);

// Face mesh connections (optional - can toggle)
uniform bool show_mesh = false;
uniform vec4 mesh_color : source_color = vec4(0.0, 1.0, 0.0, 0.3);

// Video dimensions for coordinate normalization
uniform vec2 video_size = vec2(1280.0, 720.0);

// BT.709 YUV to RGB conversion matrix
const mat3 yuv_to_rgb = mat3(
	vec3(1.164,  1.164,  1.164),
	vec3(0.000, -0.392,  2.017),
	vec3(1.596, -0.813,  0.000)
);

// Convert NV12 to RGB using BT.709 standard
vec3 nv12_to_rgb(vec2 uv) {
	// Sample Y (luminance) from Y plane
	float y = texture(y_texture, uv).r;
	
	// Sample UV (chrominance) from UV plane
	// UV plane is half resolution, but sampler handles this with filtering
	vec2 chroma = texture(uv_texture, uv).rg;
	
	// Convert from [0,1] to YUV range
	vec3 yuv;
	yuv.x = (y * 255.0 - 16.0) / 255.0;      // Y component
	yuv.y = (chroma.r * 255.0 - 128.0) / 255.0; // U component
	yuv.z = (chroma.g * 255.0 - 128.0) / 255.0; // V component
	
	// Apply BT.709 conversion matrix
	vec3 rgb = yuv_to_rgb * yuv;
	
	// Clamp to valid range
	return clamp(rgb, 0.0, 1.0);
}

// Distance field for circle rendering
float circle_sdf(vec2 p, vec2 center, float radius) {
	return length(p - center) - radius;
}

// Draw a landmark point
vec4 draw_landmark(vec2 pixel_pos, vec2 landmark_pos, float radius, vec4 color) {
	float dist = circle_sdf(pixel_pos, landmark_pos, radius);
	
	// Smooth anti-aliased circle
	float alpha = smoothstep(1.0, 0.0, dist);
	
	return vec4(color.rgb, color.a * alpha);
}

// Draw a line between two points (for face mesh)
vec4 draw_line(vec2 pixel_pos, vec2 p1, vec2 p2, float thickness, vec4 color) {
	// Vector from p1 to p2
	vec2 line_vec = p2 - p1;
	float line_len = length(line_vec);
	
	if (line_len < 0.001) return vec4(0.0);
	
	vec2 line_dir = line_vec / line_len;
	
	// Vector from p1 to pixel
	vec2 to_pixel = pixel_pos - p1;
	
	// Project onto line
	float t = dot(to_pixel, line_dir);
	t = clamp(t, 0.0, line_len);
	
	// Closest point on line
	vec2 closest = p1 + line_dir * t;
	
	// Distance from pixel to line
	float dist = length(pixel_pos - closest);
	
	// Smooth anti-aliased line
	float alpha = smoothstep(thickness + 1.0, thickness, dist);
	
	return vec4(color.rgb, color.a * alpha);
}

void fragment() {
	// Get pixel position in screen space
	vec2 pixel_pos = FRAGCOORD.xy;
	
	// Convert to texture coordinates
	vec2 uv = UV;
	
	// Step 1: Convert NV12 to RGB
	vec3 video_rgb = nv12_to_rgb(uv);
	vec4 final_color = vec4(video_rgb, 1.0);
	
	// Step 2: Draw landmarks if enabled
	if (show_landmarks && landmark_count > 0) {
		vec4 landmark_overlay = vec4(0.0);
		
		// Draw each landmark
		for (int i = 0; i < landmark_count && i < 488; i++) {
			vec2 lm_pos = landmarks[i];
			
			// Skip invalid landmarks (0,0 or out of bounds)
			if (lm_pos.x < 0.01 || lm_pos.y < 0.01) continue;
			
			vec4 point = draw_landmark(pixel_pos, lm_pos, landmark_radius, landmark_color);
			
			// Alpha blend
			landmark_overlay = mix(landmark_overlay, point, point.a);
		}
		
		// Composite landmarks over video
		final_color = mix(final_color, vec4(landmark_overlay.rgb, 1.0), landmark_overlay.a);
	}
	
	// Step 3: Draw face mesh connections if enabled
	if (show_mesh && landmark_count >= 478) {
		// Note: Face mesh connections would be defined here
		// For now, just draw outline of face
		// (Full mesh would require connection indices array)
	}
	
	COLOR = final_color;
}
