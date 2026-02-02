extends Area2D

## Static spike hazard that damages the player on contact

@export var spike_direction: Vector2 = Vector2.UP  ## Direction spikes point (for sprite orientation)
@export var spike_size: Vector2 = Vector2(60, 80)  ## Size of the spike area
@export var damage_cooldown: float = 1.0  ## Time between damage hits (seconds)

@onready var spike_sprite: Sprite2D = $SpikeSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape

var damage_cooldown_timer: float = 0.0
var player_in_area: bool = false
var player_ref: Node2D = null

func _ready() -> void:
	# Setup sprite and collision
	_setup_spike_sprite()
	_setup_collision_shape()
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _setup_spike_sprite() -> void:
	"""Setup placeholder sprite for spikes."""
	# Create simple triangle texture as placeholder
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Draw spike triangles
	for x in range(64):
		for y in range(64):
			# Create jagged spike pattern
			var normalized_x = float(x) / 64.0
			var spike_pattern = abs(fmod(normalized_x * 4.0, 1.0) - 0.5) * 2.0  # 4 spikes
			var spike_height = 1.0 - spike_pattern
			var normalized_y = float(y) / 64.0
			
			if spike_direction.y < 0:  # Pointing up
				if normalized_y > spike_height:
					image.set_pixel(x, y, Color(0.4, 0.4, 0.4))  # Dark gray
			elif spike_direction.y > 0:  # Pointing down
				if normalized_y < (1.0 - spike_height):
					image.set_pixel(x, y, Color(0.4, 0.4, 0.4))
			elif spike_direction.x > 0:  # Pointing right
				if normalized_x < (1.0 - spike_height):
					image.set_pixel(x, y, Color(0.4, 0.4, 0.4))
			elif spike_direction.x < 0:  # Pointing left
				if normalized_x > spike_height:
					image.set_pixel(x, y, Color(0.4, 0.4, 0.4))
	
	var texture = ImageTexture.create_from_image(image)
	spike_sprite.texture = texture
	spike_sprite.scale = spike_size / 64.0

func _setup_collision_shape() -> void:
	"""Setup collision shape for the spikes."""
	var shape = collision_shape.shape as RectangleShape2D
	if shape:
		shape.size = spike_size

func _physics_process(delta: float) -> void:
	# Update damage cooldown timer
	if damage_cooldown_timer > 0:
		damage_cooldown_timer -= delta
	
	# Check if player is in contact and cooldown expired
	if player_in_area and player_ref and is_instance_valid(player_ref) and damage_cooldown_timer <= 0:
		_damage_player()
		damage_cooldown_timer = damage_cooldown

func _on_body_entered(body: Node2D) -> void:
	"""Called when a body enters the spike area."""
	if body.is_in_group("player"):
		player_in_area = true
		player_ref = body
		
		# Immediate damage on first contact
		if damage_cooldown_timer <= 0:
			_damage_player()
			damage_cooldown_timer = damage_cooldown

func _on_body_exited(body: Node2D) -> void:
	"""Called when a body exits the spike area."""
	if body.is_in_group("player"):
		player_in_area = false
		player_ref = null

func _damage_player() -> void:
	"""Apply hitstun to the player."""
	if player_ref and is_instance_valid(player_ref):
		if player_ref.has_method("_on_enemy_touched"):
			player_ref._on_enemy_touched(null)
