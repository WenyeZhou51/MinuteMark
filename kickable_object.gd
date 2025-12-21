extends Area2D

# ====================================
# KICKABLE OBJECT
# ====================================
# An object that can be kicked by the player
# Flies in a straight line until hitting a wall or enemy
# Turns into physics object on collision before disappearing

# CONFIGURATION
@export_group("Kick Properties")
@export var kick_speed: float = 2000.0  ## Speed when kicked
@export var rotation_speed_min: float = -10.0  ## Minimum rotation speed when kicked
@export var rotation_speed_max: float = 10.0  ## Maximum rotation speed when kicked

@export_group("Collision Response")
@export var physics_duration: float = 0.5  ## Time as physics object before despawning
@export var bounce_damping: float = 0.4  ## Velocity retention after bounce (0.0-1.0)
@export var gravity_strength: float = 2000.0  ## Gravity applied as physics object

@export_group("Detection")
@export var object_size: Vector2 = Vector2(40, 40)  ## Size of the object for visuals

# Internal state
var is_kicked: bool = false
var kick_velocity: Vector2 = Vector2.ZERO
var rotation_speed: float = 0.0
var has_collided: bool = false
var physics_timer: float = 0.0
var raycast: RayCast2D = null

# Visual references
@onready var visual: Polygon2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	# Setup collision layers
	# Layer 6 (value 32) for kickable objects
	collision_layer = 32
	# Mask: Layer 1 (walls/platforms), Layer 3 (enemies)
	collision_mask = 5  # Binary: 101 = layers 1 and 3
	
	# Add to group for detection
	add_to_group("kickable_objects")
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Create raycast for collision detection while flying
	raycast = RayCast2D.new()
	raycast.enabled = false
	raycast.collide_with_areas = true
	raycast.collide_with_bodies = true
	raycast.exclude_parent = true
	add_child(raycast)
	
	# Set raycast collision mask: Layer 1 (walls) and Layer 3 (enemies)
	raycast.set_collision_mask_value(1, true)  # Walls/platforms
	raycast.set_collision_mask_value(3, true)  # Enemies
	
	# Update visual size
	_update_visual()


func _update_visual() -> void:
	"""Update visual polygon to match object size."""
	if visual:
		var half_size = object_size / 2.0
		visual.polygon = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y)
		])


func _physics_process(delta: float) -> void:
	if is_kicked and not has_collided:
		# Flying in straight line - check for collisions ahead
		raycast.target_position = kick_velocity.normalized() * kick_velocity.length() * delta * 1.5
		raycast.force_raycast_update()
		
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			_handle_collision(collider)
		else:
			# Keep flying in straight line
			global_position += kick_velocity * delta
			rotation += rotation_speed * delta
	
	elif has_collided:
		# Physics object behavior - apply gravity and slow down
		physics_timer += delta
		
		# Apply gravity
		kick_velocity.y += gravity_strength * delta
		
		# Move
		global_position += kick_velocity * delta
		rotation += rotation_speed * delta
		
		# Fade out
		var fade_progress = physics_timer / physics_duration
		modulate.a = 1.0 - fade_progress
		
		# Despawn after duration
		if physics_timer >= physics_duration:
			queue_free()


func kick(direction: Vector2, speed: float = 0.0) -> void:
	"""Called when player kicks this object - send flying in straight line."""
	if is_kicked:
		return  # Already kicked
	
	is_kicked = true
	
	# Use provided speed or default
	var final_speed = speed if speed > 0 else kick_speed
	kick_velocity = direction.normalized() * final_speed
	
	# Random rotation
	rotation_speed = randf_range(rotation_speed_min, rotation_speed_max)
	
	# Enable raycast for collision detection
	raycast.enabled = true
	
	# Disable collision detection with player (so it doesn't hit them)
	set_collision_mask_value(2, false)  # Layer 2 is player
	
	# Visual feedback - tint red
	modulate = Color(1.5, 0.5, 0.5)
	
	# print("[KICKABLE] Kicked with speed: ", final_speed, " direction: ", direction)


func _handle_collision(collider: Node) -> void:
	"""Handle collision with wall or enemy."""
	if has_collided:
		return  # Already collided
	
	# print("[KICKABLE] Collision detected with: ", collider.name if collider else "null")
	
	# Check if collider is an enemy
	if collider and (collider.is_in_group("enemies") or collider.is_in_group("enemy")):
		_collide_with_enemy(collider)
	else:
		# Hit a wall or platform
		_collide_with_wall()


func _collide_with_enemy(enemy: Node) -> void:
	"""Both object and enemy become physics objects for 0.5s then disappear."""
	# print("[KICKABLE] Hit enemy! Both becoming physics objects")
	
	# Make enemy also become physics object
	if enemy.has_method("become_physics_object"):
		enemy.become_physics_object(kick_velocity.normalized(), kick_velocity.length())
	elif enemy.has_method("kick"):
		# Fallback: use existing kick method
		enemy.kick(kick_velocity.normalized(), kick_velocity.length())
	
	# Turn self into physics object
	_become_physics_object()


func _collide_with_wall() -> void:
	"""Hit a wall - become physics object for 0.5s then disappear."""
		# print("[KICKABLE] Hit wall! Becoming physics object")
	_become_physics_object()


func _become_physics_object() -> void:
	"""Convert to physics object behavior - bounce and fall with gravity."""
	has_collided = true
	physics_timer = 0.0
	raycast.enabled = false
	
	# Reduce velocity (bounce damping)
	kick_velocity *= bounce_damping
	
	# Add some randomness to bounce direction
	var bounce_angle = randf_range(-0.3, 0.3)
	kick_velocity = kick_velocity.rotated(bounce_angle)


func _on_body_entered(body: Node2D) -> void:
	"""Handle collision with CharacterBody2D (walls, platforms, player)."""
	if is_kicked and not has_collided:
		# Don't collide with player
		if body.is_in_group("player"):
			return
		
		_handle_collision(body)


func _on_area_entered(area: Area2D) -> void:
	"""Handle collision with Area2D (enemies)."""
	if is_kicked and not has_collided:
		_handle_collision(area)


func can_be_kicked() -> bool:
	"""Check if this object can currently be kicked."""
	return not is_kicked

