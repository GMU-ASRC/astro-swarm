shader_type canvas_item;
render_mode blend_mix;

uniform float pixels : hint_range(10, 400);
uniform float time_speed : hint_range(0.0, 1.0) = 0.05;
uniform float time;
uniform float rotation : hint_range(0.0, 6.28) = 0.0;
uniform vec4 colors[4] : source_color;
uniform int n_colors = 4;
uniform bool should_dither = true;
uniform float seed : hint_range(1, 10);
uniform float size = 50.0;
uniform int OCTAVES : hint_range(0, 20, 1);
uniform float TILES : hint_range(0, 20, 1);

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

vec2 hash2(vec2 p) {
	float r = 523.0 * sin(dot(p, vec2(53.3158, 43.6143)));
	return vec2(fract(15.32354 * r), fract(17.25865 * r));
}

float cells(vec2 p, float num_cells) {
	p *= num_cells;
	float d = 1.0e10;
	for (int xo = -1; xo <= 1; xo++) {
		for (int yo = -1; yo <= 1; yo++) {
			vec2 tp = floor(p) + vec2(float(xo), float(yo));
			tp = p - tp - hash2(mod(tp, num_cells / TILES));
			d = min(d, dot(tp, tp));
		}
	}
	return sqrt(d);
}

bool dither(vec2 uv1, vec2 uv2) {
	return mod(uv1.x + uv2.y, 2.0 / pixels) <= 1.0 / pixels;
}

vec2 spherify(vec2 uv) {
	vec2 centered = uv * 2.0 - 1.0;
	float z = sqrt(1.0 - dot(centered.xy, centered.xy));
	vec2 sphere = centered / (z + 1.0);
	return sphere * 0.5 + 0.5;
}

void fragment() {
	vec2 pixelized = floor(UV * pixels) / pixels;
	float a = step(distance(pixelized, vec2(0.5)), 0.49999);
	bool dith = dither(UV, pixelized);
	pixelized = rotate(pixelized, rotation);
	pixelized = spherify(pixelized);
	float n = cells(pixelized - vec2(time * time_speed * 2.0, 0.0), 10.0);
	n *= cells(pixelized - vec2(time * time_speed * 1.0, 0.0), 20.0);
	n *= 2.0;
	n = clamp(n, 0.0, 1.0);
	if (dith || !should_dither) {
		n *= 1.3;
	}
	float interpolate = floor(n * float(n_colors - 1)) / float(n_colors - 1);
	int idx = clamp(int(interpolate * float(n_colors - 1)), 0, n_colors - 1);
	vec4 col = colors[idx];
	COLOR = vec4(col.rgb, a * col.a);
}
