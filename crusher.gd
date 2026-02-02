extends Node2D

## Crusher hazard that moves back and forth, crushing the player

@export var crusher_size: Vector2 = Vector2(100, 40)  ## Size of the crusher platform
@export var move_direction: Vector2 = Vector2.DOWN  ## Direction of movement (UP, DOWN, LEFT, RIGHT)
@export var move_distance: float = 200.0  ## Total distance to move
@export var move_speed: float = 150.0  ## Speed of movement (pixels per second)
@export var pause_at_start: float = 1.5  ## Time to pause at start position (seconds)
@export var pause_at_end: float = 1.0  ## Time to pause at end position (seconds)
@export var warning_time: float = 0.8  ## Warning time before moving (seconds)
@export var damage_cooldown: float = 0.5  ## Time between damage hits (seconds)

enum CrusherState { PAUSED_START, WARNING, MOVING_FORWARD, PAUSED_END, MOVING_BACK }
var current_state: CrusherState = CrusherState.PAUSED_START
var state_timer: float = 0.0
var start_position: Vector2 = Vector2.ZERO
var end_position: Vector2 = Vector2.ZERO
var current_position: Vector2 = Vector2.ZERO

@onready var crusher_body: AnimatableBody2D = $CrusherBody
@onready var crusher_sprite: Sprite2D = $CrusherBody/CrusherSprite
@onready var crusher_visual: ColorRect = $CrusherBody/CrusherVisual
@onready var crusher_collision: CollisionShape2D = $CrusherBody/CollisionShape
@onready var damage_area: Area2D = $CrusherBody/DamageArea
@onready var damage_collision: CollisionShape2D = $CrusherBody/DamageArea/DamageCollision
@onready var warning_particles: Node2D = $CrusherBody/WarningParticles

var damage_cooldown_timer: float = 0.0
var player_in_area: bool = false
var player_ref: Node2D = null

func _ready() -> void:
	# Normalize movement direction
	move_direction = move_direction.normalized()
	
	# Calculate positions
	start_position = position
	end_position = position + move_direction * move_distance
	current_position = start_position
	
	# Setup all components
	_setup_crusher_sprite()
	_setup_crusher_visual()
	_setup_collision_shapes()
	
	# Connect damage area signals
	damage_area.body_entered.connect(_on_body_entered)
	damage_area.body_exited.connect(_on_body_exited)
	
	# Start in paused state
	current_state = CrusherState.PAUSED_START
	state_timer = pause_at_start

func _setup_crusher_sprite() -> void:
	"""Setup placeholder sprite for crusher."""
	# Create textured image
	var img_width = int(crusher_size.x)
	var img_height = int(crusher_size.y)
	var image = Image.create(img_width, img_height, false, Image.FORMAT_RGBA8)
	
	# Fill with hazard stripes
	for x in range(img_width):
		for y in range(img_height):
			# Create diagonal stripe pattern
			var stripe_pos = (x + y) % 20
			if stripe_pos < 10:
				image.set_pixel(x, y, Color(1.0, 0.85, 0.0))  # Yellow
			else:
				image.set_pixel(x, y, Color(0.15, 0.15, 0.15))  # Dark gray
	
	var texture = ImageTexture.create_from_image(image)
	crusher_sprite.texture = texture
	crusher_sprite.centered = true

func _setup_crusher_visual() -> void:
	"""Setup shader visual for crusher (currently hidden, using sprite instead)."""
	# Load and apply shader
	var shader_material = ShaderMaterial.new()
	shader_material.shader = load("res://crusher_shader.gdshader")
	shader_material.set_shader_parameter("stripe_color_1", Color(1.0, 0.85, 0.0, 1.0))  # Yellow
	shader_material.set_shader_parameter("stripe_color_2", Color(0.15, 0.15, 0.15, 1.0))  # Dark gray
	shader_material.set_shader_parameter("stripe_width", 0.12)
	shader_material.set_shader_parameter("stripe_angle", -45.0)
	shader_material.set_shader_parameter("pulse_speed", 3.0)
	shader_material.set_shader_parameter("pulse_intensity", 0.25)
	
	crusher_visual.material = shader_material
	crusher_visual.size = crusher_size
	crusher_visual.position = -crusher_size / 2.0

