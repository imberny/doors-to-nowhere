shader_type spatial;
//render_mode world_vertex_coords;
render_mode unshaded;

uniform sampler2D camera_texture;
uniform float distance_factor;
//
//void vertex() {
//
//}

void fragment() {
	float dist = distance_factor;//1f;
	float aspect = VIEWPORT_SIZE.y / VIEWPORT_SIZE.x;
//	ALBEDO = texture(camera_texture, vec2(SCREEN_UV.x * aspect + SCREEN_UV.x * aspect/2f, SCREEN_UV.y)).xyz;
	ALBEDO = texture(camera_texture, SCREEN_UV).xyz;
}