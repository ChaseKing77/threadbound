class_name RedArchetype
extends BaseArchetype

# ===================================================================
# RED ARCHETYPE — Charge Jump, Charge Dash, Reverse Grapple
# ===================================================================

# ──────────────────────── VISUAL REFERENCES ────────────────────────
var anim_sprite: AnimatedSprite2D
var thread_line: Line2D
var ui: ArchetypeUI

# ──────────────────────── REVERSE GRAPPLE STATE ───────────────────────
var current_grapple_target: RigidBody2D = null
var connected: bool = false
var current_slack: float = 0.0

# ──────────────────────── CHARGE JUMP STATE ───────────────────────
var is_charging_jump: bool = false
var jump_charge_timer: float = 0.0
var jump_charge_ratio: float = 0.0
@export var jump_charge_max_time: float = 0.9
@export var jump_charge_min_force: float = 700.0
@export var jump_charge_max_force: float = 1800.0


# ──────────────────────── CHARGE DASH STATE ───────────────────────
var is_dashing: bool = false
var is_charging_dash: bool = false
var charge_dash_timer: float = 0.0
var dash_charge: float = 0.0
var last_direction: int = 1
var dash_speed: float = 0.0
@export var charge_dash_max_time: float = 2.0
@export var charge_dash_min_speed: float = 600.0
@export var charge_dash_max_speed: float = 1800.0
@export var charge_dash_min_duration: float = 0.1
@export var charge_dash_max_duration: float = 0.3

# ──────────────────────── REVERSE GRAPPLE TUNABLES ───────────────────────
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

# ===================================================================
# INITIALIZATION
# ===================================================================
func _initialize_archetype() -> void:
	charge_glow_color = ArchetypeConstants.RED_COLOR

	anim_sprite = player.get_node_or_null("Player Animation") as AnimatedSprite2D
	if not anim_sprite:
		push_error("RedArchetype: 'Player Animation' node not found!")
		return

	# UI Component
	ui = ArchetypeUI.new()
	ui.parent_node = player
	add_child(ui)
	
	# Set up global debug UI
	if DebugUI:
		DebugUI.set_target_node(player)
		DebugUI.update_debug("RED: Ready")

	# Thread line visual
	thread_line = Line2D.new()
	thread_line.width = 3.0
	thread_line.default_color = ArchetypeConstants.RED_COLOR
	thread_line.default_color.a = 0.8
	thread_line.visible = false
	player.add_child(thread_line)

	# Connect to grapple platforms
	for plat in get_tree().get_nodes_in_group("red_grapple"):
		if plat.has_node("DetectionArea"):
			var area: Area2D = plat.get_node("DetectionArea")
			area.body_entered.connect(_on_detection_entered.bind(plat))
			area.body_exited.connect(_on_detection_exited.bind(plat))

	print("[RED] Archetype loaded successfully")

# ===================================================================
# PRIMARY ACTION: CHARGE JUMP
# ===================================================================
func handle_primary_action(state: ActionState, delta: float) -> void:
	match state:
		ActionState.PRESSED:
			_start_jump_charge()
		ActionState.RELEASED:
			if player.is_on_floor() or player.coyote_timer > 0.0:
				_perform_charged_jump()
			else:
				_cancel_jump_charge()
		ActionState.HOLDING:
			if is_charging_jump:
				if player.is_on_floor() or player.coyote_timer > 0.0:
					jump_charge_timer = min(jump_charge_timer + delta, jump_charge_max_time)
					jump_charge_ratio = clamp(jump_charge_timer / jump_charge_max_time, 0.0, 1.0)
					if player.has_method("set_jump_charge_level"):
						player.set_jump_charge_level(jump_charge_ratio)
				else:
					jump_charge_ratio = 0.0
					if player.has_method("set_jump_charge_level"):
						player.set_jump_charge_level(0.0)

func _start_jump_charge() -> void:
	is_charging_jump = true
	jump_charge_timer = 0.0
	jump_charge_ratio = 0.0

func _perform_charged_jump() -> void:
	if not is_charging_jump:
		return
	var charge = clamp(jump_charge_ratio, 0.0, 1.0)
	var force = lerp(jump_charge_min_force, jump_charge_max_force, charge)
	player.velocity.y = -force
	player.coyote_timer = 0.0
	_cancel_jump_charge()

func _cancel_jump_charge() -> void:
	is_charging_jump = false
	jump_charge_timer = 0.0
	jump_charge_ratio = 0.0
	if player.has_method("set_jump_charge_level"):
		player.set_jump_charge_level(0.0)

# ===================================================================
# SECONDARY ACTION: CHARGE DASH
# ===================================================================
func handle_secondary_action(state: ActionState, delta: float) -> void:
	_handle_charge_dash(state, delta)

