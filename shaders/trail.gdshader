shader_type canvas_item;
// Claim trail ribbon: glowing core with shimmer marching along the line.
// Line2D: texture_mode = TILE, so UV.x runs along the length.

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.98, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.8, 1.0);
uniform float danger = 0.0;   // flashes red when broken

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;           // 0 center, 1 edge
	float core = 1.0 - smoothstep(0.16, 0.28, across);
	float rim = (1.0 - smoothstep(0.28, 0.36, across)) - core;   // ink outline
	float glow = pow(1.0 - across, 1.8);
	float shimmer = 0.6 + 0.4 * sin(UV.x * 1.4 - TIME * 10.0);
	vec3 col = mix(glow_color.rgb, core_color.rgb, core);
	col = mix(col, vec3(0.14, 0.05, 0.12), clamp(rim, 0.0, 1.0) * 0.8);
	col = mix(col, vec3(1.0, 0.1, 0.05), danger);
	float a = max(max(core, rim * 0.9), glow * 0.85 * shimmer);
	COLOR = vec4(col, a * COLOR.a);
}
