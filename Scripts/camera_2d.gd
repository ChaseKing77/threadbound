extends Camera2D

@export var smoothing_speed := 8.0  # Snappier default for better recentering (tweak in inspector)
@export var horizontal_dead_zone := 30.0  # Pixels; player can move this much horizontally without camera following
@export var vertical_dead_zone := 30.0  # Pixels; same for vertical
@export var look_ahead_distance := 60.0  # Small offset for ~3% screen bias/lead (Hollow Knight tight; try 40-80 for less/more)
@export var bound_margin: Vector2 = Vector2(192, 192)  # Shrink bounds inward by this much on each side to hide outer edges (1.5 tiles at 128px effective = 192px)
var level_bounds: Rect2

# Assume your player has 'last_direction' (1 right, -1 left) and 'velocity' Vector2
@onready var player = get_parent()  # For accessing player.last_direction and player.velocity

# For damping the look-ahead offset smoothly
var current_look_ahead_offset: float = 0.0
@export var look_ahead_damp_speed := 6.0  # How quickly the offset transitions (higher = snappier to new target; ~6 feels fluid for HK)

func _ready():
	enabled = true  # Activate the camera (if this errors in your version, try 'enabled = true')

	# Get the TileMapLayer called "Base Tiles"
	var tilemap_layer = get_node_or_null("../../Base Tiles")
	if tilemap_layer:
		level_bounds = get_tilemap_layer_bounds(tilemap_layer)
		print("Camera ready. Level bounds: ", level_bounds)
	else:
		push_warning("Camera: Could not find TileMapLayer '../../Base Tiles'")

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	var desired = player.global_position

	# Target offset: Always apply small lead/bias in last_direction (facing dir)
	var target_offset = player.last_direction * look_ahead_distance

	# Damp the current offset toward target (smooth transition on dir changes)
	current_look_ahead_offset = lerp(current_look_ahead_offset, target_offset, clamp(look_ahead_damp_speed * delta, 0.0, 1.0))

	# Apply the damped offset to desired position (camera leads, player pulls ahead on changes)
	desired.x += current_look_ahead_offset

	# Clamp the desired position first (accounts for viewport to keep screen full)
	var half_screen = get_viewport_rect().size * 0.5
	var clamped_desired = desired
	if level_bounds.size != Vector2.ZERO:
		clamped_desired.x = clamp(desired.x, level_bounds.position.x + half_screen.x, level_bounds.position.x + level_bounds.size.x - half_screen.x)
		clamped_desired.y = clamp(desired.y, level_bounds.position.y + half_screen.y, level_bounds.position.y + level_bounds.size.y - half_screen.y)

	# Deadzone logic: Only update target if outside deadzone (per axis, for subtle following—enhances the "ahead" feel)
	var target = global_position
	if abs(clamped_desired.x - global_position.x) > horizontal_dead_zone:
		target.x = clamped_desired.x
	if abs(clamped_desired.y - global_position.y) > vertical_dead_zone:
		target.y = clamped_desired.y

	# Smooth to target with lerp
	var t = clamp(smoothing_speed * delta, 0.0, 1.0)
	var smoothed = global_position.lerp(target, t)

	# Special falling handling (faster vertical when falling, like Hollow Knight)
	if player.velocity.y > 0:  # Player is falling (y positive down)
		smoothed.y = lerp(global_position.y, target.y, clamp(player.velocity.y * delta * 0.5, 0.0, 1.0))  # Scale by velocity for catch-up; tweak 0.5

	global_position = smoothed

	# Update debug draw every frame
	queue_redraw()

# --- Accurate global bounds (handles scale=0.25, offsets, etc.) with margin shrink ---
func get_tilemap_layer_bounds(tilemap_layer: TileMapLayer) -> Rect2:
	var used_rect: Rect2i = tilemap_layer.get_used_rect()  # Cell coords bounding box
	if used_rect.size == Vector2i.ZERO:
		print("TileMapLayer has no used cells—bounds are zero.")
		return Rect2()

	# Min cell (top-left) and max cell +1 (for bottom-right edge)
	var min_cell: Vector2i = used_rect.position
	var max_cell: Vector2i = used_rect.end  # end is after last cell, perfect for size

	# Get local positions
	var top_left_local: Vector2 = tilemap_layer.map_to_local(min_cell)
	var bottom_right_local: Vector2 = tilemap_layer.map_to_local(max_cell)

	# Convert to global space (accounts for scale=0.25, offsets, etc.)
	var top_left_global: Vector2 = tilemap_layer.to_global(top_left_local)
	var bottom_right_global: Vector2 = tilemap_layer.to_global(bottom_right_local)

	var size: Vector2 = bottom_right_global - top_left_global

	# Apply margin to shrink bounds (hides outer edges; positive values shrink inward)
	top_left_global += bound_margin
	size -= bound_margin * 2.0

	return Rect2(top_left_global, size)

func _draw():
	if level_bounds.size == Vector2.ZERO:
		return
	# Draw the bounds rectangle in local space for debug (red outline)
	var local_top_left = to_local(level_bounds.position)
	var local_size = level_bounds.size  # size remains the same in local space
	draw_rect(Rect2(local_top_left, local_size), Color(1, 0, 0), false, 2.0)
