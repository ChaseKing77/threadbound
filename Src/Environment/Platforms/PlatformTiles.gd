extends TileMapLayer

var is_in_range: bool = false
@onready var glow_rect: TextureRect = $GlowLayer/GlowRect
@onready var glow_material: ShaderMaterial = glow_rect.material as ShaderMaterial if glow_rect else null

func _ready():
	if glow_rect and glow_material:
		glow_material.set_shader_parameter("glow_intensity", 0.0)
		glow_material.set_shader_parameter("glow_color", Color(1.0, 0.2, 0.2, 1.0))
		print("PlatformTiles: Glow ready")
	else:
		print("ERROR: GlowRect or material missing! Check ShaderMaterial on GlowRect.")

func set_in_range(active: bool):
	is_in_range = active
	if active:
		_fade_in_glow()
	else:
		_fade_out_glow()

func _fade_in_glow():
	if not glow_material: return
	var tween = create_tween()
	tween.tween_method(func(i): glow_material.set_shader_parameter("glow_intensity", i), 0.0, 1.0, 0.5)
	tween.tween_callback(_start_pulse)

func _fade_out_glow():
	if not glow_material: return
	var tween = create_tween()
	tween.tween_method(func(i): glow_material.set_shader_parameter("glow_intensity", i), glow_material.get_shader_parameter("glow_intensity"), 0.0, 0.3)
	_stop_pulse()

var pulse_tween: Tween
func _start_pulse():
	if not glow_material: return
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_method(func(i): glow_material.set_shader_parameter("glow_intensity", 0.7 + i * 0.8), 0.0, 1.0, 1.6)

func _stop_pulse():
	if pulse_tween:
		pulse_tween.kill()
