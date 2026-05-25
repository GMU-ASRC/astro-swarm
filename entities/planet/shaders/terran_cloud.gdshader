shader_type canvas_item;
render_mode blend_mix;

uniform float pixels : hint_range(10, 100);
uniform float rotation : hint_range(0.0, 6.28) = 0.0;
uniform float cloud_cover : hint_range(0.0, 1.0);
uniform vec2 light_origin = vec2(0.39, 0.39);
uniform float time_speed : hint_range(-1.0, 1.0) = 0.2;
uniform float stretch : hint_range(1.0, 3.0) = 2.0;
uniform float cloud_curve : hint_range(1.0, 2.0) = 1.3;
uniform float light_border_1 : hint_range(0.0, 1.0) = 0.52;
uniform float light_border_2 : hint_range(0.0, 1.0) = 0.62;
uniform vec4 colors[4] : source_color;
uniform float size = 50.0;
uniform int OCTAVES : hint_range(0, 20, 1);
uniform float seed : hint_range(1, 10);
uniform float time = 0.0;

float rand(vec2 coord) {
	coord = mod(coord, vec2(1.0, 1.0) * round(size));
	return fract(sin(dot(coord.xy, vec2(12.9898, 78.233))) * 15.5453 * seed);
}

float noise(vec2 coord) {
	vec2 i = floor(coord);
	vec2 f = fract(coord);
	float a = rand(i);
	float b = rand(i + vec2(1.0, 0.0));
	float c = rand(i + vec2(0.0, 1.0));
	float d = rand(i + vec2(1.0, 1.0));
	vec2 cubic = f * f * (3.0 - 2.0 * f);
	return mix(a, b, cubic.x) + (c - a) * cubic.y * (1.0 - cubic.x) + (d - b) * cubic.x * cubic.y;
}

float fbm(vec2 coord) {
	float value = 0.0;
	float scale = 0.5;
	for (int i = 0; i < OCTAVES; i++) {
		value += noise(coord) * scale;
		coord *= 2.0;
		scale *= 0.5;
	}
	return value;
}

float circleNoise(vec2 uv) {
	float uv_y = floor(uv.y);
	uv.x += uv_y * 0.31;
	vec2 f = fract(uv);
	float h = rand(vec2(floor(uv.x), floor(uv_y)));
	float m = length(f - 0.25 - (h * 0.5));
	float r = h * 0.25;
	return smoothstep(0.0, r, m * 0.75);
}

float cloud_alpha(vec2 uv) {
	float c_noise = 0.0;
	for (int i = 0; i < 9; i++) {
		c_noise += circleNoise((uv * size * 0.3) + (float(i + 1) + 10.0) + (vec2(time * time_speed, 0.0)));
	}
	return fbm(uv * size + c_noise + vec2(time * time_speed, 0.0));
}

vec2 spherify(vec2 uv) {
	vec2 centered = uv * 2.0 - 1.0;
	float z = sqrt(1.0 - dot(centered.xy, centered.xy));
	vec2 sphere = centered / (z + 1.0);
	return sphere * 0.5 + 0.5;
}

vec2 rotate(vec2 coord, float angle) {
	coord -= 0.5;
	coord *= mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
	return coord + 0.5;
}

void fragment() {
	vec2 uv = floor(UV * pixels) / pixels;
	float d_light = distance(uv, light_origin);
	float a = step(length(uv - vec2(0.5)), 0.49999);
	float d_to_center = distance(uv, vec2(0.5));

	uv = rotate(uv, rotation);
	uv = spherify(uv);
	uv.y += smoothstep(0.0, cloud_curve, abs(uv.x - 0.4));

	float c = cloud_alpha(uv * vec2(1.0, stretch));

	vec4 col = colors[0];
	if (c < cloud_cover + 0.03) {
		col = colors[1];
	}
	if (d_light + c * 0.2 > light_border_1) {
		col = colors[2];
	}
	if (d_light + c * 0.2 > light_border_2) {
		col = colors[3];
	}

	c *= step(d_to_center, 0.5);
	COLOR = vec4(col.rgb, step(cloud_cover, c) * a * col.a);
}
