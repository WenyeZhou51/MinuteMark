extends Area2D

# ====================================
# DOOR
# ====================================
# A door that can be kicked by the player
# Flies in a straight line when kicked, knocking down enemies it hits
# Similar to GunPoint door mechanics

# CONFIGURATION
@export_group("Kick Properties")
@export var kick_speed: float = 2000.0  ## Speed when kicked
@export var rotation_speed_min: float = -10.0  ## Minimum rotation speed when kicked
@export var rotation_speed_max: float = 10.0  ## Maximum rotation speed when kicked

@export_group("Door Properties")
@export var door_width: float = 80.0  ## Width of the door
@export var door_height: float = 120.0  ## Height of the door
@export var door_texture: Texture2D = null  ## Optional texture/image for the door
@export var backward_flight_distance: float = 5000.0  ## Distance to fly backward before stopping (very far to reach enemies off-screen)

@export_group("Collision Response")
@export var bounce_damping: float = 0.4  ## Velocity retention after bounce (0.0-1.0)
@export var gravity_strength: float = 2000.0  ## Gravity applied as physics object

# Internal state
var is_kicked: bool = false
var kick_velocity: Vector2 = Vector2.ZERO
var rotation_speed: float = 0.0
var has_collided: bool = false
var has_hit_enemy: bool = false  ## Track if door has already hit an enemy
var raycast: RayCast2D = null
var shapecast: ShapeCast2D = null
var flight_timer: float = 0.0
var despawn_timer: float = 0.0
var despawn_duration: float = 2.0  ## How long door lasts after hitting wall
const MAX_FLIGHT_TIME: float = 10.0  ## Max time to fly before timeout (enough to travel very far)
var initial_position: Vector2 = Vector2.ZERO  ## Store position when kicked
var distance_traveled: float = 0.0  ## Track distance traveled backward

# Visual references
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var blocking_body: StaticBody2D = $BlockingBody


func _ready() -> void:
	# Setup collision layers
	# Layer 6 (value 32) for kickable objects/doors
	collision_layer = 32
	# Mask: Layer 1 (walls/platforms), Layer 3 (enemies)
	collision_mask = 5  # Binary: 101 = layers 1 and 3
	
	# Add to group for detection (same as kickable_objects so player can kick it)
	add_to_group("kickable_objects")
	
	# Ensure Area2D is monitorable so player can detect it
	monitoring = true
	monitorable = true
	
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
	
	# Create shapecast for more robust high-speed collision detection
	shapecast = ShapeCast2D.new()
	shapecast.enabled = false
	shapecast.collide_with_areas = true
	shapecast.collide_with_bodies = true
	shapecast.exclude_parent = true
	
	# Use a rectangle shape matching door size
	var rect = RectangleShape2D.new()
	rect.size = Vector2(door_width, door_height)
	shapecast.shape = rect
	shapecast.max_results = 10  # Can hit multiple enemies
	add_child(shapecast)
	
	# Set shapecast collision mask
	shapecast.set_collision_mask_value(1, true)  # Walls/platforms
	shapecast.set_collision_mask_value(3, true)  # Enemies
	
	# Setup visual
	_update_visual()
	
	# Setup blocking body for player collision
	_setup_blocking_body()


func _update_visual() -> void:
	"""Update visual sprite and collision shape to match door size."""
	if sprite:
		# Set sprite scale to match door dimensions
		if door_texture:
			sprite.texture = door_texture
			# Scale texture to match door size
			if door_texture:
				var tex_size = door_texture.get_size()
				if tex_size.x > 0 and tex_size.y > 0:
					sprite.scale = Vector2(door_width / tex_size.x, door_height / tex_size.y)
		else:
			# Default: create a simple colored rectangle
			var image = Image.create(int(door_width), int(door_height), false, Image.FORMAT_RGBA8)
			image.fill(Color(0.6, 0.4, 0.2, 1.0))  # Brown door color
			var texture = ImageTexture.create_from_image(image)
			sprite.texture = texture
			sprite.scale = Vector2(1.0, 1.0)
	
	if collision_shape:
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(door_width, door_height)
		collision_shape.shape = rect_shape


