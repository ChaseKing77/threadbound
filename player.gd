extends CharacterBody2D

# ===============================
# NODES
# ===============================
@onready var player_animation: AnimatedSprite2D = $"Player Animation"
@onready var camera = get_node_or_null("../Camera Master/Camera2D/PhantomCameraHost2D/MainFollowCam")
@onready var glow_sprite: Sprite2D = $GlowSprite

# ===============================
# TUNABLES
# ===============================
@export var speed: float = 500.0
@export var air_control_mult: float = 0.75
@export var jump_force: float = 550.0
@export var gravity: float = 1600.0
@export var gravity_jump_hold: float = 500.0
@export var max_fall_speed: float = 1000.0
@export var coyote_time: float = 0.12
@export var dash_speed: float = 900.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@export var look_offset: float = 60.0
@export var look_speed: float = 10.0
@export var hold_duration: float = 1.0

# ===============================
# STATE
# ===============================
var is_dashing = false
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var coyote_timer = 0.0
var last_direction: int = 1
var is_jumping: bool = false
var is_near_interactable = false
var current_selector = null
var current_look_offset_y: float = 0.0
var hold_timer: float = 0.0

# Archetype
var archetype = null

# --------------------------------------------------------------
# MAIN LOOP
# --------------------------------------------------------------
func _physics_process(delta: float) -> void:
	# ---- DASH COOLDOWN ----
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	# ---- GRAVITY + COYOTE ----
	var holding_jump = Input.is_action_pressed("Jump")
	if not is_on_floor():
		if velocity.y < 0 and holding_jump:
			velocity.y += gravity_jump_hold * delta
		else:
			velocity.y += gravity * delta
			if is_jumping and not holding_jump:
				velocity.y += (gravity - gravity_jump_hold) * delta * 2.0
		if velocity.y > max_fall_speed:
			velocity.y = max_fall_speed
		coyote_timer -= delta
	else:
		coyote_timer = coyote_time
		is_jumping = false

	# ---- JUMP ----
	if Input.is_action_just_pressed("Jump") and (is_on_floor() or coyote_timer > 0.0):
		velocity.y = -jump_force
		is_jumping = true
		coyote_timer = 0.0

	# ---- DASH ----
	if Input.is_action_just_pressed("Dash") and not is_dashing and dash_cooldown_timer <= 0 and not archetype:
		is_dashing = true
		dash_timer = dash_duration
		velocity.x = last_direction * dash_speed
		velocity.y = 0
		dash_cooldown_timer = dash_cooldown

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false

	# ---- HORIZONTAL INPUT ----
	var horizontal_input = Input.get_axis("move_left", "move_right")
	if horizontal_input != 0:
		last_direction = sign(horizontal_input)

	# ---- BASE MOVEMENT — ALWAYS RUNS ----
	var control = 1.0 if is_on_floor() else air_control_mult
	velocity.x = speed * horizontal_input * control

	# ---- DASH OVERRIDE ----
	if is_dashing:
		velocity.x = last_direction * dash_speed

	# ---- LOOK / INTERACT ----
	if camera:
		var cur = camera.follow_offset if "follow_offset" in camera else Vector2.ZERO
		var target_y = 0.0

		if Input.is_action_pressed("move_up") and not is_dashing:
			hold_timer += delta
			if hold_timer >= hold_duration and not is_near_interactable:
				target_y = -look_offset
			elif is_near_interactable and Input.is_action_just_pressed("move_up") and current_selector:
				set_archetype(current_selector.color)
				hold_timer = 0.0
		elif Input.is_action_pressed("move_down") and not is_dashing:
			hold_timer += delta
			if hold_timer >= hold_duration:
				target_y = look_offset
		else:
			hold_timer = 0.0

		current_look_offset_y = lerp(current_look_offset_y, target_y, delta * look_speed)
		camera.set_follow_offset(Vector2(cur.x, current_look_offset_y))
# Inside _physics_process(delta):

	# ---- ARCHETYPE – RUNS BEFORE move_and_slide() ----
	if archetype and archetype.has_method("process_mechanics"):
		archetype.process_mechanics(delta, self)

	# ---- FINAL PHYSICS MOVE ----
	move_and_slide()

	# ---- ANIMATIONS ----
	update_animations(horizontal_input)

# --------------------------------------------------------------
# REST OF CODE
# --------------------------------------------------------------
func _process(_delta: float) -> void:
	if glow_sprite and player_animation and player_animation.sprite_frames:
		var tex = player_animation.sprite_frames.get_frame_texture(
			player_animation.animation, player_animation.frame)
		glow_sprite.texture = tex
		glow_sprite.flip_h = player_animation.flip_h
		glow_sprite.position = player_animation.position
		glow_sprite.scale = player_animation.scale

func update_animations(dir: float) -> void:
	if is_dashing and player_animation.sprite_frames.has_animation("Dash"):
		player_animation.play("Dash")
	elif not is_on_floor() and player_animation.sprite_frames.has_animation("Jump"):
		player_animation.play("Jump")
	elif dir != 0 and player_animation.sprite_frames.has_animation("Walk"):
		player_animation.play("Walk")
	elif player_animation.sprite_frames.has_animation("Idle"):
		player_animation.play("Idle")
	if velocity.x != 0:
		player_animation.flip_h = velocity.x < 0

func _on_interactable_entered(area: Area2D):
	is_near_interactable = true
	current_selector = area

func _on_interactable_exited(area: Area2D):
	is_near_interactable = false
	if current_selector == area:
		current_selector = null

func _ready():
	if glow_sprite and glow_sprite.material:
		glow_sprite.material.set_shader_parameter("glow_color", Color(0,0,0,0))
	for n in get_tree().get_nodes_in_group("selectors"):
		if n is Area2D:
			n.connect("body_entered", Callable(self, "_on_interactable_entered"))
			n.connect("body_exited", Callable(self, "_on_interactable_exited"))

# === CRITICAL CHANGE: NO init() CALL ===
func set_archetype(color: String):
	if archetype and archetype != self:
		archetype.queue_free()
	match color:
		"Red":
			archetype = preload("res://Scripts/RedArchetype.gd").new()
			glow_sprite.material.set_shader_parameter("glow_color", Color(1,0,0,1))
		"Blue":
			archetype = preload("res://Scripts/BlueArchetype.gd").new()
			glow_sprite.material.set_shader_parameter("glow_color", Color(0,0,1,1))
		"Yellow":
			archetype = preload("res://Scripts/YellowArchetype.gd").new()
			glow_sprite.material.set_shader_parameter("glow_color", Color(1,1,0,1))
	if archetype:
		add_child(archetype)  # _enter_tree() runs
