extends Node

# === PLAYER & VISUALS ===
var player: CharacterBody2D
var anim_sprite: AnimatedSprite2D
var thread_line: Line2D
var grapple_popup: Label
var debug_label: Label
var trail_container: Node2D

# === GRAPPLE STATE ===
var current_grapple_target: RigidBody2D = null
var connected: bool = false
var current_slack: float = 0.0

# === CHARGE DASH STATE ===
var is_dashing: bool = false
var is_charging_dash: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var charge_dash_timer: float = 0.0
var dash_charge: float = 0.0
var last_direction: int = 1
var dash_speed: float = 0.0

# === STOMP STATE ===
var is_stomping: bool = false
var stomp_cooldown_timer: float = 0.0
var stomp_impact: bool = false
var stomp_fall_time: float = 0.0
var stomp_trail_timer: float = 0.0
var stomp_glow_shader: ShaderMaterial

# === DOUBLE-TAP S ===
var last_down_press_time: float = 0.0
@export var double_tap_window: float = 0.3

# === TUNABLES ===
@export var max_slack: float = 50.0
@export var slack_take_rate: float = 380.0
@export var slack_restore_rate: float = 100.0
@export var yank_force: float = 1600.0
@export var grapple_slow_factor: float = 0.15
@export var grapple_max_range: float = 850.0
@export var screen_shake_small: float = 3.0
@export var screen_shake_big: float = 8.0
@export var pull_vel_threshold: float = 35.0
@export var taut_stop_dist: float = 150.0
@export var max_total_stretch_mult: float = 1.0

@export var charge_dash_max_time: float = 2.0
@export var charge_dash_min_speed: float = 600.0
@export var charge_dash_max_speed: float = 1800.0
@export var charge_dash_min_duration: float = 0.1
@export var charge_dash_max_duration: float = 0.3
@export var dash_cooldown: float = 0.5

@export var stomp_fall_speed: float = 1200.0
@export var stomp_cooldown: float = 0.8
@export var stomp_bounce_vel: float = -200.0
@export var stomp_impact_radius: float = 24.0
@export var stomp_ray_length: float = 8.0
@export var stomp_trail_interval: float = 0.03

# === BREAKABLE TILES ===
var breakable_tilemap: TileMap
var breakable_shader: ShaderMaterial
@export var glow_activation_distance: float = 300.0
@export var glow_max_intensity: float = 3.0
var is_red_active: bool = false

# === LAYER ===
const BREAKABLE_LAYER: int = 0  # FIXED: Layer 0

# === TILE SIZE (512px → scaled 0.25 → effective 128px) ===
const TILE_WORLD_SIZE: Vector2 = Vector2(512, 512) * 0.25  # = (128, 128)

func _enter_tree():
	player = get_parent() as CharacterBody2D
	if not player:
		push_error("RedArchetype: Parent is NOT CharacterBody2D!")
		return

	# === FIND ANIMATED SPRITE ===
	anim_sprite = player.get_node_or_null("Player Animation") as AnimatedSprite2D
	if not anim_sprite:
		push_error("RedArchetype: 'Player Animation' not found!")
		return

	# === LINE ===
	thread_line = Line2D.new()
	thread_line.width = 3.0
	thread_line.default_color = Color(1, 0, 0, 0.8)
	thread_line.visible = false
	player.add_child(thread_line)

	# === POPUP ===
	grapple_popup = Label.new()
	grapple_popup.add_theme_font_size_override("font_size", 24)
	grapple_popup.position = Vector2(0, -80)
	grapple_popup.visible = false
	player.add_child(grapple_popup)

	# === DEBUG ===
	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", 18)
	debug_label.position = Vector2(0, -120)
	debug_label.text = "RED: Ready"
	player.add_child(debug_label)

	# === TRAIL CONTAINER ===
	trail_container = Node2D.new()
	trail_container.name = "StompTrailContainer"
	get_tree().current_scene.add_child(trail_container)

	# === PLAYER GLOW SHADER ===
	_setup_stomp_shader()

	# === GRAPPLE PLATFORMS ===
	for plat in get_tree().get_nodes_in_group("red_grapple"):
		if plat.has_node("DetectionArea"):
			var area: Area2D = plat.get_node("DetectionArea")
			area.body_entered.connect(_on_detection_entered.bind(plat))
			area.body_exited.connect(_on_detection_exited.bind(plat))

	# === BREAKABLE TILEMAP ===
	_setup_breakable_tilemap()

	print("[RED] Archetype loaded – player = ", player.name)

