extends CharacterBody2D

# ===============================
# NODES
# ===============================
@onready var player_animation: AnimatedSprite2D = $"Player Animation"
@onready var camera = get_node_or_null("../Camera Master/Camera2D/PhantomCameraHost2D/MainFollowCam")
@onready var glow_sprite: Sprite2D = $GlowSprite
@onready var ability_cooldown_timer: Timer = $AbilityCooldownTimer

# ===============================
# TUNABLES
# ===============================
@export var speed: float = 500.0
@export var air_control_mult: float = 0.75
@export var gravity: float = 1600.0
@export var max_fall_speed: float = 1000.0
@export var coyote_time: float = 0.12
@export var look_offset: float = 60.0
@export var look_speed: float = 10.0
@export var hold_duration: float = 1.0

# Glow configuration (shared across all archetypes)
@export var idle_glow_width: float = 1.2
@export var idle_glow_intensity: float = 0.35
@export var charge_glow_max_width: float = 4.0
@export var charge_glow_max_intensity: float = 1.2
@export var jump_force: float = 700.0

# ===============================
# STATE
# ===============================
# Dash state is now handled by archetypes (RedArchetype)
var coyote_timer = 0.0
var last_direction: int = 1
var is_near_interactable = false
var current_selector = null
var current_look_offset_y: float = 0.0
var hold_timer: float = 0.0
# Charge ratios for glow effects (set by archetypes)
var jump_charge_ratio: float = 0.0
var dash_charge_ratio: float = 0.0
var base_glow_color: Color = ArchetypeConstants.RED_COLOR
var base_glow_width: float = 1.2
var base_glow_intensity: float = 0.35
var default_glow_color: Color = ArchetypeConstants.RED_COLOR
var default_glow_width: float = 1.2
var default_glow_intensity: float = 0.35
var current_charge_glow_color: Color = ArchetypeConstants.RED_COLOR

# Archetype - typed as BaseArchetype
var archetype: BaseArchetype = null

# --------------------------------------------------------------
# MAIN LOOP
# --------------------------------------------------------------
func _physics_process(delta: float) -> void:
	# ---- GRAVITY + COYOTE ----
	if not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y > max_fall_speed:
			velocity.y = max_fall_speed
		coyote_timer -= delta
	else:
		coyote_timer = coyote_time

	# ---- ARCHETYPE ACTIONS ----
	if archetype:
		# Primary action (Jump) - handle PRESSED and RELEASED independently
		if Input.is_action_just_pressed("Jump"):
			archetype.handle_primary_action(BaseArchetype.ActionState.PRESSED, delta)
		if Input.is_action_just_released("Jump"):
			archetype.handle_primary_action(BaseArchetype.ActionState.RELEASED, delta)
		# HOLDING is called every frame while button is held (but not on press/release frames)
		if Input.is_action_pressed("Jump") and not Input.is_action_just_pressed("Jump") and not Input.is_action_just_released("Jump"):
			archetype.handle_primary_action(BaseArchetype.ActionState.HOLDING, delta)
		
		# Secondary action (Dash) - handle PRESSED and RELEASED independently
		if Input.is_action_just_pressed("Dash"):
			archetype.handle_secondary_action(BaseArchetype.ActionState.PRESSED, delta)
		if Input.is_action_just_released("Dash"):
			archetype.handle_secondary_action(BaseArchetype.ActionState.RELEASED, delta)
		# HOLDING is called every frame while button is held (but not on press/release frames)
		if Input.is_action_pressed("Dash") and not Input.is_action_just_pressed("Dash") and not Input.is_action_just_released("Dash"):
			archetype.handle_secondary_action(BaseArchetype.ActionState.HOLDING, delta)
		
		# Thread mechanic (called every frame)
		archetype.thread_mechanic(delta)

	# ---- HORIZONTAL INPUT ----
	var horizontal_input = Input.get_axis("move_left", "move_right")
	if horizontal_input != 0:
		last_direction = sign(horizontal_input)

	# ---- BASE MOVEMENT — ALWAYS RUNS ----
	var control = 1.0 if is_on_floor() else air_control_mult
	# Only apply base movement if archetype isn't controlling velocity (e.g., during dash)
	var archetype_controlling = false
	if archetype and "is_dashing" in archetype and archetype.is_dashing:
		archetype_controlling = true
	if not archetype_controlling:
		velocity.x = speed * horizontal_input * control

	# ---- ARCHETYPE SELECTION ----
	if is_near_interactable and current_selector and Input.is_action_just_pressed("move_up"):
		set_archetype(current_selector.color)
		if archetype and archetype.has_method("set_active"):
			archetype.set_active(true)

	# ---- LOOK / INTERACT ----
	if camera:
		var cur = camera.follow_offset if "follow_offset" in camera else Vector2.ZERO
		var target_y = 0.0

		if Input.is_action_pressed("move_up") and not (archetype and "is_dashing" in archetype and archetype.is_dashing):
			hold_timer += delta
			if hold_timer >= hold_duration and not is_near_interactable:
				target_y = -look_offset
		elif Input.is_action_pressed("move_down") and not (archetype and "is_dashing" in archetype and archetype.is_dashing):
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
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
	if glow_sprite and player_animation and player_animation.sprite_frames:
		var tex = player_animation.sprite_frames.get_frame_texture(
			player_animation.animation, player_animation.frame)
		glow_sprite.texture = tex
		glow_sprite.flip_h = player_animation.flip_h
		glow_sprite.position = player_animation.position
		glow_sprite.scale = player_animation.scale
	_apply_charge_glow()

