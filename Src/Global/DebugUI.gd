extends Node

## Global debug UI singleton
## Provides a single debug label accessible from anywhere

var debug_label: Label
var target_node: Node2D = null  # Usually the player
var canvas_layer: CanvasLayer = null

func _ready():
	# Create canvas layer for debug UI (always on top)
	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "DebugCanvas"
	add_child(canvas_layer)
	
	# Create debug label
	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", 18)
	debug_label.text = "Debug"
	debug_label.position = Vector2(10, 10)  # Top-left corner by default
	canvas_layer.add_child(debug_label)

## Update debug text - call from anywhere
func update_debug(text: String):
	if debug_label:
		debug_label.text = text

## Clear debug text
func clear_debug():
	if debug_label:
		debug_label.text = ""

## Set target node for relative positioning (optional)
## When set, the debug label will follow the target node
func set_target_node(node: Node2D):
	target_node = node
	if target_node and debug_label:
		# Position relative to target (above player)
		debug_label.position = Vector2(0, -120)
		# Move label to follow target
		if debug_label.get_parent() != target_node:
			debug_label.get_parent().remove_child(debug_label)
			target_node.add_child(debug_label)

## Reset to screen-relative positioning
func reset_position():
	if debug_label and target_node:
		if debug_label.get_parent() == target_node:
			target_node.remove_child(debug_label)
		canvas_layer.add_child(debug_label)
		debug_label.position = Vector2(10, 10)
		target_node = null
