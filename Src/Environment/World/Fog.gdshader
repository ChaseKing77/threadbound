shader_type canvas_item;

uniform vec4 center_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);  // Soft blue-white glow (center light)
uniform vec4 edge_color : source_color = vec4(0.05, 0.1, 0.08, 1.0);    // Dark cavern green-black (edges shadow)
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.2;           // Edge darkening (1.0=HK misty)
uniform float grain_intensity : hint_range(0.0, 0.1) = 0.03;            // Subtle film grain (0.02-0.05)
uniform float mist_intensity : hint_range(0.0, 0.3) = 0.15;             // Slow cloudy fog (0.1-0.2)
uniform float noise_scale = 8.0;                                        // Grain detail (higher= finer)
uniform float mist_speed = 0.02;                                        // Slow mist drift

// Simple noise (for grain/mist)
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);  // Smoothstep
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    vec2 uv = SCREEN_UV;  // Full viewport (0-1, ignores cam)

    // Radial gradient (center light → edges dark)
    float dist = distance(uv, vec2(0.5));  // Center at 0.5,0.5
    float g = smoothstep(0.0, 0.95, dist);  // Soft falloff
    vec4 base = mix(center_color, edge_color, g);

    // Vignette (extra edge shadow)
    float vign = smoothstep(0.3, vignette_strength, dist);
    base.rgb *= (1.0 - vign * 0.5);

    // Animated grain (fine noise overlay)
    float grain = noise(uv * noise_scale + vec2(TIME * 0.5, 0.0));
    base.rgb += (grain - 0.5) * grain_intensity;

    // Slow mist (large-scale noise for fog/clouds)
    float mist = noise(uv * 2.0 + vec2(TIME * mist_speed, TIME * mist_speed * 0.7));
    base.rgb += (mist - 0.5) * mist_intensity;

    COLOR = base;
}