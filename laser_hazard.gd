extends Area2D

## A laser beam hazard that damages/hitstuns the player on contact

@export var laser_length: float = 500.0  ## Length of the laser beam
@export var laser_width: float = 30.0  ## Width of the laser beam
@export var laser_direction: Vector2 = Vector2.RIGHT  ## Direction the laser points
@export var damage_cooldown: float = 1.0  ## Time between damage hits (seconds)

@onready var laser_visual: ColorRect = $LaserVisual
@onready var laser_particles: CPUParticles2D = $LaserParticles
@onready var laser_end_particles: CPUParticles2D = $LaserEndParticles
@onready var emitter_sprite: Sprite2D = $EmitterSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape

var damage_cooldown_timer: float = 0.0
var player_in_area: bool = false
var player_ref: Node2D = null

func _ready() -> void:
	# Normalize laser direction
	laser_direction = laser_direction.normalized()
	
	# Setup all visual elements
	_setup_emitter_sprite()
	_setup_laser_visual()
	_setup_laser_particles()
	_setup_end_particles()
	_setup_collision_shape()
	
	# Connect area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _setup_emitter_sprite() -> void:
	"""Setup sprite for the laser emitter."""
	# Create simple box texture as placeholder
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	
	# Fill with dark gray and red accents
	for x in range(32):
		for y in range(32):
			if x < 4 or x >= 28 or y < 4 or y >= 28:
				image.set_pixel(x, y, Color(0.2, 0.2, 0.2))  # Dark border
			elif x >= 12 and x < 20 and y >= 12 and y < 20:
				image.set_pixel(x, y, Color(1.0, 0.2, 0.0))  # Red center
			else:
				image.set_pixel(x, y, Color(0.3, 0.3, 0.3))  # Gray body
	
	var texture = ImageTexture.create_from_image(image)
	emitter_sprite.texture = texture
	
	# Rotate to match laser direction
	emitter_sprite.rotation = laser_direction.angle()

func _setup_laser_visual() -> void:
	"""Setup the visual representation of the laser beam."""
	# Update size
	laser_visual.size = Vector2(laser_length, laser_width)
	
	# Position and rotate the laser
	var angle = laser_direction.angle()
	laser_visual.rotation = angle
	laser_visual.position = Vector2(-laser_width/2, -laser_width/2)
	laser_visual.pivot_offset = Vector2(0, laser_width/2)
	
	laser_visual.z_index = -1

func _setup_laser_particles() -> void:
	"""Setup particle effects along the laser beam."""
	# Update emission area
	laser_particles.emission_rect_extents = Vector2(laser_length / 2.0, laser_width / 4.0)
	
	# Move particles along the beam
	var particle_direction = laser_direction
	laser_particles.direction = particle_direction
	
	# Position at center of beam
	laser_particles.position = laser_direction * (laser_length / 2.0)

func _setup_end_particles() -> void:
	"""Setup particle effects at the end of the laser."""
	# Position at end of beam
	laser_end_particles.position = laser_direction * laser_length

func _setup_collision_shape() -> void:
	"""Setup collision shape for the laser beam."""
	var shape = collision_shape.shape as RectangleShape2D
	if shape:
		shape.size = Vector2(laser_length, laser_width * 0.6)
	
	# Position and rotate to match laser direction
	var angle = laser_direction.angle()
	collision_shape.rotation = angle
	collision_shape.position = laser_direction * (laser_length / 2.0)

func _physics_process(delta: float) -> void:
	# Update damage cooldown timer
	if damage_cooldown_timer > 0:
		damage_cooldown_timer -= delta
	
	# Check if player is in contact and cooldown expired
	if player_in_area and player_ref and is_instance_valid(player_ref) and damage_cooldown_timer <= 0:
		_damage_player()
		damage_cooldown_timer = damage_cooldown

func _on_body_entered(body: Node2D) -> void:
	"""Called when a body enters the laser."""
	if body.is_in_group("player"):
		player_in_area = true
		player_ref = body
		
		# Immediate damage on first contact
		if damage_cooldown_timer <= 0:
			_damage_player()
			damage_cooldown_timer = damage_cooldown

func _on_body_exited(body: Node2D) -> void:
	"""Called when a body exits the laser."""
	if body.is_in_group("player"):
		player_in_area = false
		player_ref = null

func _damage_player() -> void:
	"""Apply hitstun to the player."""
	if player_ref and is_instance_valid(player_ref):
		if player_ref.has_method("_on_enemy_touched"):
			player_ref._on_enemy_touched(null)