func _setup_collision_shapes() -> void:
	"""Setup collision shapes for body and damage area."""
	# Body collision
	var body_shape = crusher_collision.shape as RectangleShape2D
	if body_shape:
		body_shape.size = crusher_size
	
	# Damage collision (below crusher)
	var damage_shape = damage_collision.shape as RectangleShape2D
	if damage_shape:
		damage_shape.size = Vector2(crusher_size.x, 20.0)
	damage_collision.position = Vector2(0, crusher_size.y / 2.0 + 10.0)

func _physics_process(delta: float) -> void:
	state_timer += delta
	
	# Update damage cooldown
	if damage_cooldown_timer > 0:
		damage_cooldown_timer -= delta
	
	# Check for player damage
	if player_in_area and player_ref and is_instance_valid(player_ref) and damage_cooldown_timer <= 0:
		if current_state == CrusherState.MOVING_FORWARD or current_state == CrusherState.MOVING_BACK:
			_damage_player()
			damage_cooldown_timer = damage_cooldown
	
	match current_state:
		CrusherState.PAUSED_START:
			if state_timer >= pause_at_start:
				_enter_warning_state()
		
		CrusherState.WARNING:
			# Flash warning indicators
			var flash = int(state_timer / 0.1) % 2 == 0
			warning_particles.visible = flash
			
			if state_timer >= warning_time:
				_enter_moving_forward_state()
		
		CrusherState.MOVING_FORWARD:
			# Move towards end position
			var distance_to_move = move_speed * delta
			var direction_to_end = (end_position - current_position).normalized()
			current_position += direction_to_end * distance_to_move
			
			# Check if reached end
			if current_position.distance_to(end_position) < 5.0:
				current_position = end_position
				_enter_paused_end_state()
			
			crusher_body.position = current_position - position
		
		CrusherState.PAUSED_END:
			if state_timer >= pause_at_end:
				_enter_moving_back_state()
		
		CrusherState.MOVING_BACK:
			# Move back to start position
			var distance_to_move = move_speed * delta
			var direction_to_start = (start_position - current_position).normalized()
			current_position += direction_to_start * distance_to_move
			
			# Check if reached start
			if current_position.distance_to(start_position) < 5.0:
				current_position = start_position
				_enter_paused_start_state()
			
			crusher_body.position = current_position - position

func _enter_warning_state() -> void:
	current_state = CrusherState.WARNING
	state_timer = 0.0
	warning_particles.visible = true

func _enter_moving_forward_state() -> void:
	current_state = CrusherState.MOVING_FORWARD
	state_timer = 0.0
	warning_particles.visible = false

func _enter_paused_end_state() -> void:
	current_state = CrusherState.PAUSED_END
	state_timer = 0.0

func _enter_moving_back_state() -> void:
	current_state = CrusherState.MOVING_BACK
	state_timer = 0.0

func _enter_paused_start_state() -> void:
	current_state = CrusherState.PAUSED_START
	state_timer = 0.0

func _on_body_entered(body: Node2D) -> void:
	"""Called when a body enters the crusher area."""
	if body.is_in_group("player"):
		player_in_area = true
		player_ref = body
		
		# Immediate damage if moving
		if (current_state == CrusherState.MOVING_FORWARD or current_state == CrusherState.MOVING_BACK) and damage_cooldown_timer <= 0:
			_damage_player()
			damage_cooldown_timer = damage_cooldown

func _on_body_exited(body: Node2D) -> void:
	"""Called when a body exits the crusher area."""
	if body.is_in_group("player"):
		player_in_area = false
		player_ref = null

func _damage_player() -> void:
	"""Apply hitstun to the player."""
	if player_ref and is_instance_valid(player_ref):
		if player_ref.has_method("_on_enemy_touched"):
			player_ref._on_enemy_touched(null)
