shader_type canvas_item;
render_mode blend_mix;

uniform float pixels : hint_range(10, 400);
uniform vec4 colors[2] : source_color;
uniform float time_speed : hint_range(0.0, 1.0) = 0.05;
uniform float time;
uniform float rotation : hint_range(0.0, 6.28) = 0.0;
uniform bool should_dither = true;
uniform float storm_width : hint_range(0.0, 0.5) = 0.3;
uniform float storm_dither_width : hint_range(0.0, 0.5) = 0.07;
uniform float scale = 1.0;
uniform float seed : hint_range(1, 10);
uniform float circle_amount : hint_range(2.0, 30.0) = 5.0;
uniform float circle_scale : hint_range(0.0, 1.0) = 1.0;
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
	return smoothstep(c, c + 0.5, invert * circle_scale * rand(rand_co * 1.5));
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
	float scl = 0.5;
	for (int i = 0; i < OCTAVES; i++) {
		value += noise(coord) * scl;
		coord *= 2.0;
		scl *= 0.5;
	}
	return value;
}

bool dither(vec2 uv1, vec2 uv2) {
	return mod(uv1.x + uv2.y, 2.0 / pixels) <= 1.0 / pixels;
}

void fragment() {
	vec2 pixelized = floor(UV * pixels) / pixels;
	bool dith = dither(UV, pixelized);
	pixelized = rotate(pixelized, rotation);
	vec2 uv = pixelized;
	float angle = atan(uv.x - 0.5, uv.y - 0.5) * 0.4;
	float d = distance(pixelized, vec2(0.5));
	vec2 circle_uv = vec2(d, angle);
	float n = fbm(circle_uv * size - time * time_speed);
	float nc = circle(circle_uv * scale - time * time_speed + n);
	nc *= 1.5;
	float n2 = fbm(circle_uv * size - time + vec2(100.0, 100.0));
	nc -= n2 * 0.1;
	float a = 0.0;
	if (1.0 - d > nc) {
		if (nc > storm_width - storm_dither_width + d && (dith || !should_dither)) {
			a = 1.0;
		} else if (nc > storm_width + d) {
			a = 1.0;
		}
	}
	float interpolate = floor(n2 + nc);
	int idx = clamp(int(interpolate), 0, 1);
	vec4 col = colors[idx];
	a *= step(n2 * 0.25, d);
	COLOR = vec4(col.rgb, a * col.a);
}
