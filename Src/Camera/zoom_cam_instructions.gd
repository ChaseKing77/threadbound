extends Area2D

@onready var host = get_node("../..")  # Up to host (no type—fixes error)
@onready var main_cam = host.get_node("MainFollowCam")  # Your main cam
@onready var zoom_cam = get_parent()  # This ZoomCam

func _ready():
	print("Trigger ready. Host: ", host.name if host else "PATH ERROR - Check ../..")  # Debug path
	print("MainCam: ", main_cam.name if main_cam else "MAIN ERROR")
	print("ZoomCam: ", zoom_cam.name if zoom_cam else "ZOOM ERROR")

func _on_body_entered(body: Node2D):
	print("Entered! Body: ", body.name)  # Debug signal fire
	if body.name == "Player":  # Change to your Player name if different
		main_cam.priority = 0  # Deactivate main
		zoom_cam.priority = 20  # Activate zoom
		print("Swapped to ZoomCam!")

func _on_body_exited(body: Node2D):
	print("Exited! Body: ", body.name)  # Debug
	if body.name == "Player":
		main_cam.priority = 10  # Reactivate main
		zoom_cam.priority = 0  # Deactivate zoom
		print("Back to MainCam!")
