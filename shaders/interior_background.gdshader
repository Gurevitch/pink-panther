shader_type canvas_item;

// Enhanced warped British cottage interior — theatrical set style
// Matches Pink Panther: Passport to Peril (1996) visual language

uniform float barrel_warp : hint_range(0.0, 0.3) = 0.12;
uniform float wall_floor_split : hint_range(0.4, 0.8) = 0.62;

// Wall palette
uniform vec4 wall_color_light : source_color = vec4(0.36, 0.20, 0.10, 1.0);
uniform vec4 wall_color_dark : source_color = vec4(0.22, 0.12, 0.06, 1.0);
uniform vec4 wall_color_deep : source_color = vec4(0.10, 0.05, 0.02, 1.0);

// Floor palette
uniform vec4 floor_color : source_color = vec4(0.40, 0.25, 0.14, 1.0);
uniform vec4 floor_shadow : source_color = vec4(0.20, 0.12, 0.06, 1.0);

// Carpet
uniform vec4 carpet_color : source_color = vec4(0.10, 0.13, 0.27, 1.0);
uniform vec4 carpet_border : source_color = vec4(0.06, 0.08, 0.17, 1.0);

// Central door opening
uniform vec2 door_center = vec2(0.50, 0.30);
uniform vec2 door_size = vec2(0.24, 0.52);
uniform vec4 exterior_sky : source_color = vec4(0.35, 0.66, 0.83, 1.0);
uniform vec4 exterior_grass : source_color = vec4(0.23, 0.55, 0.17, 1.0);
uniform vec4 exterior_hills : source_color = vec4(0.23, 0.42, 0.60, 1.0);
uniform vec4 door_frame_color : source_color = vec4(0.55, 0.38, 0.20, 1.0);

// Side windows
uniform vec2 left_window_pos = vec2(0.14, 0.28);
uniform vec2 left_window_size = vec2(0.09, 0.14);
uniform vec2 right_window_pos = vec2(0.84, 0.30);
uniform vec2 right_window_size = vec2(0.09, 0.14);
uniform vec4 window_exterior : source_color = vec4(0.29, 0.48, 0.22, 1.0);

// Lighting
uniform vec2 candle_pos = vec2(0.22, 0.25);
uniform float candle_intensity : hint_range(0.0, 1.0) = 0.45;
uniform float door_light_intensity : hint_range(0.0, 1.0) = 0.55;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;

// Wood grain
uniform float grain_scale : hint_range(10.0, 200.0) = 80.0;
uniform float grain_intensity : hint_range(0.0, 0.3) = 0.15;
uniform float plank_count : hint_range(4.0, 20.0) = 10.0;

// ---- noise helpers ----

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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

