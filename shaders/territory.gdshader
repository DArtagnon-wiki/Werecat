shader_type canvas_item;
// Renders the Cute/Scary playfield from a low-res territory mask.
// Organic edges come from bilinear-filtered mask + a slow noise warp.
// A radial noise dissolve animates each claim from its closing point.

uniform sampler2D mask_tex : filter_nearest;     // R: 0 = Cute, 1 = Scary (pre-blurred)
uniform sampler2D prev_mask_tex : filter_nearest; // mask before the last claim
uniform float flip_progress = 1.0;               // 0..1 dissolve
uniform vec2 flip_origin = vec2(0.5);            // uv of the closing point
uniform vec2 field_size = vec2(640.0, 760.0);
uniform float corner_radius = 22.0;
uniform float morph = 0.5;                       // overall scary %, for mood

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}
vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}
// distance to nearest voronoi edge (for glowing cracks)
float voronoi_edge(vec2 p) {
	vec2 n = floor(p), f = fract(p);
	float d1 = 8.0, d2 = 8.0;
	for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
		vec2 g = vec2(float(i), float(j));
		vec2 o = hash2(n + g);
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return d2 - d1;
}

// manual bilinear filtering (works the same on every renderer)
float bilinear(sampler2D tex, vec2 uv) {
	vec2 sz = vec2(textureSize(tex, 0));
	vec2 p = clamp(uv * sz - 0.5, vec2(0.0), sz - 1.001);
	ivec2 i = ivec2(floor(p));
	vec2 f = p - floor(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = texelFetch(tex, i, 0).r;
	float b = texelFetch(tex, min(i + ivec2(1, 0), ivec2(sz) - 1), 0).r;
	float c = texelFetch(tex, min(i + ivec2(0, 1), ivec2(sz) - 1), 0).r;
	float d = texelFetch(tex, min(i + ivec2(1, 1), ivec2(sz) - 1), 0).r;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float mask_at(vec2 uv) {
	float vn = bilinear(mask_tex, uv);
	if (flip_progress >= 1.0) return vn;
	float vo = bilinear(prev_mask_tex, uv);
	vec2 asp = vec2(field_size.x / field_size.y, 1.0);
	float d = distance(uv * asp, flip_origin * asp);
	float front = flip_progress * 1.5;
	float reveal = smoothstep(front - 0.06, front, d + (noise(uv * 14.0) - 0.5) * 0.12);
	return mix(vn, vo, reveal);
}

void fragment() {
	vec2 uv = UV;
	vec2 px = uv * field_size;
	float t = TIME;

	// organic wobble on the boundary
	vec2 warp = vec2(noise(px * 0.02 + t * 0.15), noise(px * 0.02 - t * 0.12 + 7.0)) - 0.5;
	vec2 wuv = uv + warp * (6.0 / field_size);
	float m0 = mask_at(wuv);
	// soft distance field: blurred mask
	float mb = 0.0;
	float r = 7.0;
	for (int k = 0; k < 8; k++) {
		float a = float(k) * 0.785398;
		mb += mask_at(wuv + vec2(cos(a), sin(a)) * r / field_size);
	}
	mb = (mb + m0) / 9.0;
	float s = smoothstep(0.44, 0.56, m0);
	float edge = 1.0 - clamp(abs(mb - 0.5) * 2.4, 0.0, 1.0);   // 1 at the seam

	// ---------- Cute: lavender-to-pink quilt with twinkling sparkles
	vec3 cute = mix(vec3(0.86, 0.79, 0.98), vec3(0.98, 0.78, 0.88), uv.y);
	// quilted diamonds
	vec2 q = px / 46.0;
	vec2 qd = abs(fract(vec2(q.x + q.y, q.x - q.y) * 0.5) - 0.5);
	float quilt = smoothstep(0.0, 0.06, min(qd.x, qd.y));
	cute *= mix(0.93, 1.0, quilt);
	// stitches
	cute = mix(cute, vec3(1.0), (1.0 - smoothstep(0.0, 0.025, min(qd.x, qd.y))) * step(0.5, fract((q.x + q.y) * 3.0)) * 0.35);
	// sparkles
	vec2 sc = floor(px / 38.0);
	vec2 sp = fract(px / 38.0) - 0.5 - (hash2(sc) - 0.5) * 0.5;
	float tw = 0.5 + 0.5 * sin(t * 2.5 + hash(sc) * 6.283);
	float star = max(0.0, 1.0 - (abs(sp.x) * abs(sp.y)) * 900.0) * (1.0 - smoothstep(0.0, 0.22, length(sp)));
	cute += vec3(1.0, 0.95, 1.0) * star * tw * step(0.55, hash(sc + 3.1)) * 0.9;
	// soft glow toward the seam
	cute = mix(cute, vec3(1.0, 0.97, 1.0), edge * 0.55);

	// ---------- Scary: oxblood smoke with slow ember cracks
	vec2 sm = px * 0.006;
	float smoke = fbm(sm + vec2(t * 0.03, -t * 0.05));
	float smoke2 = fbm(sm * 2.2 - vec2(t * 0.06, t * 0.02) + smoke);
	vec3 scary = mix(vec3(0.05, 0.01, 0.025), vec3(0.24, 0.03, 0.07), smoke2);
	float cr = voronoi_edge(px * 0.018 + smoke * 0.6);
	float crack = 1.0 - smoothstep(0.0, 0.06, cr);
	float pulse = 0.55 + 0.45 * sin(t * 1.3 + smoke * 6.0);
	scary += vec3(1.0, 0.25, 0.08) * crack * pulse * 0.45 * smoke2;
	// darker toward the seam, then a burning rim right at it
	scary *= 1.0 - edge * 0.5;

	vec3 col = mix(cute, scary, s);
	// seam: hot ember line on the scary side, white glow on the cute side
	float seam = smoothstep(0.22, 0.0, abs(m0 - 0.5));
	float halo = edge * edge;
	float flicker = 0.75 + 0.25 * noise(px * 0.05 + t * 3.0);
	col += vec3(1.0, 0.35, 0.12) * (seam * 1.1 + halo * 0.35) * s * flicker;
	col = mix(col, vec3(1.0, 0.95, 0.98), seam * (1.0 - s) * 0.85);
	// a thin dark ink line exactly on the boundary for a crisp, drawn look
	float ink = 1.0 - smoothstep(0.0, 0.035, abs(m0 - 0.5));
	col = mix(col, vec3(0.14, 0.05, 0.12), ink * 0.85);

	// dissolve front glow
	if (flip_progress < 1.0) {
		float vn = bilinear(mask_tex, uv), vo = bilinear(prev_mask_tex, uv);
		vec2 asp = vec2(field_size.x / field_size.y, 1.0);
		float d = distance(uv * asp, flip_origin * asp) + (noise(uv * 14.0) - 0.5) * 0.12;
		float front = flip_progress * 1.5;
		float ring = (1.0 - smoothstep(0.0, 0.04, abs(d - front))) * abs(vn - vo);
		col += mix(vec3(1.0, 0.8, 0.95), vec3(1.0, 0.4, 0.1), vn) * ring * 1.6;
	}

	// inner vignette + rounded corners
	vec2 b = abs(px - field_size * 0.5) - (field_size * 0.5 - corner_radius);
	float sd = length(max(b, 0.0)) + min(max(b.x, b.y), 0.0) - corner_radius;
	col *= mix(1.0, 0.72, smoothstep(-90.0, 0.0, sd));
	float alpha = 1.0 - smoothstep(-1.0, 1.0, sd);
	COLOR = vec4(col, alpha);
}