func _setup_blocking_body() -> void:
	"""Setup the StaticBody2D that blocks player movement."""
	if blocking_body:
		# Set collision layer to block player (layer 1 = walls/platforms)
		# Player's collision_mask includes layer 1, so this will block them
		blocking_body.collision_layer = 1  # Layer 1 (walls/platforms)
		# Set collision mask to 0 (don't need to detect anything, just block)
		blocking_body.collision_mask = 0
		
		# Update the blocking body's collision shape
		var blocking_collision = blocking_body.get_node_or_null("CollisionShape2D")
		if blocking_collision:
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = Vector2(door_width, door_height)
			blocking_collision.shape = rect_shape


func _physics_process(delta: float) -> void:
	if not is_kicked:
		return
	
	if not has_collided:
		# Flying backward - check for collisions ahead
		flight_timer += delta
		
		# Check for timeout (didn't hit wall within max time)
		if flight_timer >= MAX_FLIGHT_TIME:
			_on_timeout()
			return
		
		# Check distance traveled
		var distance_from_start = global_position.distance_to(initial_position)
		
		# Calculate movement step
		var move_step = kick_velocity * delta
		
		# MOVE THE DOOR FIRST, then check for collisions
		# This prevents the door from detecting walls it's already touching
		global_position += move_step
		rotation += rotation_speed * delta
		distance_traveled = global_position.distance_to(initial_position)
		
		# Check for collisions using shapecast and raycast AFTER moving
		# Only check AHEAD in the movement direction, not at current position
		# This prevents detecting the platform the door is standing on
		var check_ahead_distance = max(move_step.length() * 1.5, 10.0)  # At least 10 pixels ahead
		var check_direction = move_step.normalized()
		shapecast.target_position = check_direction * check_ahead_distance
		shapecast.force_shapecast_update()
		
		raycast.target_position = check_direction * check_ahead_distance
		raycast.force_raycast_update()
		
		# Check for enemies FIRST (before walls) - use multiple detection methods
		# Only check if we haven't hit an enemy yet (knock only the first enemy)
		var hit_wall_shapecast = false  # Declare outside the if block
		if not has_hit_enemy:
			# Method 1: Check shapecast for enemies FIRST (prioritize enemies over walls)
			if shapecast.is_colliding():
				var collision_count = shapecast.get_collision_count()
				
				# FIRST: Check for enemies in shapecast
				var found_enemy = false
				for i in range(collision_count):
					var collider = shapecast.get_collider(i)
					if collider and (collider.is_in_group("enemies") or collider.is_in_group("enemy")):
						if not collider.is_destroyed:
							_collide_with_enemy(collider)
							found_enemy = true
							break  # Only knock the first enemy
				
				# THEN: Check for walls only if no enemy was found
				if not found_enemy and not has_hit_enemy:
					for i in range(collision_count):
						var collider = shapecast.get_collider(i)
						
						# Skip BlockingBody (it's part of the door itself)
						if collider and collider.name != "BlockingBody" and not (collider.is_in_group("enemies") or collider.is_in_group("enemy")):
							# Check if this collision is actually blocking horizontal movement
							# Get collision normal to see if it's blocking our movement direction
							var collision_normal = shapecast.get_collision_normal(i)
							var move_direction = kick_velocity.normalized()
							# If normal is pointing opposite to movement, it's blocking us
							var dot_product = collision_normal.dot(-move_direction)
							
							# Only collide if it's a VERTICAL wall (not a horizontal floor/ceiling)
							# Check if the collision normal is mostly horizontal (wall) vs vertical (floor/ceiling)
							var is_horizontal_surface = abs(collision_normal.y) > 0.7  # Floor or ceiling (normal pointing up/down)
							var is_vertical_wall = abs(collision_normal.x) > 0.7  # Wall (normal pointing left/right)
							
							# Only stop on vertical walls, not floors/ceilings
							# Also check that it's blocking our movement direction
							if is_vertical_wall and dot_product > 0.5:
								# It's a vertical wall blocking our horizontal movement
								hit_wall_shapecast = true
								_handle_collision(collider)
								break
		
		# Check for wall collisions via raycast (only if we haven't already hit an enemy)
		var hit_wall = hit_wall_shapecast  # Start with shapecast result
		if not has_hit_enemy and not hit_wall and raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider and collider.name != "BlockingBody" and not (collider.is_in_group("enemies") or collider.is_in_group("enemy")):
				# Check if it's a vertical wall, not a floor
				var collision_normal = raycast.get_collision_normal()
				var is_vertical_wall = abs(collision_normal.x) > 0.7
				
				if is_vertical_wall:
					hit_wall = true
					_handle_collision(collider)
		
		# If we hit a wall, undo the movement
		if hit_wall or has_collided:
			global_position -= move_step  # Undo the movement
			rotation -= rotation_speed * delta
		else:
			
			# Check for overlapping enemies AFTER moving (Area2D overlap detection)
			# This catches enemies that other methods might have missed
			if not has_hit_enemy:
				# Force update overlapping areas
				var overlapping_areas = get_overlapping_areas()
				for area in overlapping_areas:
					if area and is_instance_valid(area):
						if (area.is_in_group("enemies") or area.is_in_group("enemy")) and not area.is_destroyed:
							_collide_with_enemy(area)
							break  # Only knock the first enemy
				
				# Also check overlapping bodies (in case enemy is a CharacterBody2D)
				var overlapping_bodies = get_overlapping_bodies()
				for body in overlapping_bodies:
					if body and is_instance_valid(body):
						if (body.is_in_group("enemies") or body.is_in_group("enemy")) and not body.is_destroyed:
							_collide_with_enemy(body)
							break  # Only knock the first enemy
			
			# Don't stop based on distance - only stop when hitting something
			# The door should fly until it hits an enemy or wall, or times out
	
	elif has_collided:
		# Falling with gravity after collision
		# Only apply vertical gravity, stop horizontal movement
		# Stop horizontal movement when hitting wall
		kick_velocity.x = 0.0
		
		# Apply gravity only vertically
		kick_velocity.y += gravity_strength * delta
		global_position += kick_velocity * delta
		rotation += rotation_speed * delta
		
		# Fade out
		despawn_timer += delta
		var fade_progress = despawn_timer / despawn_duration
		modulate.a = 1.0 - fade_progress
		
		if despawn_timer >= despawn_duration:
			queue_free()