float fbm3(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

float wood_grain(vec2 uv, float sc, float angle) {
	vec2 r = vec2(
		uv.x * cos(angle) - uv.y * sin(angle),
		uv.x * sin(angle) + uv.y * cos(angle)
	);
	float g = sin(r.y * sc + fbm3(r * 5.0) * 4.0);
	g = g * 0.5 + 0.5;
	g *= 0.8 + noise(uv * 25.0) * 0.2;
	return g;
}

vec2 barrel_distort(vec2 uv, float amt) {
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	return c * (1.0 + amt * r2) + 0.5;
}

bool in_rect(vec2 uv, vec2 center, vec2 half_size) {
	return abs(uv.x - center.x) < half_size.x && abs(uv.y - center.y) < half_size.y;
}

// ---- wood knot ----
float wood_knot(vec2 uv, vec2 pos, float radius) {
	float d = distance(uv, pos);
	if (d > radius) return 0.0;
	float t = d / radius;
	float rings = sin(t * 28.0) * 0.5 + 0.5;
	float mask = 1.0 - smoothstep(0.0, 1.0, t);
	return mask * (0.55 + rings * 0.25);
}

// ---- fragment ----

void fragment() {
	vec2 uv = UV;
	vec2 wuv = barrel_distort(uv, barrel_warp);

	vec3 color = vec3(0.0);

	// --- openings ---
	vec2 dh = door_size * 0.5;
	float frame_w = 0.025;
	bool in_door       = in_rect(wuv, door_center, dh);
	bool in_door_frame = in_rect(wuv, door_center, dh + vec2(frame_w));

	vec2 lwh = left_window_size * 0.5;
	vec2 rwh = right_window_size * 0.5;
	float wf_w = 0.016;
	bool in_lw       = in_rect(wuv, left_window_pos,  lwh);
	bool in_lw_frame = in_rect(wuv, left_window_pos,  lwh + vec2(wf_w));
	bool in_rw       = in_rect(wuv, right_window_pos, rwh);
	bool in_rw_frame = in_rect(wuv, right_window_pos, rwh + vec2(wf_w));

	bool is_wall = wuv.y < wall_floor_split;

	// ============================================================
	//  DOOR INTERIOR — enhanced exterior vista
	// ============================================================
	if (in_door) {
		float ly = (wuv.y - (door_center.y - dh.y)) / door_size.y;
		if (ly < 0.22) {
			// Sky gradient with wispy clouds
			vec3 sky_top = exterior_sky.rgb * 1.18;
			vec3 sky_bot = exterior_sky.rgb * 0.88;
			color = mix(sky_top, sky_bot, ly / 0.22);
			float cloud = fbm3(wuv * vec2(9.0, 4.0) + vec2(0.5, 0.0));
			color = mix(color, vec3(0.92, 0.93, 0.96), smoothstep(0.42, 0.62, cloud) * 0.3);
		} else if (ly < 0.40) {
			// Distant rolling hills
			float h_shape = sin(wuv.x * 20.0) * 0.025 + sin(wuv.x * 8.0) * 0.018;
			float t = smoothstep(0.22, 0.40, ly + h_shape);
			color = mix(exterior_sky.rgb * 0.82, exterior_hills.rgb, t);
			color *= 0.90 + noise(wuv * vec2(35.0, 18.0)) * 0.15;
		} else if (ly < 0.52) {
			// Hedgerow / tree line
			float hedge = fbm3(wuv * vec2(45.0, 22.0));
			vec3 hedge_col = mix(vec3(0.10, 0.32, 0.08), vec3(0.16, 0.40, 0.12), hedge);
			float t = smoothstep(0.40, 0.52, ly);
			color = mix(exterior_hills.rgb * 0.8, hedge_col, t);
		} else {
			// Lush grass with blade detail
			color = exterior_grass.rgb;
			float grass_detail = noise(wuv * vec2(65.0, 35.0));
			float grass_blades = sin(wuv.x * 220.0 + grass_detail * 12.0) * 0.5 + 0.5;
			color *= 0.82 + grass_detail * 0.22 + grass_blades * 0.06;
			// Path/lighter patch
			float path = exp(-pow((wuv.x - door_center.x) * 8.0, 2.0));
			color = mix(color, color * 1.15, path * 0.3);
			color *= 1.0 - (ly - 0.52) * 0.35;
		}
		// Door frame inner edge with shadow
		vec2 ed = abs(wuv - door_center) / dh;
		float ff = smoothstep(0.80, 0.96, max(ed.x, ed.y));
		color = mix(color, door_frame_color.rgb * 0.7, ff);
		// Inner shadow at top
		float top_shadow = smoothstep(0.04, 0.18, ly);
		color *= 0.65 + top_shadow * 0.35;

	// ============================================================
	//  DOOR FRAME
	// ============================================================
	} else if (in_door_frame) {
		color = door_frame_color.rgb;
		float fg = wood_grain(wuv, grain_scale * 0.5, 0.0);
		color *= 0.82 + fg * 0.22;
		vec2 fd = abs(wuv - door_center) / (dh + vec2(frame_w));
		float depth_s = smoothstep(0.65, 1.0, max(fd.x, fd.y));
		color *= 0.75 + depth_s * 0.25;

	// ============================================================
	//  LEFT WINDOW — enhanced with crossbar
	// ============================================================
	} else if (in_lw) {
		float wy = (wuv.y - (left_window_pos.y - lwh.y)) / left_window_size.y;
		color = mix(exterior_sky.rgb * 1.1, window_exterior.rgb, smoothstep(0.25, 0.7, wy));
		color *= 1.1;
		color += noise(wuv * 45.0) * 0.06;
		vec2 we = abs(wuv - left_window_pos) / lwh;
		color = mix(color, door_frame_color.rgb * 0.8, smoothstep(0.76, 0.94, max(we.x, we.y)));
		// Cross bars
		float cx = 1.0 - smoothstep(0.0, 0.012, abs(wuv.x - left_window_pos.x));
		float cy = 1.0 - smoothstep(0.0, 0.014, abs(wuv.y - left_window_pos.y));
		color = mix(color, door_frame_color.rgb * 0.65, max(cx, cy) * 0.85);

	} else if (in_lw_frame) {
		color = door_frame_color.rgb * 0.85;
		color *= 0.86 + wood_grain(wuv, grain_scale * 0.4, 0.1) * 0.18;

	// ============================================================
	//  RIGHT WINDOW — enhanced with crossbar
	// ============================================================
	} else if (in_rw) {
		float wy = (wuv.y - (right_window_pos.y - rwh.y)) / right_window_size.y;
		color = mix(exterior_sky.rgb * 1.05, window_exterior.rgb * 0.95, smoothstep(0.25, 0.7, wy));
		color *= 1.05;
		color += noise(wuv * 45.0) * 0.06;
		vec2 we = abs(wuv - right_window_pos) / rwh;
		color = mix(color, door_frame_color.rgb * 0.8, smoothstep(0.76, 0.94, max(we.x, we.y)));
		float cx = 1.0 - smoothstep(0.0, 0.012, abs(wuv.x - right_window_pos.x));
		float cy = 1.0 - smoothstep(0.0, 0.014, abs(wuv.y - right_window_pos.y));
		color = mix(color, door_frame_color.rgb * 0.65, max(cx, cy) * 0.85);

	} else if (in_rw_frame) {
		color = door_frame_color.rgb * 0.85;
		color *= 0.86 + wood_grain(wuv, grain_scale * 0.4, -0.1) * 0.18;

	// ============================================================
	//  WALL — major enhancement
	// ============================================================
	} else if (is_wall) {
		// Distance from center for corner darkening
		float dist_cx = abs(wuv.x - 0.5) * 2.0;
		float corner = smoothstep(0.12, 1.0, dist_cx);

		// Ceiling area darkening
		float ceiling_dark = smoothstep(0.28, 0.0, wuv.y);

		// === Light sources ===
		float cdist = distance(wuv, candle_pos);
		float clight = exp(-cdist * 4.0) * candle_intensity;

		float ddist = distance(wuv, door_center);
		float dlight = exp(-ddist * 2.5) * door_light_intensity;

		// Window glow on nearby wall
		float lwdist = distance(wuv, left_window_pos);
		float lw_glow = exp(-lwdist * 4.5) * 0.22;
		float rwdist = distance(wuv, right_window_pos);
		float rw_glow = exp(-rwdist * 4.5) * 0.22;

		float light = max(max(clight, dlight), max(lw_glow, rw_glow));

		// Base wall color modulated by light
		color = mix(wall_color_dark.rgb, wall_color_light.rgb, light);
		color = mix(color, wall_color_deep.rgb, corner * 0.80);
		color = mix(color, wall_color_deep.rgb * 0.25, ceiling_dark * 0.75);

		// === Ceiling beams (3 thick curved dark beams) ===
		for (int i = 0; i < 3; i++) {
			float beam_y = 0.035 + float(i) * 0.105;
			float curve = sin(wuv.x * 3.14159) * 0.018;
			float beam_dist = abs(wuv.y - beam_y + curve);
			float thickness = 0.020 + sin(float(i) * 2.7) * 0.005;
			float beam = 1.0 - smoothstep(0.0, thickness, beam_dist);
			// Beam wood grain
			float bg = wood_grain(wuv, grain_scale * 0.25, 1.5);
			vec3 beam_col = vec3(0.12, 0.06, 0.02) * (0.75 + bg * 0.35);
			// Dark outline at beam edges
			float bedge = smoothstep(thickness * 0.6, thickness, beam_dist);
			beam_col = mix(beam_col * 0.4, beam_col, bedge);
			color = mix(color, beam_col, beam * 0.92);
		}

		// === Horizontal plank bands (stronger grooves) ===
		float py = wuv.y * plank_count;
		float pid = floor(py);
		float pf = fract(py);

		// Dark groove lines between planks
		float edge = smoothstep(0.0, 0.032, pf) * smoothstep(1.0, 0.968, pf);
		color *= 0.68 + edge * 0.32;

		// Per-plank color variation
		float ph = hash(vec2(pid, 42.0));
		color *= 0.84 + ph * 0.20;

		// === Wood grain (much more visible) ===
		float g = wood_grain(wuv + vec2(ph * 0.1, 0.0), grain_scale, 0.05 + ph * 0.1);
		color *= 1.0 + (g - 0.5) * grain_intensity * 2.0;

		// Horizontal grain streaks
		float streak = sin(wuv.y * 350.0 + noise(wuv * vec2(4.0, 90.0)) * 22.0);
		color *= 0.95 + streak * 0.05;

		// === Wood knots at fixed positions ===
		float kv = 0.0;
		kv = max(kv, wood_knot(wuv, vec2(0.07, 0.23), 0.028));
		kv = max(kv, wood_knot(wuv, vec2(0.30, 0.40), 0.032));
		kv = max(kv, wood_knot(wuv, vec2(0.42, 0.15), 0.024));
		kv = max(kv, wood_knot(wuv, vec2(0.70, 0.10), 0.026));
		kv = max(kv, wood_knot(wuv, vec2(0.78, 0.46), 0.030));
		kv = max(kv, wood_knot(wuv, vec2(0.95, 0.30), 0.022));
		color *= 1.0 - kv * 0.50;

		// Staining / patina variation
		float stain = fbm3(wuv * vec2(3.0, 7.0));
		color *= 0.90 + stain * 0.10;

		// Subtle cracks/scratches
		float crack = noise(wuv * vec2(220.0, 440.0));
		color *= 1.0 - smoothstep(0.80, 0.84, crack) * 0.10;

	// ============================================================
	//  FLOOR — major enhancement
	// ============================================================
	} else {
		float fy = (wuv.y - wall_floor_split) / (1.0 - wall_floor_split);

		// Carpet zone (trapezoid shape)
		float ct = 0.12;
		float cb = 0.88;
		float cwt = 0.26;
		float cwb = 0.38;
		bool in_carpet = false;

		if (fy > ct && fy < cb) {
			float t = (fy - ct) / (cb - ct);
			float hw = mix(cwt, cwb, t);
			in_carpet = abs(wuv.x - 0.5) < hw;
		}

		if (in_carpet) {
			color = carpet_color.rgb;

			// Fibrous shaggy texture (multi-layer noise)
			float fib1 = noise(wuv * vec2(130.0, 65.0));
			float fib2 = noise(wuv * vec2(65.0, 130.0));
			float fib3 = noise(wuv * vec2(220.0, 110.0));
			float fiber = (fib1 * 0.4 + fib2 * 0.35 + fib3 * 0.25);
			color *= 0.78 + fiber * 0.32;

			// Carpet pile direction (diagonal ribbing)
			float pile = sin(wuv.x * 160.0 + wuv.y * 85.0 + noise(wuv * 22.0) * 4.5);
			color *= 0.94 + pile * 0.08;

			// Sheen variation (large scale)
			float sheen = noise(wuv * vec2(11.0, 9.0));
			color *= 0.88 + sheen * 0.16;

			// === Border detection ===
			float tb = (fy - ct) / (cb - ct);
			float hwb = mix(cwt, cwb, tb);
			float bx = abs(wuv.x - 0.5) / hwb;
			float bt = smoothstep(ct, ct + 0.05, fy);
			float bb = smoothstep(cb, cb - 0.05, fy);
			float bdr = smoothstep(0.82, 0.93, bx) + (1.0 - bt) + (1.0 - bb);
			bdr = clamp(bdr, 0.0, 1.0);

			// RED/BURGUNDY border (matches reference)
			vec3 border_red = vec3(0.52, 0.07, 0.09);
			color = mix(color, border_red, bdr * 0.88);

			// Inner accent line (darker navy)
			float ib = smoothstep(0.76, 0.80, bx) * (1.0 - smoothstep(0.81, 0.83, bx));
			float ibt = smoothstep(ct + 0.04, ct + 0.06, fy) * (1.0 - smoothstep(ct + 0.06, ct + 0.08, fy));
			float ibb = smoothstep(cb - 0.06, cb - 0.04, fy) * (1.0 - smoothstep(cb - 0.04, cb - 0.02, fy));
			color = mix(color, carpet_border.rgb, (ib + ibt + ibb) * 0.55);

		// === Floor planks ===
		} else {
			color = floor_color.rgb;

			// Perspective plank convergence
			vec2 vp = vec2(0.5, wall_floor_split);
			vec2 fv = wuv - vp;
			float ang = atan(fv.x, fv.y);

			// Strong plank groove lines
			float fplank = sin(ang * 16.0);
			color *= 1.0 - smoothstep(0.86, 1.0, abs(fplank)) * 0.42;

			// Per-plank color variation
			float fpid = floor(ang * 16.0 / 3.14159);
			float fph = hash(vec2(fpid, 99.0));
			color *= 0.85 + fph * 0.18;

			// Wood grain on floor planks
			float fg = wood_grain(wuv, grain_scale * 0.6, ang * 0.3);
			color *= 1.0 + (fg - 0.5) * grain_intensity * 1.0;

			// Cross-board lines (width/length joints)
			float cross_line = sin(length(fv) * 45.0);
			color *= 1.0 - smoothstep(0.93, 1.0, abs(cross_line)) * 0.18;

			// Depth darkening (far floor darker)
			float depth = 1.0 - fy;
			color = mix(color, floor_shadow.rgb, depth * 0.58);
		}

		// === Door light spill on floor (warm trapezoid) ===
		float door_fx = abs(wuv.x - door_center.x);
		float door_spread = 0.04 + fy * 0.16;
		float door_light = smoothstep(door_spread, door_spread * 0.55, door_fx);
		door_light *= smoothstep(0.0, 0.14, fy) * smoothstep(0.72, 0.28, fy);
		color += door_light * door_light_intensity * 0.55 * vec3(0.20, 0.16, 0.08);

		// === Window light patches on floor ===
		float lw_fx = wuv.x - left_window_pos.x + (fy - 0.2) * 0.1;
		float lw_fy_m = smoothstep(0.0, 0.22, fy) * smoothstep(0.55, 0.28, fy);
		float lw_floor = exp(-lw_fx * lw_fx * 90.0) * lw_fy_m;
		color += lw_floor * 0.14 * vec3(0.16, 0.13, 0.06);

		float rw_fx = wuv.x - right_window_pos.x - (fy - 0.2) * 0.1;
		float rw_fy_m = smoothstep(0.0, 0.22, fy) * smoothstep(0.55, 0.28, fy);
		float rw_floor = exp(-rw_fx * rw_fx * 90.0) * rw_fy_m;
		color += rw_floor * 0.14 * vec3(0.16, 0.13, 0.06);
	}

	// ============================================================
	//  GLOBAL EFFECTS
	// ============================================================

	// Warm ambient tint
	color *= vec3(1.0, 0.89, 0.74);

	// Strong vignette (nearly black corners — matches reference)
	vec2 vu = uv * 2.0 - 1.0;
	float vig = 1.0 - dot(vu * vu, vu * vu) * vignette_strength * 1.5;
	color *= clamp(vig, 0.0, 1.0);

	// Extra edge darkening (top/bottom strips)
	float top_strip = smoothstep(0.14, 0.0, uv.y);
	float bottom_strip = smoothstep(0.86, 1.0, uv.y);
	color *= 1.0 - (top_strip + bottom_strip) * 0.45;

	// Side edge darkening
	float left_strip = smoothstep(0.08, 0.0, uv.x);
	float right_strip = smoothstep(0.92, 1.0, uv.x);
	color *= 1.0 - (left_strip + right_strip) * 0.35;

	// Overall darken to match reference's moody feel
	color *= 0.78;

	// Paint texture variation (hand-painted feel)
	color *= 0.93 + fbm3(uv * 50.0) * 0.14;

	// Subtle warm/cool color drift (hand-painted inconsistency)
	float color_noise = fbm3(uv * 28.0 + vec2(7.0, 3.0));
	color.r *= 0.97 + color_noise * 0.06;
	color.b *= 1.03 - color_noise * 0.06;

	COLOR = vec4(color, 1.0);
}
