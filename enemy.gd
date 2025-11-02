extends Area2D

signal enemy_touched_by_player
signal enemy_destroyed

var is_destroyed: bool = false
var is_kicked: bool = false
var kick_velocity: Vector2 = Vector2.ZERO
var has_collided: bool = false
var despawn_timer: float = 0.0
var despawn_duration: float = 1.0  # Fast despawn after collision (1 second)
var rotation_speed: float = 0.0

# Targeting/outline variables
var is_targeted: bool = false
var outline_shake_intensity: float = 2.0
var outline_node: Line2D = null

# Raycast for collision detection while flying
var raycast: RayCast2D

func _ready() -> void:
	# Connect the area entered signal for player touch
	body_entered.connect(_on_body_entered)
	
	# Create raycast for collision detection while kicked
	raycast = RayCast2D.new()
	raycast.enabled = false
	raycast.collide_with_areas = false
	raycast.collide_with_bodies = true
	raycast.exclude_parent = true
	add_child(raycast)
	
	# Create outline for targeting indicator
	outline_node = Line2D.new()
	outline_node.width = 3.0
	outline_node.default_color = Color(1.0, 0.0, 0.0, 1.0)  # Red outline
	outline_node.closed = true
	outline_node.visible = false
	outline_node.z_index = 10  # Draw on top
	add_child(outline_node)
	
	# Set outline points (rectangle around enemy)
	var outline_padding = 5.0
	outline_node.points = PackedVector2Array([
		Vector2(-20 - outline_padding, -30 - outline_padding),
		Vector2(20 + outline_padding, -30 - outline_padding),
		Vector2(20 + outline_padding, 30 + outline_padding),
		Vector2(-20 - outline_padding, 30 + outline_padding)
	])

func _physics_process(delta: float) -> void:
	# Update outline shake effect if targeted
	if is_targeted and outline_node and not is_destroyed:
		_update_outline_shake()
	
	if is_kicked and not has_collided:
		# Flying in straight line - check for collisions ahead
		raycast.target_position = kick_velocity * delta * 1.5  # Check slightly ahead
		raycast.force_raycast_update()
		
		if raycast.is_colliding():
			# Hit something! Start falling
			_on_collision()
		else:
			# Keep flying in straight line
			global_position += kick_velocity * delta
			
			# Rotate while flying
			rotation += rotation_speed * delta
	
	elif has_collided:
		# Falling with gravity after collision
		kick_velocity.y += 2000.0 * delta  # Apply gravity
		global_position += kick_velocity * delta
		rotation += rotation_speed * delta
		
		# Fast fade out
		despawn_timer += delta
		var fade_progress = despawn_timer / despawn_duration
		modulate.a = 1.0 - fade_progress
		
		if despawn_timer >= despawn_duration:
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	# Check if the body is the player (more robust detection)
	if body.has_method("_on_enemy_touched") and not is_destroyed:
		# Emit signal that player touched enemy
		enemy_touched_by_player.emit()
		print("Enemy touched by player!")

func kick(knockback_direction: Vector2, force: float) -> void:
	"""Called when player kicks this enemy - send flying in straight line."""
	if not is_destroyed:
		is_destroyed = true
		is_kicked = true
		enemy_destroyed.emit()
		
		# Set velocity for straight-line flight
		kick_velocity = knockback_direction * force
		
		# Add random spin
		rotation_speed = randf_range(-15.0, 15.0)
		
		# Disable player collision while flying
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		
		# Enable raycast for collision detection
		raycast.enabled = true
		
		# Change color to indicate it's been kicked
		modulate = Color(1.5, 0.5, 0.5)  # Red tint
		
		print("Enemy kicked with force: ", force, " in direction: ", knockback_direction)

func _on_collision() -> void:
	"""Called when kicked enemy hits something - start falling."""
	has_collided = true
	raycast.enabled = false
	despawn_timer = 0.0
	
	# Reduce velocity significantly on impact
	kick_velocity *= 0.3
	
	print("Enemy hit something! Starting to fall...")

func destroy() -> void:
	"""Destroy the enemy (fallback for old system compatibility)"""
	if not is_destroyed:
		kick(Vector2.RIGHT, 0.0)  # Kick with no force

func set_targeted(targeted: bool) -> void:
	"""Set whether this enemy is currently targeted by the player."""
	is_targeted = targeted
	if outline_node:
		outline_node.visible = targeted and not is_destroyed

func _update_outline_shake() -> void:
	"""Apply shake effect to the outline when targeted."""
	if not outline_node:
		return
	
	# Generate random shake offset for each point
	var outline_padding = 5.0
	var base_points = [
		Vector2(-20 - outline_padding, -30 - outline_padding),
		Vector2(20 + outline_padding, -30 - outline_padding),
		Vector2(20 + outline_padding, 30 + outline_padding),
		Vector2(-20 - outline_padding, 30 + outline_padding)
	]
	
	# Apply random shake to each point
	var shaken_points = PackedVector2Array()
	for point in base_points:
		var shake_offset = Vector2(
			randf_range(-outline_shake_intensity, outline_shake_intensity),
			randf_range(-outline_shake_intensity, outline_shake_intensity)
		)
		shaken_points.append(point + shake_offset)
	
	outline_node.points = shaken_points
