extends Node

@onready var cam: PhantomCamera2D = get_parent()  # MainFollowCam
@onready var player: CharacterBody2D = cam.follow_target  # Your Player

@export var bias_distance: float = 60.0  # ±3% on stop (tune 40-80)
@export var damp_speed: float = 6.0  # Smooth delay (higher=snappier)
@export var stopped_threshold: float = 10.0  # Lower for true stop (velocity <10 = bias; tune 5-20)

var current_bias: float = 0.0

func _process(delta: float) -> void:
	if not player: return

	var target_bias: float = 0.0  # Center during movement
	if abs(player.velocity.x) < stopped_threshold:
		# Bias on facing when idle (uncomment next to flip sign if "more behind")
		target_bias = player.last_direction * bias_distance
		# target_bias = - player.last_direction * bias_distance  # Test flip

	# Lerp for smooth delay
	current_bias = lerp(current_bias, target_bias, clamp(damp_speed * delta, 0.0, 1.0))
	
	# Set Phantom's follow_offset (safe, direct—overrides deadzone for bias)
	cam.follow_offset.x = current_bias
	# Debug: Print every frame (console shows velocity/target—share during test)
	#print("Vel.x: ", player.velocity.x, " | Threshold: ", stopped_threshold, " | Bias: ", current_bias, " (Target: ", target_bias, ") | Facing: ", player.last_direction)

# Reset on start
func _ready():
	cam.follow_offset = Vector2(0, 0)  # Clean base
	#print("Bias ready—threshold: ", stopped_threshold, " | Distance: ", bias_distance)
