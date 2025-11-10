extends Area2D

@export var color: String = "Yellow"  # Set to "Blue" or "Yellow" for others
@onready var popup = Label.new()  # Temp popup

func _ready():
	add_to_group("selectors")  # For player to detect
	var rect_color: Color = Color(0, 0, 0, 1)  # Default black (fallback)
	if color == "Red":
		rect_color = Color(1, 0, 0, 1)
	elif color == "Blue":
		rect_color = Color(0, 0, 1, 1)
	elif color == "Yellow":
		rect_color = Color(1, 1, 0, 1)
	$ColorRect.color = rect_color
	popup.text = "Use W Key to select " + color + " archetype"
	popup.visible = false
	popup.position = Vector2(-125, -125)  # Position above the box; adjust as needed (e.g., -50 for 50px above)
	add_child(popup)

func _on_body_entered(body):
	if body.name == "Player":
		body._on_interactable_entered(self)
		popup.visible = true
		if Input.is_action_just_pressed("move_up"):
			body.set_archetype(color)
			print("Selected color: ", color)

func _on_body_exited(body):
	if body.name == "Player":
		body._on_interactable_exited(self)
		popup.visible = false
