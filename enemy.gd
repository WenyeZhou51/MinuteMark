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

# ====================================
# RANGED ATTACK CONFIGURATION
# ====================================
@export_group("Ranged Attack")
@export var shooting_enabled: bool = true  ## Enable ranged attacks
@export var shoot_interval: float = 1.0  ## Time between shots (seconds)
@export var warning_duration: float = 0.3  ## Duration of warning indicator before shooting (seconds)
@export var bullet_speed: float = 2000.0  ## Speed of fired bullets (pixels per second)
@export var detection_range: float = 800.0  ## Range to detect and shoot at player
@export var warning_shake_intensity: float = 3.0  ## Intensity of exclamation mark shake

# Bullet scene
const BulletScene = preload("res://enemy_bullet.tscn")

# Shooting state variables
var shoot_timer: float = 0.0
var warning_timer: float = 0.0
var is_warning: bool = false
var warning_indicator: Node2D = null
var warning_text: Label = null
var player_ref: Node2D = null

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
	
	# Create warning indicator (exclamation mark)
	if shooting_enabled:
		_create_warning_indicator()
	
	# Find player reference
	await get_tree().process_frame
	_find_player()

func _physics_process(delta: float) -> void:
	# Update outline shake effect if targeted
	if is_targeted and outline_node and not is_destroyed:
		_update_outline_shake()
	
	# Update shooting behavior (only when not destroyed)
	if shooting_enabled and not is_destroyed and not is_kicked:
		_update_shooting(delta)
	
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
		# Emit signal that player touched enemy, passing this enemy as parameter
		enemy_touched_by_player.emit(self)
		# print("Enemy touched by player!")

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
		
		# print("Enemy kicked with force: ", force, " in direction: ", knockback_direction)

func _on_collision() -> void:
	"""Called when kicked enemy hits something - start falling."""
	has_collided = true
	raycast.enabled = false
	despawn_timer = 0.0
	
	# Reduce velocity significantly on impact
	kick_velocity *= 0.3
	
	# print("Enemy hit something! Starting to fall...")

func destroy() -> void:
	"""Destroy the enemy (fallback for old system compatibility)"""
	if not is_destroyed:
		kick(Vector2.RIGHT, 0.0)  # Kick with no force

func become_physics_object(direction: Vector2, speed: float) -> void:
	"""Turn into physics object when hit by kicked object - behaves like kick but synchronized with object."""
	if not is_destroyed:
		is_destroyed = true
		is_kicked = true
		has_collided = true  # Start as physics object immediately
		enemy_destroyed.emit()
		
		# Set velocity for physics behavior
		kick_velocity = direction * speed * 0.3  # Reduce speed for physics phase
		
		# Add random spin
		rotation_speed = randf_range(-15.0, 15.0)
		
		# Disable player collision
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		
		# Disable raycast since we're already in physics mode
		raycast.enabled = false
		
		# Change color to indicate physics object
		modulate = Color(1.0, 1.0, 0.5)  # Yellow tint
		
		# print("Enemy became physics object with velocity: ", kick_velocity)

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

# ====================================
# RANGED ATTACK SYSTEM
# ====================================

func _find_player() -> void:
	"""Find and store reference to player."""
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_ref = players[0]

func _create_warning_indicator() -> void:
	"""Create the visual warning indicator (exclamation mark)."""
	warning_indicator = Node2D.new()
	warning_indicator.name = "WarningIndicator"
	warning_indicator.visible = false
	add_child(warning_indicator)
	
	# Create exclamation mark label
	warning_text = Label.new()
	warning_text.text = "!"
	warning_text.add_theme_font_size_override("font_size", 48)
	warning_text.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0, 1.0))  # Yellow
	warning_text.add_theme_color_override("font_outline_color", Color(1.0, 0.0, 0.0, 1.0))  # Red outline
	warning_text.add_theme_constant_override("outline_size", 4)
	warning_text.position = Vector2(-12, -60)  # Above enemy
	warning_indicator.add_child(warning_text)

func _update_shooting(delta: float) -> void:
	"""Update shooting timer and handle shooting behavior."""
	# Check if player is in range
	if not player_ref or not is_instance_valid(player_ref):
		_find_player()
		return
	
	var distance_to_player = global_position.distance_to(player_ref.global_position)
	if distance_to_player > detection_range:
		return
	
	# Update warning state
	if is_warning:
		warning_timer += delta
		_update_warning_shake()
		
		if warning_timer >= warning_duration:
			# Warning complete - shoot!
			_shoot_at_player()
			is_warning = false
			warning_timer = 0.0
			if warning_indicator:
				warning_indicator.visible = false
	else:
		# Update shoot timer
		shoot_timer += delta
		
		if shoot_timer >= shoot_interval:
			# Start warning
			_start_warning()
			shoot_timer = 0.0

func _start_warning() -> void:
	"""Start the warning indicator before shooting."""
	is_warning = true
	warning_timer = 0.0
	
	if warning_indicator:
		warning_indicator.visible = true
	
	# print("[ENEMY] Warning started - will shoot in ", warning_duration, " seconds")

func _update_warning_shake() -> void:
	"""Apply vibrating shake effect to warning indicator."""
	if not warning_indicator or not warning_text:
		return
	
	# Generate random shake offset
	var shake_offset = Vector2(
		randf_range(-warning_shake_intensity, warning_shake_intensity),
		randf_range(-warning_shake_intensity, warning_shake_intensity)
	)
	
	# Apply shake to base position
	warning_text.position = Vector2(-12, -60) + shake_offset

func _shoot_at_player() -> void:
	"""Shoot a bullet towards the player."""
	if not player_ref or not is_instance_valid(player_ref):
		return
	
	# Calculate direction to player
	var direction_to_player = (player_ref.global_position - global_position).normalized()
	
	# Create bullet
	var bullet = BulletScene.instantiate()
	
	# Position bullet at enemy location
	bullet.global_position = global_position
	
	# Initialize bullet with direction, speed, and shooter reference
	bullet.initialize(direction_to_player, bullet_speed, self)
	
	# Add bullet to scene (as sibling, not child)
	get_parent().add_child(bullet)
	
	# print("[ENEMY] Fired bullet towards player! Direction: ", direction_to_player)

func _hit_by_parried_bullet(hit_direction: Vector2, bullet_speed: float) -> void:
	"""Called when this enemy is hit by a parried bullet."""
	if not is_destroyed:
		# Become physics object with bullet's velocity
		become_physics_object(hit_direction, bullet_speed)
		# print("[ENEMY] Hit by parried bullet! Becoming physics object")
