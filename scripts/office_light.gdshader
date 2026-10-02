shader_type canvas_item;
render_mode unshaded;
uniform vec2 cool_source = vec2(152.0, 520.0);
uniform vec2 warm_source = vec2(405.0, 532.0);
uniform float cool_energy = 0.18;
uniform float warm_energy = 0.24;
varying vec2 canvas_position;
varying vec4 item_color;
void vertex() {
	canvas_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	item_color = COLOR;
}
void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * item_color;
	float cool = pow(max(0.0, 1.0 - distance(canvas_position, cool_source) / 210.0), 2.0);
	float warm = pow(max(0.0, 1.0 - distance(canvas_position, warm_source) / 185.0), 2.0);
	vec3 illumination = vec3(0.94, 0.93, 0.97)
		+ cool * cool_energy * vec3(0.28, 0.65, 1.0)
		+ warm * warm_energy * vec3(1.0, 0.68, 0.30);
	COLOR = vec4(pixel.rgb * illumination, pixel.a);
}
