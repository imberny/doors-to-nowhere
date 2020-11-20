shader_type spatial;
render_mode unshaded;

uniform sampler2D camera_texture;
uniform sampler2D portal_mask;

uniform float distance_factor;


void fragment() {
	vec4 mask_value = texture(portal_mask, UV);
	float camera_weight = mask_value.g;
	float outline_weight = mask_value.r;
	vec3 camera_color = texture(camera_texture, SCREEN_UV).xyz;
	vec3 outline_color = vec3(sin(UV.x + TIME), cos(UV.y + TIME), sin(UV.y) * cos(UV.x));

	ALBEDO = camera_weight * camera_color + outline_weight * outline_color;
	ALPHA = mask_value.a;
}
