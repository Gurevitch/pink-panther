shader_type canvas_item;

uniform float time_scale : hint_range(0.1, 2.0) = 0.3;
uniform vec4 color_sky_top : source_color = vec4(0.02, 0.02, 0.08, 1.0);
uniform vec4 color_sky_bottom : source_color = vec4(0.08, 0.05, 0.15, 1.0);
uniform float horizon_line : hint_range(0.3, 0.8) = 0.55;

// Stars
uniform float star_density : hint_range(0.0, 1.0) = 0.25;
uniform float star_twinkle_speed : hint_range(0.5, 5.0) = 1.5;

// Moon
uniform vec2 moon_position = vec2(0.85, 0.12);
uniform float moon_size : hint_range(0.02, 0.15) = 0.055;

// City colors
uniform vec4 building_color_1 : source_color = vec4(0.03, 0.03, 0.06, 1.0);
uniform vec4 building_color_2 : source_color = vec4(0.05, 0.04, 0.08, 1.0);
uniform vec4 window_color : source_color = vec4(1.0, 0.9, 0.5, 1.0);

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Draw a building silhouette
float building(vec2 uv, float x_pos, float width, float height, float seed) {
    float left = x_pos - width * 0.5;
    float right = x_pos + width * 0.5;

    if (uv.x > left && uv.x < right && uv.y > horizon_line - height && uv.y < horizon_line) {
        return 1.0;
    }
    return 0.0;
}

// Draw windows on buildings
float windows(vec2 uv, float x_pos, float width, float height, float seed, float time) {
    float left = x_pos - width * 0.5;
    float right = x_pos + width * 0.5;

    if (uv.x > left && uv.x < right && uv.y > horizon_line - height && uv.y < horizon_line - 0.02) {
        // Window grid
        vec2 window_uv = vec2((uv.x - left) / width, (uv.y - (horizon_line - height)) / height);
        vec2 grid = floor(window_uv * vec2(width * 30.0, height * 25.0));

        // Window pattern
        float window_random = random(grid + vec2(seed));

        // Some windows are lit, some flicker
        float lit = step(0.55, window_random);
        float flicker = sin(time * (2.0 + window_random * 3.0)) * 0.5 + 0.5;

        // Window shape
        vec2 window_local = fract(window_uv * vec2(width * 30.0, height * 25.0));
        float is_window = step(0.2, window_local.x) * step(window_local.x, 0.8) *
                         step(0.15, window_local.y) * step(window_local.y, 0.85);

        // Only every other cell is a window
        float cell_pattern = mod(grid.x + grid.y, 2.0);

        return is_window * lit * (0.7 + flicker * 0.3) * step(0.5, cell_pattern);
    }
    return 0.0;
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * time_scale;

    // Sky gradient
    vec4 sky_color = mix(color_sky_bottom, color_sky_top, uv.y / horizon_line);

    // Stars (only in sky)
    if (uv.y < horizon_line - 0.1) {
        vec2 star_uv = floor(uv * 150.0);
        float star_random = random(star_uv);

        if (star_random > 1.0 - star_density * 0.08) {
            float twinkle = sin(time * star_twinkle_speed + star_random * 6.28) * 0.5 + 0.5;
            float star_brightness = twinkle * (1.0 - uv.y / horizon_line) * 0.8;
            sky_color.rgb += vec3(star_brightness);
        }
    }

    // Moon
    float moon_dist = distance(uv, moon_position);
    if (moon_dist < moon_size) {
        float moon_edge = smoothstep(moon_size, moon_size * 0.75, moon_dist);
        vec3 moon_color = vec3(1.0, 0.98, 0.9);
        float crater = noise(uv * 180.0);
        moon_color -= crater * 0.08;
        sky_color.rgb = mix(sky_color.rgb, moon_color, moon_edge);
    }

    // Moon glow
    float glow_dist = distance(uv, moon_position);
    float glow = exp(-glow_dist * 12.0) * 0.25;
    sky_color.rgb += vec3(0.6, 0.55, 0.4) * glow;

    // Far buildings (silhouettes)
    float far_buildings = 0.0;
    for (int i = 0; i < 12; i++) {
        float fi = float(i);
        float x_pos = 0.05 + fi * 0.085 + sin(fi * 2.5) * 0.02;
        float width = 0.04 + random(vec2(fi, 1.0)) * 0.05;
        float height = 0.08 + random(vec2(fi, 2.0)) * 0.2;
        far_buildings = max(far_buildings, building(uv, x_pos, width, height, fi));
    }

    if (far_buildings > 0.0) {
        sky_color = mix(sky_color, building_color_1, 0.95);
    }

    // Near buildings with windows
    float near_buildings = 0.0;
    float window_light = 0.0;

    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        float x_pos = 0.08 + fi * 0.12 + sin(fi * 1.7) * 0.03;
        float width = 0.06 + random(vec2(fi, 10.0)) * 0.06;
        float height = 0.12 + random(vec2(fi, 20.0)) * 0.18;

        float b = building(uv, x_pos, width, height, fi + 100.0);
        near_buildings = max(near_buildings, b);

        if (b > 0.0) {
            window_light = max(window_light, windows(uv, x_pos, width, height, fi + 100.0, time));
        }
    }

    if (near_buildings > 0.0) {
        sky_color = mix(sky_color, building_color_2, 0.97);
        // Add window lights
        sky_color.rgb = mix(sky_color.rgb, window_color.rgb, window_light * 0.9);
    }

    // Ground
    if (uv.y > horizon_line) {
        vec4 ground_color = vec4(0.04, 0.03, 0.05, 1.0);
        sky_color = ground_color;

        // Street line
        if (uv.y > horizon_line && uv.y < horizon_line + 0.008) {
            sky_color.rgb += vec3(0.1, 0.08, 0.06);
        }
    }

    // Ambient city glow on horizon
    float city_glow = exp(-abs(uv.y - horizon_line) * 15.0) * 0.15;
    sky_color.rgb += vec3(0.4, 0.3, 0.5) * city_glow;

    COLOR = sky_color;
}
