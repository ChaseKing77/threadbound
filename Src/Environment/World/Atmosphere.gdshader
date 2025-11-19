shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(0.2, 0.3, 0.6, 0.3);  // Soft blue hue (low alpha)
uniform float tint_intensity : hint_range(0.0, 1.0) = 1;  // Overall strength

void fragment() {
    vec4 screen = texture(SCREEN_TEXTURE, SCREEN_UV);  // Sample viewport
    vec3 tinted = mix(screen.rgb, tint_color.rgb, tint_intensity * tint_color.a);
    COLOR = vec4(tinted, screen.a);  // Apply tint, preserve alpha
}