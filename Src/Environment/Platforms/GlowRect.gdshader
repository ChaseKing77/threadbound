shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform float glow_width : hint_range(0.0, 10.0) = 4.0;
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.0;

void fragment() {
    vec2 ps = TEXTURE_PIXEL_SIZE;
    vec4 col = texture(TEXTURE, UV);
    float alpha = col.a;

    float edge = 0.0;
    for (float x = -glow_width; x <= glow_width; x += 1.0) {
        for (float y = -glow_width; y <= glow_width; y += 1.0) {
            vec2 offset = vec2(x, y) * ps;
            float sample = texture(TEXTURE, UV + offset).a;
            edge += abs(alpha - sample);
        }
    }
    edge = min(edge, 1.0) * glow_intensity;

    if (edge > 0.1) {
        COLOR = vec4(glow_color.rgb, edge * glow_color.a);
    } else {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    }
}