shader_type canvas_item;
// Night sky behind everything: gradient, twinkling stars, drifting clouds,
// and the moon, which turns from pale cream to blood red as Scary rises.

uniform float morph = 0.0;
uniform vec2 screen_size = vec2(720.0, 1280.0);
uniform vec2 moon_center = vec2(360.0, 236.0);
uniform float moon_radius = 168.0;
uniform float hold = 0.0;
uniform float ground_y = 1240.0;          // 0..1 win countdown, drawn as a ring

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.02; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 px = UV * screen_size;
	float t = TIME;
	float m = smoothstep(0.0, 1.0, morph);
	vec3 top = mix(vec3(0.16, 0.12, 0.33), vec3(0.06, 0.0, 0.03), m);
	vec3 bot = mix(vec3(0.33, 0.20, 0.42), vec3(0.20, 0.02, 0.05), m);
	vec3 col = mix(top, bot, smoothstep(0.0, 1.0, UV.y));

	// stars: soft round points, a few with cross glints
	vec2 cell = floor(px / 26.0);
	float h = hash(cell);
	vec2 sp = fract(px / 26.0) - 0.5 - (vec2(hash(cell + 1.3), hash(cell + 7.1)) - 0.5) * 0.6;
	float size = mix(0.035, 0.09, hash(cell + 3.7));
	float tw = 0.55 + 0.45 * sin(t * (1.0 + h * 2.5) + h * 40.0);
	float star = smoothstep(size, 0.0, length(sp)) * step(0.72, h);
	float glint = max(0.0, 1.0 - abs(sp.x) * 60.0) * max(0.0, 1.0 - abs(sp.y) * 6.0)
		+ max(0.0, 1.0 - abs(sp.y) * 60.0) * max(0.0, 1.0 - abs(sp.x) * 6.0);
	star += glint * step(0.965, h) * 0.6;
	col += vec3(1.0, 0.95, 0.9) * star * tw * (1.0 - UV.y * 0.8) * (1.0 - 0.6 * m);

	// moon + halo
	float d = distance(px, moon_center);
	vec3 moon_col = mix(vec3(1.0, 0.95, 0.84), vec3(0.85, 0.08, 0.06), m);
	float halo = exp(-max(d - moon_radius, 0.0) / (40.0 + 50.0 * m));
	col += mix(vec3(1.0, 0.9, 0.8), vec3(1.0, 0.15, 0.05), m) * halo * (0.35 + 0.35 * m);
	float disc = 1.0 - smoothstep(moon_radius - 1.5, moon_radius + 1.5, d);
	float craters = fbm((px - moon_center) * 0.018 + 3.0);
	vec3 mc = moon_col * (0.82 + 0.3 * craters);
	// soft terminator shading
	mc *= 0.85 + 0.15 * smoothstep(moon_radius, -moon_radius, (px.x - moon_center.x) + (px.y - moon_center.y) * 0.4);
	col = mix(col, mc, disc);

	// hold ring around the moon
	if (hold > 0.0) {
		vec2 v = px - moon_center;
		float ang = atan(v.x, -v.y) / 6.28318 + 0.5;
		float ring = 1.0 - smoothstep(3.0, 6.0, abs(d - moon_radius - 16.0));
		col = mix(col, vec3(1.0, 0.86, 0.4), ring * step(ang, hold));
	}

	// drifting clouds in front of the moon
	float c = fbm(px * vec2(0.004, 0.009) + vec2(t * 0.02, 0.0));
	float band = smoothstep(0.55, 0.75, c) * (1.0 - smoothstep(0.1, 0.55, abs(UV.y - 0.24)));
	col = mix(col, mix(vec3(0.42, 0.32, 0.55), vec3(0.12, 0.02, 0.04), m), band * 0.65);

	// ground silhouette at the very bottom
	float hill = ground_y + 18.0 * sin(px.x * 0.012) + 10.0 * sin(px.x * 0.031 + 1.0);
	col = mix(col, vec3(0.04, 0.02, 0.06), smoothstep(hill - 1.0, hill + 1.0, px.y));
	COLOR = vec4(col, 1.0);
}
