class_name ArchetypeUI
extends Node

## UI component for archetype-specific UI elements
## Handles popups and other visual feedback

var grapple_popup: Label
var parent_node: Node

func _init(_parent: Node = null):
	parent_node = _parent

func _ready():
	if parent_node:
		_setup_ui()

func _setup_ui():
	# Grapple popup
	grapple_popup = Label.new()
	grapple_popup.add_theme_font_size_override("font_size", 24)
	grapple_popup.position = Vector2(0, -80)
	grapple_popup.visible = false
	parent_node.add_child(grapple_popup)

func show_grapple_prompt(text: String = "Q to attach"):
	if not grapple_popup:
		return
	grapple_popup.visible = true
	grapple_popup.text = text
	var tw = create_tween()
	tw.tween_property(grapple_popup, "scale", Vector2(1.2, 1.2), 0.1)
	tw.tween_property(grapple_popup, "scale", Vector2(1, 1), 0.1).set_trans(Tween.TRANS_BOUNCE)

func hide_grapple_prompt():
	if grapple_popup:
		grapple_popup.visible = false

