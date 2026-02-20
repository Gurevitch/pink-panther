shader_type canvas_item;

// Full-screen paper grain + film flicker overlay
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float grain_intensity : hint_range(0.0, 0.2) = 0.05;
uniform float grain_size : hint_range(0.5, 3.0) = 1.0;
uniform float fiber_intensity : hint_range(0.0, 0.1) = 0.025;
uniform vec4 paper_tint : source_color = vec4(1.0, 0.97, 0.92, 1.0);
uniform float time_flicker : hint_range(0.0, 1.0) = 0.15;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);
	vec2 uv = SCREEN_UV;

	float t = TIME * time_flicker;

	// multi-scale grain
	float g1 = hash(uv * 500.0 * grain_size + t);
	float g2 = noise(uv * 200.0 * grain_size);
	float g3 = noise(uv * 80.0 * grain_size);
	float grain = (g1 * 0.5 + g2 * 0.3 + g3 * 0.2 - 0.5) * grain_intensity;

	// fiber texture
	float f1 = noise(uv * 100.0);
	float f2 = noise(uv * 150.0 + 50.0);
	float fiber = (mix(f1, f2, 0.5) - 0.5) * fiber_intensity;

	vec3 color = base.rgb + grain;

	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	color += fiber * (1.0 - lum * 0.5);

	// paper tint
	color = mix(color, color * paper_tint.rgb, 0.1);

	// slight desaturation for painted look
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(gray), color, 0.92);

	COLOR = vec4(color, 1.0);
}
