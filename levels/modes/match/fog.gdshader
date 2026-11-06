shader_type canvas_item;

const int MAX_CIRCLES = 96;

uniform int circle_count = 0;
uniform vec3 circles[MAX_CIRCLES];
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec4 fog_color : source_color = vec4(0.02, 0.02, 0.04, 0.94);
uniform float edge_softness = 60.0;

void fragment() {
	vec2 pixel = UV * rect_size;
	float clear_amount = 0.0;
	for (int index = 0; index < MAX_CIRCLES; index++) {
		if (index >= circle_count) {
			break;
		}
		vec3 circle = circles[index];
		float distance_to_center = distance(pixel, circle.xy);
		float softness = min(edge_softness, circle.z);
		clear_amount = max(clear_amount, 1.0 - smoothstep(circle.z - softness, circle.z, distance_to_center));
	}
	COLOR = vec4(fog_color.rgb, fog_color.a * (1.0 - clear_amount));
}
