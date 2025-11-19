class_name BlueArchetype
extends BaseArchetype

# ===================================================================
# BLUE ARCHETYPE — Peak Suspend Jump, Thread Swing
# ===================================================================

var last_direction: int = 1

# ──────────────────────── VISUAL REFERENCES ────────────────────────
var ui: ArchetypeUI

# ──────────────────────── PEAK SUSPEND JUMP STATE ───────────────────────
var is_suspended_at_peak: bool = false
var peak_suspend_timer: float = 0.0
var new_velocity_y: float = 0.0  # Store previous frame's vertical velocity for peak detection
var previous_velocity_y: float = 0.0  # Store previous frame's vertical velocity for peak detection
@export var jump_force: float = 700.0
@export var peak_suspend_duration: float = 0.5  # Time player suspends at jump peak

# ──────────────────────── THREAD SWING STATE ───────────────────────
var thread_swing_target: Node2D = null
var is_swinging: bool = false
var swing_angle: float = 0.0
var swing_velocity: float = 0.0
@export var swing_max_range: float = 300.0
@export var swing_gravity: float = 500.0
@export var swing_damping: float = 0.95
 

# ===================================================================
# INITIALIZATION
# ===================================================================
func _initialize_archetype() -> void:
	charge_glow_color = ArchetypeConstants.BLUE_COLOR
	# UI Component
	ui = ArchetypeUI.new()
	ui.parent_node = player
	add_child(ui)
	
	# Set up global debug UI
	if DebugUI:
		DebugUI.set_target_node(player)
		DebugUI.update_debug("BLUE: Ready")

	print("[BLUE] Archetype loaded successfully")

# ===================================================================
# PRIMARY ACTION: PEAK SUSPEND JUMP
# ===================================================================
func handle_primary_action(state: ActionState, delta: float) -> void:
	match state:
		ActionState.PRESSED:
			# Blue archetype: instant jump on press
			if player.is_on_floor() or player.coyote_timer > 0.0:
				player.velocity.y = -jump_force
				player.coyote_timer = 0.0
				previous_velocity_y = player.velocity.y
		ActionState.RELEASED, ActionState.HOLDING:
			# No action needed for release/hold
			pass


# ===================================================================
# SECONDARY ACTION: None
# ===================================================================
func handle_secondary_action(state: ActionState, delta: float) -> void:
	pass


# ===================================================================
# THREAD MECHANIC: THREAD SWING
# ===================================================================
func thread_mechanic(delta: float) -> void:
	_handle_thread_swing(delta)

func _handle_thread_swing(delta: float) -> void:
	# TODO: Implement thread swing mechanic
	# Player can attach to blue-threaded objects and swing
	if Input.is_action_just_pressed("Traversal"):
		if not is_swinging:
			# Try to attach to nearest blue thread target
			_attach_to_thread_target()
		else:
			# Detach from swing
			_detach_from_swing()

	if is_swinging and thread_swing_target:
		# Update swing physics
		_update_swing_physics(delta)
	else:
		is_swinging = false

func _attach_to_thread_target() -> void:
	# Find nearest blue thread target in range
	var nearest_target = null
	var nearest_dist = swing_max_range
	for target in get_tree().get_nodes_in_group("blue_thread"):
		var dist = player.global_position.distance_to(target.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_target = target

	if nearest_target:
		thread_swing_target = nearest_target
		is_swinging = true
		swing_angle = 0.0
		swing_velocity = 0.0

func _detach_from_swing() -> void:
	is_swinging = false
	thread_swing_target = null

func _update_swing_physics(delta: float) -> void:
	if not thread_swing_target:
		return

	var to_target = thread_swing_target.global_position - player.global_position
	var distance = to_target.length()
	var angle = atan2(to_target.y, to_target.x)

	# Apply swing gravity
	swing_velocity += swing_gravity * delta * sin(angle)
	swing_velocity *= swing_damping

	# Update angle
	swing_angle += swing_velocity * delta

	# Apply swing force to player
	var swing_force = Vector2(cos(swing_angle), sin(swing_angle)) * swing_velocity * 100.0
	player.velocity += swing_force * delta

# ===================================================================
# PROCESS MECHANICS
# ===================================================================
func process_mechanics(delta: float, _p: CharacterBody2D) -> void:
	if not player:
		return

	var h_input = Input.get_axis("move_left", "move_right")
	if h_input != 0:
		last_direction = sign(h_input)


	# Reset when on ground
	if player.is_on_floor():
		previous_velocity_y = 0.0
	else:
		previous_velocity_y = new_velocity_y
	new_velocity_y = player.velocity.y

	# Detect peak of jump: previous velocity was negative (ascending), current is positive/zero (reached peak)
	if not is_suspended_at_peak and new_velocity_y > 0.0 and previous_velocity_y <= 0.0:
		is_suspended_at_peak = true
		peak_suspend_timer = peak_suspend_duration
		player.velocity.y = 0.0

	if is_suspended_at_peak:
		peak_suspend_timer -= delta
		if peak_suspend_timer <= 0.0:
			is_suspended_at_peak = false
		else:
			player.velocity.y -= player.gravity * delta
