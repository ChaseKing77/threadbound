extends Camera2D

@export var smoothing_speed: float = 5.0
var level_bounds: Rect2 = Rect2()  # initialized empty rect

func _ready() -> void:
	var tilemap_layer: TileMapLayer = get_node_or_null("../Base Tiles")
	if tilemap_layer:
		level_bounds = get_tilemap_layer_bounds(tilemap_layer)
		print("Level bounds: ", level_bounds)
	else:
		push_warning("Camera: Could not find TileMapLayer 'Base Tiles'")

func _process(delta: float) -> void:
	if not is_instance_valid(get_parent()):
		return

	var desired: Vector2 = get_parent().global_position
	var smoothed: Vector2 = global_position.lerp(desired, clamp(smoothing_speed * delta, 0.0, 1.0))

	if level_bounds.size != Vector2.ZERO:
		# Clamp inside level bounds
		var half_screen: Vector2 = get_viewport_rect().size * 0.5
		var min_x: float = level_bounds.position.x + half_screen.x
		var max_x: float = level_bounds.position.x + level_bounds.size.x - half_screen.x
		var min_y: float = level_bounds.position.y + half_screen.y
		var max_y: float = level_bounds.position.y + level_bounds.size.y - half_screen.y

		smoothed.x = clamp(smoothed.x, min_x, max_x)
		smoothed.y = clamp(smoothed.y, min_y, max_y)

	global_position = smoothed


func get_tilemap_layer_bounds(tilemap_layer: TileMapLayer) -> Rect2:
	var used_cells: Array[Vector2i] = tilemap_layer.get_used_cells()
	if used_cells.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)

	var min_x = used_cells[0].x
	var min_y = used_cells[0].y
	var max_x = used_cells[0].x
	var max_y = used_cells[0].y

	for cell in used_cells:
		min_x = min(min_x, cell.x)
		min_y = min(min_y, cell.y)
		max_x = max(max_x, cell.x)
		max_y = max(max_y, cell.y)

	var cell_size: Vector2 = Vector2(tilemap_layer.tile_set.tile_size)
	var top_left: Vector2 = Vector2(min_x, min_y) * cell_size
	var size: Vector2 = Vector2((max_x - min_x + 1), (max_y - min_y + 1)) * cell_size

	return Rect2(top_left, size)
