shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 6.0) = 0.0;
uniform float crack_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(5.0, 50.0) = 18.0;

// Fast procedural noise for cracks
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	p *= 22.0;
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	float a = hash(i);
	float b = hash(i + vec2(1.0,0.0));
	float c = hash(i + vec2(0.0,1.0));
	float d = hash(i + vec2(1.0,1.0));
	return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}

void fragment() {
	// SAMPLE THE ORIGINAL TILE (Godot already handles margins correctly!)
	vec4 base = texture(TEXTURE, UV);
	if (base.a < 0.05) discard;

	// Convert UV to tile-local space (0–1 inside current tile)
	vec2 tile_uv = mod(UV * 2.0, 1.0);  // 2.0 because your atlas is 512px, tiles are 256px

	// Pulsing glow
	float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
	vec4 glow = vec4(1.0, 0.4, 0.1, 1.0) * glow_intensity * pulse;

	// Edge falloff so glow doesn't bleed outside tile
	float edge = 1.0 - smoothstep(0.3, 0.8, length(tile_uv - 0.5));
	glow *= edge;

	// Procedural cracks
	float cracks = noise(tile_uv + TIME * 0.08);
	cracks = smoothstep(0.65, 0.9, cracks) * crack_intensity * edge;

	// Darken tile where cracks are
	base.rgb *= (1.0 - cracks * 0.8);

	// Final composite
	COLOR = mix(base, glow, glow.a * 0.7);
	COLOR.rgb += glow.rgb * 0.2;  // subtle bleed
	COLOR.a = base.a + glow.a * 0.4;
}