func kick(direction: Vector2, speed: float = 0.0) -> void:
	"""Called when player kicks this door - send flying directly backward (opposite of kick direction)."""
	if is_kicked:
		return  # Already kicked
	
	is_kicked = true
	
	# Store initial position for distance tracking
	initial_position = global_position
	distance_traveled = 0.0
	
	# Door flies directly backward - in the same direction as the kick (away from player)
	# This ensures it flies in a straight line backward
	var backward_direction = direction.normalized()
	
	# Use provided speed or default
	var final_speed = speed if speed > 0 else kick_speed
	kick_velocity = backward_direction * final_speed
	
	# Random rotation
	rotation_speed = randf_range(rotation_speed_min, rotation_speed_max)
	
	# Enable raycast and shapecast for collision detection
	raycast.enabled = true
	shapecast.enabled = true
	
	# Ensure Area2D monitoring is enabled to detect enemies
	monitoring = true
	monitorable = true
	
	# Ensure collision mask includes enemies (layer 3) and walls (layer 1)
	set_collision_mask_value(1, true)  # Walls/platforms
	set_collision_mask_value(3, true)  # Enemies
	# Disable collision detection with player (so it doesn't hit them)
	set_collision_mask_value(2, false)  # Layer 2 is player
	
	# Make sure collision shape is enabled
	if collision_shape:
		collision_shape.disabled = false
	
	# Disable blocking body so player can pass through
	if blocking_body:
		blocking_body.set_deferred("collision_layer", 0)  # Disable collision
		# Also disable the collision shape
		var blocking_collision = blocking_body.get_node_or_null("CollisionShape2D")
		if blocking_collision:
			blocking_collision.set_deferred("disabled", true)
	
	# Visual feedback - slight tint
	modulate = Color(1.2, 1.0, 0.9)