func _setup_stomp_shader() -> void:
	var sh = Shader.new()
	sh.code = """
	shader_type canvas_item;
	uniform float glow_intensity : hint_range(0.0, 15.0) = 8.0;
	void fragment() {
		vec4 base = texture(TEXTURE, UV);
		if (base.a < 0.01) discard;
		float dist = length(UV - vec2(0.5));
		float pulse = 0.6 + 0.4 * sin(TIME * 22.0);
		vec4 glow = vec4(1.0, 0.35, 0.1, 1.0) * glow_intensity * pulse * (1.0 - dist);
		COLOR = mix(base, glow, glow.a * 0.7);
		COLOR.a = base.a + glow.a * 0.6;
	}
	"""
	stomp_glow_shader = ShaderMaterial.new()
	stomp_glow_shader.shader = sh

func _setup_breakable_tilemap() -> void:
	if breakable_tilemap:
		return

	await get_tree().process_frame

	var root = get_tree().current_scene
	if not root:
		push_warning("No current_scene!")
		return

	var tilemap_node = root.get_node_or_null("RedBreakablePlat")
	if not tilemap_node or not (tilemap_node is TileMap):
		push_warning("RedBreakablePlat NOT FOUND or not a TileMap!")
		return

	if tilemap_node.material is ShaderMaterial:
		breakable_shader = tilemap_node.material
	else:
		var mat = ShaderMaterial.new()
		mat.shader = load("res://Shaders/red_breakable_tile.gdshader")
		tilemap_node.material = mat
		breakable_shader = mat

	breakable_shader.set_shader_parameter("glow_intensity", 0.0)
	breakable_tilemap = tilemap_node

	print("[RED] Breakable TileMap connected + shader ready")
	print("[GLOW] FORCED OFF at start")

	# === DEBUG LAYERS ===
	print("[DEBUG] TileMap has ", breakable_tilemap.get_layers_count(), " layer(s)")
	print("[DEBUG] Used cells on Layer ", BREAKABLE_LAYER, ": ", breakable_tilemap.get_used_cells(BREAKABLE_LAYER).size())

# === SET ACTIVE (FROM SELECTOR) ===
func set_active(active: bool) -> void:
	is_red_active = active
	if not active and breakable_shader:
		breakable_shader.set_shader_parameter("glow_intensity", 0.0)
	_update_debug("RED: " + ("ACTIVE" if active else "INACTIVE"))

# === MAIN MECHANICS ===
func process_mechanics(delta: float, _p: CharacterBody2D):
	if not player: return

	var h_input = Input.get_axis("move_left", "move_right")
	if h_input != 0:
		last_direction = sign(h_input)

	_handle_double_tap_s()
	_handle_stomp(delta)
	_handle_charge_dash(delta)

	if is_red_active:
		_update_breakable_glow()
	else:
		if breakable_shader:
			breakable_shader.set_shader_parameter("glow_intensity", 0.0)

	if is_dashing:
		player.velocity = Vector2(last_direction * dash_speed, 0)
		_update_debug("DASHING: %.0f" % dash_speed)
		return

	_handle_grapple(delta)

# === PROXIMITY GLOW (LAYER 0) ===
func _update_breakable_glow() -> void:
	if not breakable_tilemap or not breakable_shader or not is_red_active:
		return

	var player_pos = player.global_position
	var max_intensity = 0.0

	for coord in breakable_tilemap.get_used_cells(BREAKABLE_LAYER):
		var data = breakable_tilemap.get_cell_tile_data(BREAKABLE_LAYER, coord)
		if not (data and data.get_custom_data("red_breakable") == true):
			continue

		var tile_pos = breakable_tilemap.map_to_local(coord)
		var dist = player_pos.distance_to(tile_pos)

		if dist < glow_activation_distance:
			var t = 1.0 - (dist / glow_activation_distance)
			var intensity = lerp(0.0, glow_max_intensity, t * t)
			if intensity > max_intensity:
				max_intensity = intensity

	breakable_shader.set_shader_parameter("glow_intensity", max_intensity)

# === DOUBLE-TAP S ===
func _handle_double_tap_s() -> void:
	if Input.is_action_just_pressed("move_down"):
		var now = Time.get_ticks_msec() / 1000.0
		var interval = now - last_down_press_time
		if interval > 0.0 and interval < double_tap_window:
			if not player.is_on_floor() and not (connected or is_dashing):
				_start_stomp()
		last_down_press_time = now

