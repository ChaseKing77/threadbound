extends Area2D

@onready var host = get_node("../..")  # PhantomCameraHost (adjust if path off)

func _on_body_entered(body):
	if body.name == "Player":  # Or body is CharacterBody2D
		host.get_node("MainFollowCam").priority = 0  # Deactivate main
		host.get_node("ZoomCam").priority = 20  # Activate zoom

func _on_body_exited(body):
	if body.name == "Player":
		host.get_node("MainFollowCam").priority = 10  # Back to main
		host.get_node("ZoomCam").priority = 0
