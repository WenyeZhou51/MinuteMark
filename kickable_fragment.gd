extends CharacterBody2D

var gravity: float = 2000.0
var life_time: float = 1.0
var timer: float = 0.0
var rotation_speed: float = 0.0
var is_on_ground: bool = false
var bounce_damping: float = 0.3  # Damping factor when hitting ground

var visual: Polygon2D = null
var collision_shape: CollisionShape2D = null

func _ready() -> void:
	# Create visual polygon
	visual = Polygon2D.new()
	add_child(visual)
	rotation_speed = randf_range(-15.0, 15.0)
	
	# Setup collision layers - fragments should collide with walls/platforms (layer 1)
	collision_layer = 0  # Fragments don't need to be on any collision layer
	collision_mask = 1   # Only collide with walls/platforms (layer 1)

func setup(points: PackedVector2Array, obj_global_pos: Vector2, obj_rotation: float, start_vel: Vector2, color: Color, grav: float = 2000.0) -> void:
	# Calculate centroid of points (relative to original object center)
	var centroid = Vector2.ZERO
	for p in points:
		centroid += p
	centroid /= points.size()
	
	# Shift points so centroid is at (0,0) for the fragment's local space
	var shifted_points = PackedVector2Array()
	for p in points:
		shifted_points.append(p - centroid)
	
	global_position = obj_global_pos + centroid.rotated(obj_rotation)
	velocity = start_vel
	gravity = grav
	visual.polygon = shifted_points
	visual.color = color
	
	# Inherit initial rotation and add some variety
	rotation = obj_rotation + randf_range(-0.5, 0.5)
	
	# Create collision shape from polygon points
	_create_collision_shape(shifted_points)

func _create_collision_shape(points: PackedVector2Array) -> void:
	"""Create a collision shape from polygon points."""
	if points.size() < 3:
		return
	
	# Create ConvexPolygonShape2D from points
	var shape = ConvexPolygonShape2D.new()
	shape.points = points
	
	# Create collision shape node
	collision_shape = CollisionShape2D.new()
	collision_shape.shape = shape
	add_child(collision_shape)

func _physics_process(delta: float) -> void:
	timer += delta
	
	# Apply gravity if not on ground
	if not is_on_ground:
		velocity.y += gravity * delta
	
	# Move using CharacterBody2D's move_and_slide (Godot 4: no parameters, uses velocity property)
	move_and_slide()
	
	# Check if on ground
	is_on_ground = is_on_floor()
	
	# Apply bounce damping when hitting ground
	if is_on_ground and velocity.y > 0:
		velocity.y *= bounce_damping
		velocity.x *= 0.9  # Friction on ground
	
	# Stop rotation when on ground (or slow it down)
	if is_on_ground:
		rotation_speed *= 0.95
	
	# Apply rotation
	rotation += rotation_speed * delta
	
	# Fade out - start fading after half lifetime, or immediately if on ground for a bit
	var fade_start_time = life_time * 0.5
	if is_on_ground:
		# Start fading sooner if on ground
		fade_start_time = life_time * 0.3
	
	if timer > fade_start_time:
		var fade_progress = (timer - fade_start_time) / (life_time - fade_start_time)
		modulate.a = 1.0 - fade_progress
	
	# Clean up
	if timer >= life_time:
		queue_free()
