shader_type spatial;
render_mode unshaded;

uniform sampler2D camera_texture;
uniform float distance_factor;
uniform float scale = 0.766f;
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
		ALBEDO = texture(camera_texture, SCREEN_UV * scale + vec2((1f - scale) / 2f)).xyz;
	}
}
