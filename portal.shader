shader_type spatial;
render_mode unshaded;

uniform sampler2D camera_texture;
uniform sampler2D portal_mask;

uniform float distance_factor;
uniform float scale = 0.766f;
uniform vec3 portal_plane;
uniform float portal_plane_dist;


bool is_behind_plane(vec4 pos) {
	return portal_plane.x * pos.x
			+ portal_plane.y * pos.y
			+ portal_plane.z * pos.z
			+ portal_plane_dist > 0.1f;
}

//void vertex() {
//	if (is_behind_plane(CAMERA_MATRIX * vec4(VERTEX, 1.0))) {
//		COLOR = vec4(1.0);
//	} 
//}


void fragment() {
	if (is_behind_plane(CAMERA_MATRIX * vec4(VERTEX, 1.0))) {
		discard;
	} else {
		vec4 mask_value = texture(portal_mask, UV);
		float camera_weight = mask_value.g;
		float outline_weight = mask_value.r;
		vec2 scaled_uv = SCREEN_UV * scale + vec2((1f - scale) / 2f);
		vec3 camera_color = texture(camera_texture, scaled_uv).xyz;
		vec3 outline_color = vec3(sin(UV.x + TIME), cos(UV.y + TIME), sin(UV.y) * cos(UV.x));

		ALBEDO = camera_weight * camera_color + outline_weight * outline_color;
		ALPHA = mask_value.a;
	}
}
