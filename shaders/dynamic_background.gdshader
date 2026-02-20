shader_type canvas_item;

uniform float time_scale : hint_range(0.1, 2.0) = 0.5;
uniform vec4 color_sky_top : source_color = vec4(0.1, 0.1, 0.3, 1.0);
uniform vec4 color_sky_bottom : source_color = vec4(0.4, 0.2, 0.5, 1.0);
uniform vec4 color_ground : source_color = vec4(0.15, 0.1, 0.2, 1.0);
uniform float horizon_line : hint_range(0.3, 0.8) = 0.6;

// Stars
uniform float star_density : hint_range(0.0, 1.0) = 0.3;
uniform float star_twinkle_speed : hint_range(0.5, 5.0) = 2.0;

// Moon
uniform vec2 moon_position = vec2(0.8, 0.2);
uniform float moon_size : hint_range(0.02, 0.15) = 0.06;

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

void fragment() {
    vec2 uv = UV;
    float time = TIME * time_scale;

    // Sky gradient
    vec4 sky_color = mix(color_sky_bottom, color_sky_top, uv.y);

    // Ground
    if (uv.y > horizon_line) {
        float ground_gradient = (uv.y - horizon_line) / (1.0 - horizon_line);
        sky_color = mix(color_sky_bottom, color_ground, ground_gradient);

        // Ground texture/noise
        float ground_noise = noise(uv * 50.0 + vec2(time * 0.1, 0.0));
        sky_color.rgb += ground_noise * 0.05;
    }

    // Stars (only in sky)
    if (uv.y < horizon_line) {
        vec2 star_uv = floor(uv * 100.0);
        float star_random = random(star_uv);

        if (star_random > 1.0 - star_density * 0.1) {
            float twinkle = sin(time * star_twinkle_speed + star_random * 6.28) * 0.5 + 0.5;
            float star_brightness = twinkle * (1.0 - uv.y / horizon_line);
            sky_color.rgb += vec3(star_brightness * 0.8);
        }
    }

    // Moon
    float moon_dist = distance(uv, moon_position);
    if (moon_dist < moon_size) {
        float moon_edge = smoothstep(moon_size, moon_size * 0.8, moon_dist);
        vec3 moon_color = vec3(1.0, 0.95, 0.8);

        // Moon craters
        float crater = noise(uv * 200.0);
        moon_color -= crater * 0.1;

        sky_color.rgb = mix(sky_color.rgb, moon_color, moon_edge);
    }

    // Moon glow
    float glow_dist = distance(uv, moon_position);
    float glow = exp(-glow_dist * 15.0) * 0.3;
    sky_color.rgb += vec3(0.8, 0.7, 0.5) * glow;

    // Subtle animated fog/atmosphere near horizon
    float fog_height = abs(uv.y - horizon_line);
    if (fog_height < 0.1) {
        float fog = noise(vec2(uv.x * 5.0 + time * 0.2, time * 0.1));
        float fog_intensity = (1.0 - fog_height / 0.1) * 0.15;
        sky_color.rgb += vec3(0.5, 0.4, 0.6) * fog * fog_intensity;
    }

    COLOR = sky_color;
}
