class_name YellowArchetype
extends BaseArchetype

var last_direction: int = 1

# ===================================================================
# YELLOW ARCHETYPE — Double-Jump
# ===================================================================

# ──────────────────────── VISUAL REFERENCES ────────────────────────
var ui: ArchetypeUI

# ──────────────────────── DOUBLE-JUMP THREAD STATE ───────────────────────
var jump_count: int = 0

# ===================================================================
# INITIALIZATION
# ===================================================================
func _initialize_archetype() -> void:
	jump_count = 0
	charge_glow_color = ArchetypeConstants.YELLOW_COLOR
	# UI Component
	ui = ArchetypeUI.new()
	ui.parent_node = player
	add_child(ui)
	
	# Set up global debug UI
	if DebugUI:
		DebugUI.set_target_node(player)
		DebugUI.update_debug("YELLOW: Ready")

	print("[YELLOW] Archetype loaded successfully")


# ===================================================================
# PRIMARY ACTION: CHARGE JUMP
# ===================================================================
func handle_primary_action(state: ActionState, delta: float) -> void:
	match state:
		ActionState.PRESSED:
			_handle_double_jump()
		ActionState.RELEASED, ActionState.HOLDING:
			# No action needed
			pass

# ===================================================================
# SECONDARY ACTION: None
# ===================================================================
func handle_secondary_action(state: ActionState, delta: float) -> void:
	pass

# ===================================================================
# THREAD MECHANIC: None
# ===================================================================
func thread_mechanic(delta: float) -> void:
	pass

func _handle_double_jump() -> void:
	# Double jump is available when in air and not already used
	if jump_count < 3:
		player.velocity.y = -player.jump_force
		jump_count += 1

# ===================================================================
# PROCESS MECHANICS
# ===================================================================
func process_mechanics(delta: float, _p: CharacterBody2D) -> void:
	if not player:
		return

	var h_input = Input.get_axis("move_left", "move_right")
	if h_input != 0:
		last_direction = sign(h_input)

	if player.is_on_floor():
		jump_count = 0
