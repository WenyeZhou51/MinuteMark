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
@export var fragment_count: int = 8  ## Number of fragments when destroyed
@export var fragment_lifetime: float = 1.0  ## How long fragments last
@export var bounce_damping: float = 0.4  ## Velocity retention after bounce (0.0-1.0)
@export var gravity_strength: float = 2000.0  ## Gravity applied as physics object

@export_group("Detection")
@export var object_size: Vector2 = Vector2(40, 40)  ## Size of the object for visuals

# Internal state
var is_kicked: bool = false
var kick_velocity: Vector2 = Vector2.ZERO
var rotation_speed: float = 0.0
var has_collided: bool = false
var raycast: RayCast2D = null

# VFX state
var speed_lines: Array[Line2D] = []
var afterimage_timer: float = 0.0
const AFTERIMAGE_INTERVAL: float = 0.015
const SPEED_LINE_COUNT: int = 4
const SPEED_LINE_LENGTH: float = 80.0

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
	if not is_kicked or has_collided:
		return
		
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
		_update_speed_lines()
		_spawn_afterimage(delta)


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

	_create_speed_lines()

# ---- VFX helpers ----

func _create_speed_lines() -> void:
	for i in SPEED_LINE_COUNT:
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color(1.0, 1.0, 1.0, 0.6)
		line.z_index = -1
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.set_color(1, Color(1, 1, 1, 0.7))
		line.gradient = g
		get_parent().add_child(line)
		speed_lines.append(line)


func _update_speed_lines() -> void:
	var back_dir := -kick_velocity.normalized()
	for i in speed_lines.size():
		var line := speed_lines[i]
		if not is_instance_valid(line):
			continue
		var spread := Vector2(back_dir.y, -back_dir.x) * randf_range(-12.0, 12.0)
		var origin := global_position + spread
		line.clear_points()
		line.add_point(origin)
		line.add_point(origin + back_dir * SPEED_LINE_LENGTH * randf_range(0.6, 1.0))


func _remove_speed_lines() -> void:
	for line in speed_lines:
		if is_instance_valid(line):
			line.queue_free()
	speed_lines.clear()


func _spawn_afterimage(delta: float) -> void:
	afterimage_timer += delta
	if afterimage_timer < AFTERIMAGE_INTERVAL:
		return
	afterimage_timer = 0.0
	if not visual:
		return
	var ghost := Polygon2D.new()
	ghost.polygon = visual.polygon
	ghost.color = visual.color
	ghost.global_position = global_position
	ghost.rotation = rotation
	ghost.modulate = Color(modulate.r, modulate.g, modulate.b, 0.7)
	ghost.z_index = z_index - 1
	# Slight stretch along velocity for motion-blur feel
	var vel_dir := kick_velocity.normalized()
	ghost.scale = Vector2(1.0 + abs(vel_dir.x) * 0.3, 1.0 + abs(vel_dir.y) * 0.3)
	get_parent().add_child(ghost)
	var tw := get_tree().create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tw.tween_callback(ghost.queue_free)


func _spawn_impact_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 20
	particles.lifetime = 0.4
	particles.direction = -kick_velocity.normalized()
	particles.spread = 60.0
	particles.initial_velocity_min = 200.0
	particles.initial_velocity_max = 500.0
	particles.gravity = Vector2(0, 800)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.95, 0.7)
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(1.0, 1.0, 0.8, 1.0))
	color_ramp.set_color(1, Color(1.0, 0.6, 0.2, 0.0))
	particles.color_ramp = color_ramp
	particles.global_position = global_position
	get_parent().add_child(particles)
	get_tree().create_timer(particles.lifetime + 0.1, true, false, true).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


func _apply_impact_vfx(is_enemy_hit: bool) -> void:
	_remove_speed_lines()
	_spawn_impact_particles()
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("apply_camera_shake"):
			player.apply_camera_shake(20.0 if is_enemy_hit else 15.0, 0.15)
		if player.has_method("apply_hitstop"):
			player.apply_hitstop(0.05 if is_enemy_hit else 0.03)


func _handle_collision(collider: Node) -> void:
	"""Handle collision with wall or enemy."""
	if has_collided:
		return  # Already collided
	
	
	# Check if collider is an enemy
	if collider and (collider.is_in_group("enemies") or collider.is_in_group("enemy")):
		_collide_with_enemy(collider)
	else:
		# Hit a wall or platform
		_collide_with_wall()


func _collide_with_enemy(enemy: Node) -> void:
	"""Both object and enemy become physics objects for 0.5s then disappear."""
	_apply_impact_vfx(true)

	if enemy.has_method("become_physics_object"):
		enemy.become_physics_object(kick_velocity.normalized(), kick_velocity.length())
	elif enemy.has_method("kick"):
		enemy.kick(kick_velocity.normalized(), kick_velocity.length())
	
	_explode()


func _collide_with_wall() -> void:
	"""Hit a wall - explode into fragments."""
	_apply_impact_vfx(false)
	_explode()


func _explode() -> void:
	"""Spawn fragments and remove self."""
	if has_collided:
		return
	has_collided = true
	
	var half_size = object_size / 2.0
	var fragment_script = load("res://kickable_fragment.gd")
	var center = Vector2.ZERO
	
	# To ensure the fragments form the exact square, we slice it into triangles
	# from the center to points on the perimeter.
	var perimeter_points = []
	
	# Add the 4 corners explicitly to maintain the square shape
	var corners = [
		Vector2(-half_size.x, -half_size.y), # TL
		Vector2(half_size.x, -half_size.y),  # TR
		Vector2(half_size.x, half_size.y),   # BR
		Vector2(-half_size.x, half_size.y)   # BL
	]
	
	# Determine how many additional points to add per side to reach fragment_count
	# Total fragments = corners (4) + extra points
	var extra_points_total = max(0, fragment_count - 4)
	var points_per_side = extra_points_total / 4
	var remainder = extra_points_total % 4
	
	for i in range(4):
		var start_corner = corners[i]
		var end_corner = corners[(i + 1) % 4]
		perimeter_points.append(start_corner)
		
		var points_on_this_side = points_per_side + (1 if i < remainder else 0)
		for j in range(1, points_on_this_side + 1):
			var t = float(j) / (points_on_this_side + 1)
			perimeter_points.append(start_corner.lerp(end_corner, t))
	
	# Final color is Polygon2D color combined with node modulate
	var final_color = visual.color * modulate
	
	for i in range(perimeter_points.size()):
		var p1 = perimeter_points[i]
		var p2 = perimeter_points[(i + 1) % perimeter_points.size()]
		var fragment_points = PackedVector2Array([center, p1, p2])
		
		# Calculate explosion velocity
		var edge_midpoint = (p1 + p2) / 2.0
		var explode_dir = edge_midpoint.normalized()
		var explode_vel = explode_dir * randf_range(300.0, 700.0)
		var start_vel = (kick_velocity * 0.4) + explode_vel
		
		var fragment = fragment_script.new()
		get_parent().add_child(fragment)
		fragment.life_time = fragment_lifetime
		fragment.setup(fragment_points, global_position, rotation, start_vel, final_color, gravity_strength)
	
	queue_free()


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