func _handle_collision(collider: Node) -> void:
	"""Handle collision with wall or enemy."""
	if has_collided:
		return  # Already collided
	
	# Check if collider is an enemy - only process if we haven't hit an enemy yet
	if not has_hit_enemy and collider and (collider.is_in_group("enemies") or collider.is_in_group("enemy")):
		_collide_with_enemy(collider)
	else:
		# Hit a wall or platform - only called from shapecast/raycast which already filtered for vertical walls
		_collide_with_wall()


func _collide_with_enemy(enemy: Node) -> void:
	"""Door hits an enemy - knock down the enemy and continue flying."""
	# Only process the first enemy hit
	if has_hit_enemy:
		return
	
	has_hit_enemy = true
	
	# Make enemy also become physics object (knock it down)
	# Use the door's velocity direction and speed
	var knock_direction = kick_velocity.normalized()
	var knock_speed = kick_velocity.length()
	
	if enemy.has_method("become_physics_object"):
		enemy.become_physics_object(knock_direction, knock_speed)
	elif enemy.has_method("kick"):
		# Fallback: use existing kick method
		enemy.kick(knock_direction, knock_speed)
	
	# Door continues flying (doesn't stop on enemy hit)
	# Just reduce velocity slightly
	kick_velocity *= 0.95


func _collide_with_wall() -> void:
	"""Hit a wall - start falling with gravity."""
	# Don't collide with wall if we've already hit an enemy (enemies take priority)
	if has_collided:
		return
	
	if has_hit_enemy:
		return
	
	has_collided = true
	raycast.enabled = false
	shapecast.enabled = false
	despawn_timer = 0.0
	
	# Reduce velocity significantly on impact
	kick_velocity *= bounce_damping
	
	# Apply slight upward bounce
	kick_velocity.y = min(kick_velocity.y, -200.0)


func _on_timeout() -> void:
	"""Called when flight time expires without hitting a wall."""
	# Start falling
	has_collided = true
	raycast.enabled = false
	shapecast.enabled = false
	despawn_timer = 0.0


func _on_body_entered(body: Node2D) -> void:
	"""Handle collision with CharacterBody2D (walls, platforms, player)."""
	if is_kicked and not has_collided:
		# Don't collide with player
		if body.is_in_group("player"):
			return
		
		# Ignore body_entered collisions - we only want to stop on walls detected via shapecast/raycast
		# This prevents stopping on floors/platforms that trigger body_entered
		# Don't call _handle_collision here - let shapecast/raycast handle wall detection


func _on_area_entered(area: Area2D) -> void:
	"""Handle collision with Area2D (enemies)."""
	# Allow enemy detection even if we've collided with a wall (enemies take priority)
	if is_kicked and not has_hit_enemy:
		# Directly check if it's an enemy and handle it
		if area and is_instance_valid(area):
			if (area.is_in_group("enemies") or area.is_in_group("enemy")):
				if not area.is_destroyed:
					_collide_with_enemy(area)
			elif not has_collided:
				# Only handle non-enemy collisions if we haven't already collided
				_handle_collision(area)


func can_be_kicked() -> bool:
	"""Check if this door can currently be kicked."""
	return not is_kicked


func reset_state() -> void:
	"""Reset door state for level reset."""
	is_kicked = false
	kick_velocity = Vector2.ZERO
	rotation_speed = 0.0
	has_collided = false
	has_hit_enemy = false
	flight_timer = 0.0
	despawn_timer = 0.0
	distance_traveled = 0.0
	
	# Reset visual
	modulate = Color.WHITE
	modulate.a = 1.0
	
	# Disable raycast and shapecast
	if raycast:
		raycast.enabled = false
	if shapecast:
		shapecast.enabled = false
	
	# Re-enable blocking body so player can't pass through
	if blocking_body:
		blocking_body.collision_layer = 1  # Re-enable collision
		var blocking_collision = blocking_body.get_node_or_null("CollisionShape2D")
		if blocking_collision:
			blocking_collision.disabled = false
	
	# Reset collision shape
	if collision_shape:
		collision_shape.disabled = false
