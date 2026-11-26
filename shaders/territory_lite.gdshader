shader_type canvas_item;
// Lite version of territory.gdshader for weak phone GPUs. Same look, much
// cheaper: noise comes from a baked tiling texture (see tools/gen_noise.py)
// instead of being computed per pixel, the mask uses hardware filtering, and
// the seam halo reads a pre-blurred "wide" mask instead of 8 extra taps.
//   mask_tex:  R = territory, G = moonstone   (blurred on the CPU)
//   wide_tex:  R = territory, blurred wider    (for the seam halo)

uniform sampler2D mask_tex : filter_linear;
uniform sampler2D prev_mask_tex : filter_linear;
uniform sampler2D wide_tex : filter_linear;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float flip_progress = 1.0;
uniform vec2 flip_origin = vec2(0.5);
uniform vec2 field_size = vec2(640.0, 744.0);
uniform float corner_radius = 22.0;
uniform float morph = 0.5;
uniform float freeze = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}
// baked equivalents of the full shader's noise(), fbm(), voronoi_edge()
float noise1(vec2 p) { return texture(noise_tex, p / 32.0).b; }
float fbm1(vec2 p) { return texture(noise_tex, p / 8.0).r; }
float vor1(vec2 p) { return texture(noise_tex, p / 8.0).g * 0.6; }

void fragment() {
	vec2 uv = UV;
	vec2 px = uv * field_size;
	float t = TIME;
	vec2 px1 = 1.0 / field_size;

	vec2 warp = texture(noise_tex, (px * 0.02 + vec2(t * 0.15, -t * 0.12)) / 32.0).ba - 0.5;
	vec2 wuv = uv + warp * 6.0 * px1;
	vec2 m = texture(mask_tex, wuv).rg;
	float vn = m.r, vo = m.r;
	float d_front = 0.0, front = 0.0;
	if (flip_progress < 1.0) {
		vec2 mo = texture(prev_mask_tex, wuv).rg;
		vo = mo.r;
		vec2 asp = vec2(field_size.x / field_size.y, 1.0);
		d_front = distance(uv * asp, flip_origin * asp) + (noise1(uv * 14.0) - 0.5) * 0.12;
		front = flip_progress * 1.5;
		m = mix(m, mo, smoothstep(front - 0.06, front, d_front));
	}
	float m0 = m.r;
	float mb = texture(wide_tex, wuv).r;
	float s = smoothstep(0.44, 0.56, m0);
	float edge = 1.0 - clamp(abs(mb - 0.5) * 2.4, 0.0, 1.0);

	// ---------- Cute
	vec3 cute = mix(vec3(0.86, 0.79, 0.98), vec3(0.98, 0.78, 0.88), uv.y);
	vec2 q = px / 46.0;
	vec2 qd = abs(fract(vec2(q.x + q.y, q.x - q.y) * 0.5) - 0.5);
	float quilt = smoothstep(0.0, 0.06, min(qd.x, qd.y));
	cute *= mix(0.93, 1.0, quilt);
	cute = mix(cute, vec3(1.0), (1.0 - smoothstep(0.0, 0.025, min(qd.x, qd.y))) * step(0.5, fract((q.x + q.y) * 3.0)) * 0.35);
	vec2 sc = floor(px / 38.0);
	float hs = hash(sc);
	vec2 sp = fract(px / 38.0) - 0.5 - (hash2(sc) - 0.5) * 0.5;
	float tw = 0.5 + 0.5 * sin(t * 2.5 + hs * 6.283);
	float star = max(0.0, 1.0 - (abs(sp.x) * abs(sp.y)) * 900.0) * (1.0 - smoothstep(0.0, 0.22, length(sp)));
	cute += vec3(1.0, 0.95, 1.0) * star * tw * step(0.55, fract(hs * 7.31 + 0.13)) * 0.9;
	cute = mix(cute, vec3(1.0, 0.97, 1.0), edge * 0.55);

	// ---------- Scary
	vec2 sm = px * 0.006;
	float smoke = fbm1(sm + vec2(t * 0.03, -t * 0.05));
	float smoke2 = fbm1(sm * 2.2 - vec2(t * 0.06, t * 0.02) + smoke);
	vec3 scary = mix(vec3(0.05, 0.01, 0.025), vec3(0.24, 0.03, 0.07), smoke2);
	float cr = vor1(px * 0.018 + smoke * 0.6);
	float crack = 1.0 - smoothstep(0.0, 0.06, cr);
	float pulse = 0.55 + 0.45 * sin(t * 1.3 + smoke * 6.0);
	scary += vec3(1.0, 0.25, 0.08) * crack * pulse * 0.45 * smoke2;
	scary *= 1.0 - edge * 0.5;

	vec3 col = mix(cute, scary, s);
	float seam = smoothstep(0.22, 0.0, abs(m0 - 0.5));
	float halo = edge * edge;
	float flicker = 0.75 + 0.25 * noise1(px * 0.05 + t * 3.0);
	col += vec3(1.0, 0.35, 0.12) * (seam * 1.1 + halo * 0.35) * s * flicker;
	col = mix(col, vec3(1.0, 0.95, 0.98), seam * (1.0 - s) * 0.85);
	float ink = 1.0 - smoothstep(0.0, 0.035, abs(m0 - 0.5));
	col = mix(col, vec3(0.14, 0.05, 0.12), ink * 0.85);

	if (flip_progress < 1.0) {
		float ring = (1.0 - smoothstep(0.0, 0.04, abs(d_front - front))) * abs(vn - vo);
		col += mix(vec3(1.0, 0.8, 0.95), vec3(1.0, 0.4, 0.1), vn) * ring * 1.6;
	}

	// ---------- Moonstone
	float g = m.g;
	float g_sh = texture(mask_tex, wuv - vec2(5.0, 8.0) * px1).g;
	if (g > 0.01 || g_sh > 0.01) {
		float sh = smoothstep(0.35, 0.6, g_sh);
		col *= 1.0 - sh * 0.45;
		float st = smoothstep(0.44, 0.56, g);
		float gx = (texture(mask_tex, wuv + vec2(3.0, 0.0) * px1).g - g) * 2.0;
		float gy = (texture(mask_tex, wuv + vec2(0.0, 3.0) * px1).g - g) * 2.0;
		float lit = clamp(0.5 - (gx + gy) * 1.6, 0.0, 1.0);
		float spk = noise1(px * 0.25) * 0.5 + noise1(px * 0.06) * 0.5;
		vec3 stone = mix(vec3(0.33, 0.29, 0.44), vec3(0.72, 0.68, 0.86), lit * 0.8 + spk * 0.25);
		float bevel = smoothstep(0.85, 0.55, g) * st;
		stone = mix(stone, vec3(0.82, 0.78, 0.95), bevel * lit * 0.6);
		col = mix(col, stone, st);
		float sink = 1.0 - smoothstep(0.0, 0.05, abs(g - 0.5));
		col = mix(col, vec3(0.14, 0.05, 0.12), sink);
	}

	if (freeze > 0.0) {
		float fr = fbm1(px * 0.03) * 0.6 + 0.4;
		col = mix(col, vec3(0.75, 0.9, 1.0), freeze * 0.35 * fr);
	}

	vec2 b = abs(px - field_size * 0.5) - (field_size * 0.5 - corner_radius);
	float sd = length(max(b, 0.0)) + min(max(b.x, b.y), 0.0) - corner_radius;
	col *= mix(1.0, 0.72, smoothstep(-90.0, 0.0, sd));
	float alpha = 1.0 - smoothstep(-1.0, 1.0, sd);
	COLOR = vec4(col, alpha);
}