# === START STOMP ===
func _start_stomp() -> void:
	if is_stomping or stomp_cooldown_timer > 0: return
	is_stomping = true
	stomp_fall_time = 0.0
	player.velocity.y = stomp_fall_speed
	anim_sprite.material = stomp_glow_shader
	_screen_shake(12.0)
	_update_debug("STOMP ACTIVE")

# === STOMP LOGIC ===
func _handle_stomp(delta: float) -> void:
	if stomp_cooldown_timer > 0.0:
		stomp_cooldown_timer -= delta

	if stomp_impact:
		stomp_impact = false
		_spawn_dust_impact()
		_screen_shake(20.0)
		_break_weak_tiles()
		_damage_enemies()
		player.velocity.y = stomp_bounce_vel
		stomp_cooldown_timer = stomp_cooldown
		_update_debug("STOMP IMPACT!")
		anim_sprite.material = null
		return

	if is_stomping:
		stomp_fall_time += delta
		player.velocity.y = max(player.velocity.y, stomp_fall_speed)
		_update_stomp_visuals(delta)
		_update_debug("STOMP: %.2fs" % stomp_fall_time)
		if player.is_on_floor():
			is_stomping = false
			stomp_impact = true
			anim_sprite.material = null

# === VISUALS: GLOW + SMEAR TRAIL ===
func _update_stomp_visuals(delta: float) -> void:
	stomp_trail_timer += delta
	if stomp_trail_timer >= stomp_trail_interval:
		stomp_trail_timer = 0.0
		_spawn_smear_trail()

	if anim_sprite.material == stomp_glow_shader:
		var intensity = 8.0 + 4.0 * sin(stomp_fall_time * 40.0)
		stomp_glow_shader.set_shader_parameter("glow_intensity", intensity)

# === SMEAR TRAIL ===
func _spawn_smear_trail() -> void:
	if not anim_sprite or not anim_sprite.sprite_frames:
		return
	var frame_tex = anim_sprite.sprite_frames.get_frame_texture(anim_sprite.animation, anim_sprite.frame)
	if not frame_tex:
		return
	var smear = Sprite2D.new()
	smear.texture = frame_tex
	smear.global_position = anim_sprite.global_position
	smear.global_rotation = anim_sprite.global_rotation
	smear.scale = anim_sprite.scale
	smear.flip_h = anim_sprite.flip_h
	smear.flip_v = anim_sprite.flip_v
	smear.modulate = Color(1.0, 0.4, 0.1, 0.85)
	trail_container.add_child(smear)
	var tw = create_tween()
	tw.set_parallel(false)
	tw.tween_property(smear, "modulate:a", 0.0, 0.25)
	tw.tween_property(smear, "scale", smear.scale * 1.45, 0.25)
	tw.tween_callback(smear.queue_free)

# === IMPACT DUST ===
func _spawn_dust_impact() -> void:
	var dust = GPUParticles2D.new()
	dust.amount = 100
	dust.lifetime = 0.4
	dust.one_shot = true
	dust.emitting = true
	dust.global_position = player.global_position + Vector2(0, 16)
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 110.0
	mat.initial_velocity_min = 160.0
	mat.initial_velocity_max = 320.0
	mat.gravity = Vector3(0, 1500, 0)
	mat.color = Color(1.0, 0.5, 0.2, 1.0)
	dust.process_material = mat
	get_tree().current_scene.add_child(dust)

# === TILE BREAK — ENTIRE PLATFORM + CORRECTED PARTICLE POS ===
func _break_weak_tiles() -> void:
	if not breakable_tilemap:
		print("[RED] No tilemap!")
		return

	var foot_pos = player.global_position + Vector2(0, 16)  # Adjusted for 128px tile
	var local_pos = breakable_tilemap.to_local(foot_pos)
	var center = breakable_tilemap.local_to_map(local_pos)

	var platform_id_to_break = -1

	# SCAN 3x3 TO FIND PLATFORM ID
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var coord = center + Vector2i(dx, dy)
			var data = breakable_tilemap.get_cell_tile_data(BREAKABLE_LAYER, coord)
			if data and data.get_custom_data("red_breakable") == true:
				platform_id_to_break = data.get_custom_data("platform_id")
				break
		if platform_id_to_break != -1:
			break

	if platform_id_to_break == -1:
		print("[RED] No breakable tile in 3x3")
		return

	# BREAK ALL TILES WITH SAME platform_id
	var broken_count = 0
	for coord in breakable_tilemap.get_used_cells(BREAKABLE_LAYER):
		var data = breakable_tilemap.get_cell_tile_data(BREAKABLE_LAYER, coord)
		if data and data.get_custom_data("platform_id") == platform_id_to_break:
			var world_pos = breakable_tilemap.map_to_local(coord)
			# CORRECT PARTICLE SPAWN: center of tile
			world_pos += Vector2(TILE_WORLD_SIZE.x * 0.5, TILE_WORLD_SIZE.y * 0.5)
			breakable_tilemap.set_cell(BREAKABLE_LAYER, coord, -1)
			_spawn_break_particles(world_pos)
			broken_count += 1

	_screen_shake(18.0 + broken_count * 2.0)
	print("[RED] BROKE ENTIRE PLATFORM (ID: ", platform_id_to_break, ", ", broken_count, " tiles)")

