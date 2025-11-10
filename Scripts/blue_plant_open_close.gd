extends AnimatedSprite2D

func _ready():
	# Ensure separate animations ("open" and "close") are used
	sprite_frames.set_animation_loop("open", false)
	sprite_frames.set_animation_loop("close", false)
	
	# Randomize animation speed (0.5x to 1.5x normal)
	speed_scale = randf_range(0.5, 1.5)
	
	# Start with random frame or animation
	if randf() < 0.5:
		play("open")
	else:
		play("close")
		
	# Random delay before starting
	await get_tree().create_timer(randf_range(0.0, 2.0)).timeout
	play_animation_with_random_delay()

func play_animation_with_random_delay():
	while true:
		# Play open, wait random duration
		play("open")
		await animation_finished
		await get_tree().create_timer(randf_range(0.5, 2.0)).timeout
		
		# Play close, wait random duration
		play("close", -1)  # Reverse for closing
		await animation_finished
		await get_tree().create_timer(randf_range(0.5, 2.0)).timeout
