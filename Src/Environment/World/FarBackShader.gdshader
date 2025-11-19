shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 2.0) = 5; // Very light blur for depth
uniform float fog_intensity : hint_range(0.0, 0.1) = 10;  // Subtle blue haze
uniform vec4 fog_color : source_color = vec4(0.2, 0.3, 0.6, 0.8);  // Soft blue, semi-transparent
uniform float grain_intensity : hint_range(0.0, 0.03) = 0.5; //inimal grain
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

    // Very light blur (soft edges, no double vision)
    vec4 base = texture(TEXTURE, uv);  // Base tile texture
    float off = blur_amount / 4000.0;  // Tiny offset for small tiles
    base += texture(TEXTURE, uv + vec2(-off, -off)) * 0.05;
    base += texture(TEXTURE, uv + vec2(off, -off)) * 0.05;
    base += texture(TEXTURE, uv + vec2(-off, off)) * 0.05;
    base += texture(TEXTURE, uv + vec2(off, off)) * 0.05;
    base /= 1.2;  // Normalize to keep brightness

    // Subtle blue haze (light overlay)
    float dist = distance(screen_uv, vec2(0.5));
    float tint = smoothstep(0.0, 1.0, dist * 1.0);  // Gentle edge fade
    base.rgb = mix(base.rgb, fog_color.rgb, tint * fog_intensity * fog_color.a);

    // Minimal grain
    float grain = noise(screen_uv * 12.0 + vec2(TIME * noise_speed, 0.0));
    base.rgb += (grain - 0.5) * grain_intensity;

    COLOR = base;
}