# === DAMAGE ENEMIES ===
func _damage_enemies() -> void:
	var ss = player.get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = stomp_impact_radius
	var q = PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform.origin = player.global_position + Vector2(0, stomp_impact_radius)
	q.exclude = [player]
	var hits = ss.intersect_shape(q)
	for hit in hits:
		var b = hit.collider
		if b.is_in_group("enemies") and b.has_method("take_damage"):
			b.take_damage(1)

# === BREAK PARTICLES (CENTERED) ===
func _spawn_break_particles(tile_center: Vector2) -> void:
	var shards = GPUParticles2D.new()
	shards.amount = 12
	shards.lifetime = 0.6
	shards.one_shot = true
	shards.emitting = true
	shards.global_position = tile_center
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 80.0
	mat.initial_velocity_min = 200.0
	mat.initial_velocity_max = 400.0
	mat.gravity = Vector3(0, 980, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.color = Color(1.0, 0.4, 0.1)
	shards.process_material = mat
	var tex = ImageTexture.new()
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0.4, 0.1))
	tex.set_image(img)
	shards.texture = tex
	get_tree().current_scene.add_child(shards)
	
	var dust = GPUParticles2D.new()
	dust.amount = 30
	dust.lifetime = 0.4
	dust.one_shot = true
	dust.emitting = true
	dust.global_position = tile_center + Vector2(0, 8)
	var dmat = ParticleProcessMaterial.new()
	dmat.direction = Vector3(0, 1, 0)
	dmat.spread = 100.0
	dmat.initial_velocity_min = 100.0
	dmat.initial_velocity_max = 250.0
	dmat.gravity = Vector3(0, 800, 0)
	dmat.color = Color(0.8, 0.3, 0.1)
	dust.process_material = dmat
	get_tree().current_scene.add_child(dust)

# === CHARGE DASH ===
func _handle_charge_dash(delta: float):
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	if connected:
		if Input.is_action_just_pressed("Dash"):
			_update_debug("DASH BLOCKED")
		return
	if Input.is_action_just_pressed("Dash") and not is_dashing and dash_cooldown_timer <= 0:
		is_charging_dash = true
		charge_dash_timer = 0.0
		dash_charge = 0.0
		_update_debug("CHARGING...")
	if is_charging_dash and Input.is_action_pressed("Dash"):
		charge_dash_timer += delta
		dash_charge = min(charge_dash_timer / charge_dash_max_time, 1.0)
		_update_debug("CHARGE: %.2f" % dash_charge)
	else:
		if is_charging_dash:
			is_dashing = true
			is_charging_dash = false
			dash_speed = lerp(charge_dash_min_speed, charge_dash_max_speed, dash_charge)
			var dur_lerp = lerp(charge_dash_min_duration, charge_dash_max_duration, dash_charge)
			dash_timer = dur_lerp
			player.velocity = Vector2(last_direction * dash_speed, 0)
			dash_cooldown_timer = dash_cooldown
			_update_debug("DASH START: %.0f" % dash_speed)
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			_update_debug("DASH END")

