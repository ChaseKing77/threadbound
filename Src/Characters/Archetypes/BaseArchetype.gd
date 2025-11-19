class_name BaseArchetype
extends Node

## Base class for all archetypes
## Provides common interface: primary_action, secondary_action, thread_mechanic

# Player reference - set in _enter_tree()
var player: CharacterBody2D

# Charge glow color - override in subclasses for archetype-specific color
@export var charge_glow_color: Color = Color(1, 0, 0, 1)

# ===================================================================
# INITIALIZATION
# ===================================================================
func _enter_tree():
	player = get_parent() as CharacterBody2D
	if not player:
		push_error("%s: Parent is NOT CharacterBody2D!" % get_script().get_path().get_file())
		return
	_initialize_archetype()

# Override in subclasses for archetype-specific initialization
func _initialize_archetype() -> void:
	pass

# ===================================================================
# ARCHETYPE ACTION INTERFACE
# ===================================================================

enum ActionState {
	PRESSED,    # Just pressed
	RELEASED,   # Just released
	HOLDING     # Currently held (called every frame while held)
}

## Primary action (typically jump) - called when primary input state changes
## state: ActionState (PRESSED, RELEASED, or HOLDING)
## delta: Time since last frame
func handle_primary_action(state: ActionState, delta: float) -> void:
	pass

## Secondary action (typically dash) - called when secondary input state changes
## state: ActionState (PRESSED, RELEASED, or HOLDING)
## delta: Time since last frame
func handle_secondary_action(state: ActionState, delta: float) -> void:
	pass

# Legacy methods for backward compatibility (deprecated)
func primary_action(delta: float) -> void:
	pass

func secondary_action(delta: float) -> void:
	pass

## Thread mechanic - called every frame to handle thread-based abilities
## Examples: reverse grapple, thread swing, double-jump
func thread_mechanic(delta: float) -> void:
	pass

## Process archetype-specific mechanics - called every frame
func process_mechanics(delta: float, _p: CharacterBody2D) -> void:
	pass

## Called when ability cooldown timer reaches zero
## Override in subclasses to handle cooldown completion (e.g., reset dash state)
func on_ability_cooldown_complete() -> void:
	pass
