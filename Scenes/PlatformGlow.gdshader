shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.2, 0.2, 1.0); // Red glow
uniform float glow_width : hint_range(0.0, 10.0) = 4.0;             // Fixed width for platforms
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.8;          // Pulsing intensity

void fragment() {
    vec2 ps = TEXTURE_PIXEL_SIZE;
    vec4 col = texture(TEXTURE, UV);
    float alpha = col.a;

    // Edge detection
    float edge = 0.0;
    for (float x = -glow_width; x <= glow_width; x += 1.0) {
        for (float y = -glow_width; y <= glow_width; y += 1.0) {
            vec2 offset = vec2(x, y) * ps;
            float sample = texture(TEXTURE, UV + offset).a;
            edge += abs(alpha - sample);
        }
    }
    edge = min(edge, 1.0) * glow_intensity;

    // Edge-only glow (activates in range)
    if (edge > 0.1) {
        COLOR = vec4(glow_color.rgb, edge * glow_color.a);
    } else {
        COLOR = col;
    }
}