# === GRAPPLE ===
func _handle_grapple(delta: float):
	if Input.is_action_just_pressed("Traversal"):
		if current_grapple_target and not connected and _is_in_range():
			current_grapple_target.attach_grapple()
			connected = true
			current_slack = max_slack
			current_grapple_target.reset_return_timer()
			_on_grapple_attached()
		elif connected:
			_detach()
	if not connected or not current_grapple_target:
		if thread_line: thread_line.visible = false
		return
	var target_pos = current_grapple_target.global_position
	var player_pos = player.global_position
	var away_dir = (player_pos - target_pos).normalized()
	var pulling = player.velocity.dot(away_dir) > pull_vel_threshold
	var dist = player_pos.distance_to(target_pos)
	if dist > grapple_max_range:
		player.velocity.x = 0
		if pulling:
			current_grapple_target.reset_return_timer()
	else:
		var stretch_ratio = current_grapple_target.get_stretch_ratio(
			player_pos, taut_stop_dist, max_total_stretch_mult, current_slack)
		var stretch_mult = lerp(1.0, 0.0, stretch_ratio)
		var slack_t = 1.0 - (current_slack / max_slack)
		var slack_mult = lerp(1.0, grapple_slow_factor, slack_t)
		var final_mult = slack_mult * stretch_mult
		if pulling:
			var old_slack = current_slack
			current_slack = max(current_slack - slack_take_rate * delta, 0.0)
			if current_grapple_target:
				current_grapple_target.reset_return_timer()
			if player.is_on_floor():
				player.velocity.x = player.speed * Input.get_axis("move_left", "move_right") * final_mult
			if stretch_ratio >= 1.0:
				player.velocity.x = 0
				current_grapple_target.reset_return_timer()
			if old_slack > max_slack * 0.99 and current_slack < max_slack * 0.99:
				_screen_shake(screen_shake_small)
			if old_slack > 2.0 and current_slack <= 0.0:
				_screen_shake(screen_shake_big)
			if current_slack <= 0.0:
				current_grapple_target.apply_impulse(away_dir * yank_force * delta, Vector2.ZERO)
		else:
			current_slack = min(current_slack + slack_restore_rate * delta, max_slack)
	_update_thread_line()
	if Input.is_action_pressed("Traversal") and not connected:
		var t = _find_unravel_target()
		if t: _unravel(t)

# === HELPERS ===
func _update_thread_line():
	if not thread_line: return
	thread_line.clear_points()
	if not connected or not current_grapple_target:
		thread_line.visible = false
		return
	var t = current_grapple_target.global_position
	var p = player.global_position
	var slack_factor = current_slack / max_slack
	var sag_amount = 60.0 * slack_factor
	thread_line.visible = true
	thread_line.default_color.a = 1.0
	var points = 8
	for i in range(points + 1):
		var t_val = i / float(points)
		var base = t.lerp(p, t_val)
		var mid = Vector2(0, 1) * sag_amount * sin(PI * t_val)
		thread_line.add_point(thread_line.to_local(base + mid))

func _update_debug(text: String):
	if debug_label:
		debug_label.text = text

func _is_in_range() -> bool:
	if not current_grapple_target: return false
	var area = current_grapple_target.get_node_or_null("DetectionArea") as Area2D
	return area and area.overlaps_body(player)

func _detach():
	if current_grapple_target:
		current_grapple_target.detach_grapple()
	connected = false
	current_slack = 0.0
	if thread_line: _update_thread_line()
	if _is_in_range():
		_show_attach_prompt()
	else:
		if grapple_popup: grapple_popup.visible = false
	current_grapple_target = null

func _show_attach_prompt():
	if not grapple_popup: return
	grapple_popup.visible = true
	grapple_popup.text = "Q to attach"
	var tw = create_tween()
	tw.tween_property(grapple_popup, "scale", Vector2(1.2,1.2), 0.1)
	tw.tween_property(grapple_popup, "scale", Vector2(1,1), 0.1).set_trans(Tween.TRANS_BOUNCE)

func _on_detection_entered(body, plat):
	if body != player: return
	if current_grapple_target: return
	current_grapple_target = plat
	plat.set_in_range(true)
	_show_attach_prompt()

func _on_detection_exited(body, plat):
	if body != player: return
	if current_grapple_target == plat and not connected:
		current_grapple_target = null
		plat.set_in_range(false)
		if grapple_popup: grapple_popup.visible = false

func _on_grapple_attached():
	if grapple_popup:
		grapple_popup.text = "Q to release"
		grapple_popup.visible = true

func _find_unravel_target() -> Node2D:
	if not player: return null
	var space = player.get_world_2d().direct_space_state
	var end = player.global_position + Vector2(last_direction * 50.0, 0)
	var q = PhysicsRayQueryParameters2D.create(player.global_position, end)
	q.collide_with_bodies = true
	q.collide_with_areas = false
	q.exclude = [player]
	var r = space.intersect_ray(q)
	return r.collider if r and r.collider.is_in_group("red_unravel") else null

func _unravel(t: Node2D):
	var tw = create_tween()
	tw.parallel().tween_property(t, "modulate:a", 0.0, 0.3)
	tw.tween_callback(t.queue_free)

func _screen_shake(amount: float):
	var cam = get_viewport().get_camera_2d()
	if not cam: return
	cam.offset += Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
	var tw = create_tween()
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
