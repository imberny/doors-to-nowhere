shader_type spatial;
render_mode unshaded;

uniform sampler2D camera_texture;
uniform float distance_factor;
uniform vec3 portal_plane;
uniform float portal_plane_dist;


bool portal_culls(vec3 vertex, mat4 cam) {
	vec3 pos = (cam * vec4(vertex, 1.0)).xyz;
	return portal_plane.x * pos.x
			+ portal_plane.y * pos.y
			+ portal_plane.z * pos.z
			+ portal_plane_dist < -0.1;
}

void fragment() {
	if (portal_culls(VERTEX, CAMERA_MATRIX)) {
		discard;
	} else {
		float dist = distance_factor;//1f;
		float aspect = VIEWPORT_SIZE.y / VIEWPORT_SIZE.x;
		//	ALBEDO = texture(camera_texture, vec2(SCREEN_UV.x * aspect + SCREEN_UV.x * aspect/2f, SCREEN_UV.y)).xyz;
		ALBEDO = texture(camera_texture, SCREEN_UV).xyz;
	}
}