func _handle_charge_dash(state: ActionState, delta: float) -> void:
	# Block dash if connected to grapple
	if connected and state == ActionState.PRESSED:
		return

	match state:
		ActionState.PRESSED:
			# Start charging dash
			if not is_dashing:
				is_charging_dash = true
				charge_dash_timer = 0.0
				dash_charge = 0.0
				_update_player_dash_charge(0.0)
		ActionState.RELEASED:
			# Release dash - set is_dashing to true
			if is_charging_dash:
				is_dashing = true
				is_charging_dash = false
				dash_speed = lerp(charge_dash_min_speed, charge_dash_max_speed, dash_charge)
				player.velocity = Vector2(last_direction * dash_speed, 0)
				# Start ability cooldown timer in player (1 second dash duration)
				if player.has_method("start_ability_cooldown"):
					player.start_ability_cooldown(0.2)
				_update_player_dash_charge(0.0)
		ActionState.HOLDING:
			# Continue charging while held
			if is_charging_dash:
				charge_dash_timer += delta
				dash_charge = min(charge_dash_timer / charge_dash_max_time, 1.0)
				_update_player_dash_charge(dash_charge)

	# Dash timer is now managed by player's ability_cooldown_timer
	# No need to manually decrement here - handled in on_ability_cooldown_complete()
	if not is_charging_dash and not is_dashing:
		_update_player_dash_charge(0.0)


func _update_player_dash_charge(value: float) -> void:
	if player and player.has_method("set_dash_charge_level"):
		player.set_dash_charge_level(value)

## Called when ability cooldown timer reaches zero
func on_ability_cooldown_complete() -> void:
	# Dash duration complete - reset dash state
	if is_dashing:
		is_dashing = false
		_update_player_dash_charge(0.0)

# ===================================================================
# THREAD MECHANIC: REVERSE GRAPPLE
# ===================================================================
func thread_mechanic(delta: float) -> void:
	_handle_reverse_grapple(delta)

func _handle_reverse_grapple(delta: float) -> void:
	# Attach/detach
	if Input.is_action_just_pressed("Traversal"):
		if current_grapple_target and not connected and _is_in_range():
			current_grapple_target.attach_grapple()
			connected = true
			current_slack = max_slack
			current_grapple_target.reset_return_timer()
			ui.hide_grapple_prompt()
		elif connected:
			_detach()

	if not connected or not current_grapple_target:
		if thread_line:
			thread_line.visible = false
		return

	var target_pos = current_grapple_target.global_position
	var player_pos = player.global_position
	var away_dir = (player_pos - target_pos).normalized()
	var pulling = player.velocity.dot(away_dir) > pull_vel_threshold
	var distance_to_target = player_pos.distance_to(target_pos)

	if distance_to_target > grapple_max_range:
		player.velocity.x = 0

	if pulling:
		var old_slack = current_slack
		current_slack = max(current_slack - slack_take_rate * delta, 0.0)
		current_grapple_target.reset_return_timer()

		if player.is_on_floor():
			player.velocity.x = player.speed * Input.get_axis("move_left", "move_right")

		if old_slack > max_slack * 0.99 and current_slack < max_slack * 0.99:
			_screen_shake(screen_shake_small)
		if old_slack > 2.0 and current_slack <= 0.0:
			_screen_shake(screen_shake_big)
		if current_slack <= 0.0:
			current_grapple_target.apply_impulse(away_dir * yank_force * delta, Vector2.ZERO)
	else:
		var stretch_ratio = current_grapple_target.get_stretch_ratio(
			player_pos, taut_stop_dist, max_total_stretch_mult, current_slack)
		var stretch_mult = lerp(1.0, 0.0, stretch_ratio)
		var slack_t = 1.0 - (current_slack / max_slack)
		var slack_mult = lerp(1.0, grapple_slow_factor, slack_t)
		var final_mult = slack_mult * stretch_mult

		if player.is_on_floor():
			player.velocity.x = player.speed * Input.get_axis("move_left", "move_right") * final_mult
		if stretch_ratio >= 1.0:
			player.velocity.x = 0
			current_grapple_target.reset_return_timer()

		current_slack = min(current_slack + slack_restore_rate * delta, max_slack)

	_update_thread_line()

# ===================================================================
# PROCESS MECHANICS
# ===================================================================
func process_mechanics(delta: float, _p: CharacterBody2D) -> void:
	if not player:
		return

	var h_input = Input.get_axis("move_left", "move_right")
	if h_input != 0:
		last_direction = sign(h_input)

	# Update dash state
	if is_dashing:
		player.velocity.x = last_direction * dash_speed

# ===================================================================
# HELPER FUNCTIONS
# ===================================================================
func _update_thread_line() -> void:
	if not thread_line:
		return
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
		var ratio = i / float(points)
		var base = t.lerp(p, ratio)
		var mid = Vector2(0, 1) * sag_amount * sin(PI * ratio)
		thread_line.add_point(thread_line.to_local(base + mid))

func _is_in_range() -> bool:
	if not current_grapple_target:
		return false
	var area = current_grapple_target.get_node_or_null("DetectionArea") as Area2D
	return area and area.overlaps_body(player)

func _detach() -> void:
	if current_grapple_target:
		current_grapple_target.detach_grapple()
	connected = false
	current_slack = 0.0
	if thread_line:
		_update_thread_line()
	if _is_in_range():
		ui.show_grapple_prompt("Q to attach")
	else:
		ui.hide_grapple_prompt()
	current_grapple_target = null

func _on_detection_entered(body, plat) -> void:
	if body != player:
		return
	if current_grapple_target:
		return
	current_grapple_target = plat
	plat.set_in_range(true)
	ui.show_grapple_prompt("Q to attach")

func _on_detection_exited(body, plat) -> void:
	if body != player:
		return
	if current_grapple_target == plat and not connected:
		current_grapple_target = null
		plat.set_in_range(false)
		ui.hide_grapple_prompt()

func _screen_shake(amount: float) -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam:
		return
	cam.offset += Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
	var tw = create_tween()
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
