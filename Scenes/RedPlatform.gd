extends RigidBody2D

@export var max_pull_dist: float = 650.0
@export var return_speed: float = 600.0
@export var return_delay: float = 2.0
@export var auto_return_delay: float = 3.0

var anchor_pos: Vector2
var return_timer: float = -1.0
var auto_return_timer: float = 0.0
var is_attached: bool = false

@onready var detection_area: Area2D = $DetectionArea
@onready var platform_tiles: TileMapLayer = $PlatformTiles

func _ready():
	anchor_pos = global_position
	gravity_scale = 0.0
	contact_monitor = true
	max_contacts_reported = 5
	linear_damp = 25.0
	angular_damp = 25.0
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.0
	physics_material_override.friction = 1.0
	collision_layer = 4
	collision_mask = 3

func _physics_process(delta):
	var to_anchor = anchor_pos - global_position
	var dist = to_anchor.length()

	if is_attached:
		auto_return_timer += delta
		if auto_return_timer >= auto_return_delay:
			var back = to_anchor.normalized()
			apply_central_force(back * return_speed * 0.6 * delta)
			linear_velocity = linear_velocity.lerp(Vector2.ZERO, delta * 6.0)
	else:
		auto_return_timer = 0.0

	if not is_attached:
		if return_timer > 0:
			return_timer -= delta
		if return_timer <= 0 and dist > 0.1:
			var back = to_anchor.normalized()
			apply_central_force(back * return_speed * 0.8 * delta)
			linear_velocity = linear_velocity.lerp(Vector2.ZERO, delta * 8.0)

func get_anchor_dist() -> float:
	return global_position.distance_to(anchor_pos)

func get_stretch_ratio(player_pos: Vector2, taut_stop_dist: float, max_mult: float, remaining_slack: float) -> float:
	var anchor_dist = get_anchor_dist()
	var player_dist = global_position.distance_to(player_pos)
	var used = anchor_dist + player_dist - remaining_slack
	var max_total = max_pull_dist + taut_stop_dist
	var ratio = clamp(used / (max_total * max_mult), 0.0, 1.0)
	return ratio

func attach_grapple():
	if is_attached: return
	is_attached = true
	auto_return_timer = 0.0
	return_timer = -1.0
	platform_tiles.modulate = Color(2.0, 0.3, 0.3, 1.5)
	await get_tree().create_timer(0.2).timeout
	if is_attached:
		platform_tiles.modulate = Color.WHITE

func detach_grapple():
	is_attached = false
	return_timer = return_delay
	auto_return_timer = 0.0

func set_in_range(active: bool):
	if active:
		platform_tiles.modulate = Color(1.5, 1.5, 1.5, 1.0)
	else:
		platform_tiles.modulate = Color.WHITE

func reset_return_timer():
	if is_attached:
		return_timer = -1.0
		auto_return_timer = 0.0
