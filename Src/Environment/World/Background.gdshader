shader_type canvas_item;

uniform vec4 center_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform vec4 edge_color   : source_color = vec4(0.05, 0.08, 0.06, 1.0);

uniform float vignette_strength : hint_range(0.0, 2.0) = 1.0;
uniform float vignette_softness : hint_range(0.1, 1.0) = 0.5;

uniform float noise_intensity : hint_range(0.0, 1.0) = 0.06;
uniform float noise_scale     = 8.0;
uniform float noise_speed     = 0.2;

uniform float mist_strength   : hint_range(0.0, 1.0) = 0.2;
uniform float mist_scale      = 4.0;
uniform float mist_speed      = 0.05;

// --- hash + noise ---
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) +
           (c - a) * u.y * (1.0 - u.x) +
           (d - b) * u.x * u.y;
}

void fragment() {
    vec2 uv = UV;

    // radial gradient
    float dist = distance(uv, vec2(0.5));
    float g = smoothstep(0.0, 0.9, dist);
    vec4 base = mix(center_color, edge_color, g);

    // vignette
    float vign = smoothstep(vignette_softness, vignette_strength, dist);
    base.rgb *= (1.0 - vign);

    // animated grain
    float n = noise((uv * noise_scale) + vec2(TIME * noise_speed));
    base.rgb += (n - 0.5) * noise_intensity;

    // mist overlay
    float m = noise((uv * mist_scale) + vec2(TIME * mist_speed, TIME * mist_speed * 0.7));
    base.rgb += (m - 0.5) * mist_strength;

    COLOR = base;
}