# Jump charge logic is now handled by archetypes

func _apply_charge_glow() -> void:
	if not glow_sprite or not glow_sprite.material or not archetype:
		return
	var level = clamp(max(jump_charge_ratio, dash_charge_ratio), 0.0, 1.0)
	var mat: ShaderMaterial = glow_sprite.material
	var target_width = lerp(base_glow_width, charge_glow_max_width, level)
	var target_intensity = lerp(base_glow_intensity, charge_glow_max_intensity, level)
	mat.set_shader_parameter("glow_width", target_width)
	mat.set_shader_parameter("glow_intensity", target_intensity)
	if level > 0.01:
		mat.set_shader_parameter("glow_color", archetype.charge_glow_color)
	else:
		mat.set_shader_parameter("glow_color", base_glow_color)

func set_dash_charge_level(level: float) -> void:
	dash_charge_ratio = clamp(level, 0.0, 1.0)

func set_jump_charge_level(level: float) -> void:
	jump_charge_ratio = clamp(level, 0.0, 1.0)

## Start ability cooldown timer - called by archetypes
func start_ability_cooldown(duration: float) -> void:
	if ability_cooldown_timer:
		ability_cooldown_timer.wait_time = duration
		ability_cooldown_timer.start()

func _set_base_glow(color: Color, width: float, intensity: float) -> void:
	base_glow_color = color
	base_glow_width = width
	base_glow_intensity = intensity
	if glow_sprite and glow_sprite.material and max(jump_charge_ratio, dash_charge_ratio) <= 0.01:
		var mat: ShaderMaterial = glow_sprite.material
		mat.set_shader_parameter("glow_color", color)
		mat.set_shader_parameter("glow_width", width)
		mat.set_shader_parameter("glow_intensity", intensity)

func update_animations(dir: float) -> void:
	var is_dashing = archetype and "is_dashing" in archetype and archetype.is_dashing
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
	# Connect ability cooldown timer timeout signal
	if ability_cooldown_timer:
		ability_cooldown_timer.timeout.connect(_on_ability_cooldown_timeout)
	# Set default archetype to Red
	set_archetype(ArchetypeConstants.RED)
	# Selectors now connect their own signals in their _ready() functions
	# No need to connect here - they call _on_interactable_entered(self) directly

func _on_ability_cooldown_timeout() -> void:
	# Call archetype callback when cooldown completes
	if archetype:
		archetype.on_ability_cooldown_complete()

# === CRITICAL CHANGE: NO init() CALL ===
func set_archetype(color: String):
	if archetype and archetype != self:
		archetype.queue_free()
	
	match color:
		ArchetypeConstants.RED:
			archetype = RedArchetype.new()
		ArchetypeConstants.BLUE:
			archetype = BlueArchetype.new()
		ArchetypeConstants.YELLOW:
			archetype = YellowArchetype.new()
		_:
			push_error("Unknown archetype color: %s" % color)
			return
	
	if archetype:
		add_child(archetype)  # _enter_tree() runs, which calls _initialize_archetype()
		# Set glow from archetype's color and player's glow configuration
		var archetype_color = ArchetypeConstants.get_color(color)
		_set_base_glow(archetype_color, idle_glow_width, idle_glow_intensity)
