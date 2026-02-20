shader_type canvas_item;

// Full-screen hand-painted overlay — brush strokes and color shifts
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float brush_intensity : hint_range(0.0, 1.0) = 0.12;
uniform float color_variation : hint_range(0.0, 0.1) = 0.025;
uniform float edge_darkening : hint_range(0.0, 0.3) = 0.15;
uniform float warmth : hint_range(0.0, 0.1) = 0.02;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float brush_stroke(vec2 uv, float angle) {
	vec2 dir = vec2(cos(angle), sin(angle));
	float s = sin(dot(uv * 200.0, dir) + hash(floor(uv * 50.0)) * 6.28);
	return s * 0.5 + 0.5;
}

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);
	vec2 uv = SCREEN_UV;

	float n = hash(uv * 200.0);
	float s1 = brush_stroke(uv, 0.3 + n * 0.5);
	float s2 = brush_stroke(uv, 1.2 + n * 0.3);
	float combined = mix(s1, s2, 0.5);

	vec3 color = base.rgb;

	// warm/cool luminance shift
	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 warm = vec3(warmth, warmth * 0.5, -warmth * 0.5);
	vec3 cool = vec3(-0.01, 0.0, 0.02);
	color += mix(cool, warm, lum) * color_variation * 10.0;

	// brush texture
	color *= 1.0 + (combined - 0.5) * brush_intensity;

	// per-area color jitter
	float area = hash(floor(uv * 30.0));
	color += (area - 0.5) * color_variation;

	// vignette edge
	vec2 cd = abs(uv - 0.5) * 2.0;
	float edge = smoothstep(0.6, 1.0, max(cd.x, cd.y));
	color *= 1.0 - edge * edge_darkening;

	COLOR = vec4(color, 1.0);
}
