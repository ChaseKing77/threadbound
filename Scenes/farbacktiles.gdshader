shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 2.0) = 0.5;  // Light blur for depth (low to avoid double vision)
uniform float grain_intensity : hint_range(0.0, 0.05) = 0.01;  // Faint grain
uniform float fog_intensity : hint_range(0.0, 0.5) = 20;// Subtle fog (volumetric feel)
uniform vec4 fog_color : source_color = vec4(0.2, 0.3, 0.6, 0.8);  // Soft blue (semi-transparent)
uniform float noise_speed = 0.2;  // Slow drift

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
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    vec2 uv = UV;
    vec2 screen_uv = SCREEN_UV;
    float t = TIME;  // Single TIME for consistency

    // Light blur (4 samples, small offset for soft edges)
    vec4 base = vec4(0.0);
    float off = blur_amount / 2000.0;  // Smaller scale for 48x48 tiles
    base += texture(TEXTURE, uv + vec2(-off, -off)) * 0.25;
    base += texture(TEXTURE, uv + vec2(off, -off)) * 0.25;
    base += texture(TEXTURE, uv + vec2(-off, off)) * 0.25;
    base += texture(TEXTURE, uv + vec2(off, off)) * 0.25;

    // Subtle grain
    float grain = noise(screen_uv * 10.0 + vec2(t * noise_speed, 0.0));
    base.rgb += (grain - 0.5) * grain_intensity;

    // Light fog (noise-based, low intensity)
    float fog = noise(screen_uv * 3.0 + vec2(t * noise_speed * 0.5, t * noise_speed * 0.3));
    base.rgb = mix(base.rgb, fog_color.rgb, fog * fog_intensity);

    COLOR = base;
}