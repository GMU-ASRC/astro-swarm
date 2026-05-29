shader_type canvas_item;
render_mode blend_mix;

uniform float pixels : hint_range(10, 400);
uniform vec4 colors[1] : source_color;
uniform float time_speed : hint_range(0.0, 1.0) = 0.05;
uniform float time = 0.0;
uniform float rotation : hint_range(0.0, 6.28) = 0.0;
uniform float seed : hint_range(1, 10);
uniform float circle_amount : hint_range(2.0, 30.0) = 5.0;
uniform float circle_size : hint_range(0.0, 1.0) = 1.0;
uniform float size = 50.0;
uniform int OCTAVES : hint_range(0, 20, 1);

float rand(vec2 co) {
	co = mod(co, vec2(1.0, 1.0) * round(size));
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 15.5453 * seed);
}

vec2 rotate(vec2 v, float angle) {
	v -= vec2(0.5);
	v *= mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
	v += vec2(0.5);
	return v;
}

float circle(vec2 uv) {
	float invert = 1.0 / circle_amount;
	if (mod(uv.y, invert * 2.0) < invert) {
		uv.x += invert * 0.5;
	}
	vec2 rand_co = floor(uv * circle_amount) / circle_amount;
	uv = mod(uv, invert) * circle_amount;
	float r = rand(rand_co);
	r = clamp(r, invert, 1.0 - invert);
	float c = distance(uv, vec2(r));
	return smoothstep(c, c + 0.5, invert * circle_size * rand(rand_co * 1.5));
}

void fragment() {
	vec2 pixelized = floor(UV * pixels) / pixels;
	vec2 uv = rotate(pixelized, rotation);
	float angle = atan(uv.x - 0.5, uv.y - 0.5);
	float d = distance(pixelized, vec2(0.5));
	float c = 0.0;
	for (int i = 0; i < 15; i++) {
		float r = rand(vec2(float(i)));
		vec2 circle_uv = vec2(d, angle);
		c += circle(circle_uv * size - time * time_speed - (1.0 / d) * 0.1 + r);
	}
	c *= 0.37 - d;
	c = step(0.07, c - d);
	COLOR = vec4(colors[0].rgb, c * colors[0].a);
}
