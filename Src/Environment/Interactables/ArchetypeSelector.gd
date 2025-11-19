extends Area2D

# Archetype color - set this in the editor (Red, Blue, or Yellow)
@export var archetype_color: String = ArchetypeConstants.RED

# Compatibility property - returns archetype_color for backward compatibility
var color: String:
	get:
		return archetype_color

@onready var popup: Label = Label.new()

func _ready():
	add_to_group("selectors")
	_setup_visuals()
	_connect_signals()

func _setup_visuals():
	var rect_color = _get_color_for_archetype(archetype_color)
	if has_node("ColorRect"):
		$ColorRect.color = rect_color
	popup.text = "Use W Key to select " + archetype_color + " archetype"
	popup.visible = false
	popup.position = Vector2(-125, -125)
	add_child(popup)

func _get_color_for_archetype(color: String) -> Color:
	return ArchetypeConstants.get_color(color)

func _connect_signals():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		body._on_interactable_entered(self)
		popup.visible = true

func _on_body_exited(body):
	if body.name == "Player":
		body._on_interactable_exited(self)
		popup.visible = false

