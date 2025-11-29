extends Area2D

# Movement properties
@export_group("Bullet Movement")
@export var speed: float = 2500.0  ## Speed of the bullet
@export var lifetime: float = 5.0  ## Auto-destroy after this many seconds

# Internal state
var velocity: Vector2 = Vector2.ZERO
var lifetime_timer: float = 0.0
var shooter_enemy: Node2D = null  # Enemy that shot this bullet
var can_be_parried: bool = true  # Can this bullet be parried
var was_parried: bool = false  # Was this bullet parried

# Particle trail reference
var particle_trail: CPUParticles2D = null

func _ready() -> void:
	# Setup collision
	collision_layer = 16  # Layer 5 for enemy bullets
	collision_mask = 1  # Detect layer 1 (player CharacterBody2D and platforms)
	
	# Add to group for detection
	add_to_group("enemy_projectiles")
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Make visual more visible
	if has_node("Visual"):
		var visual = get_node("Visual")
		if visual is Polygon2D:
			visual.color = Color(1.0, 0.5, 0.0, 1.0)  # Bright orange
	
	# Hide the built-in trail line (we'll use particles instead)
	if has_node("Trail"):
		var trail = get_node("Trail")
		trail.visible = false
	
	# Create particle trail
	_create_particle_trail()

func _physics_process(delta: float) -> void:
	# Update lifetime
	lifetime_timer += delta
	if lifetime_timer >= lifetime:
		queue_free()
		return
	
	# Move bullet
	global_position += velocity * delta
	
	# Rotate to face direction of travel
	rotation = velocity.angle()

func initialize(direction: Vector2, start_speed: float = 2500.0, shooter: Node2D = null) -> void:
	"""Initialize the bullet with direction, speed, and shooter reference."""
	speed = start_speed
	velocity = direction.normalized() * speed
	shooter_enemy = shooter

func _on_body_entered(body: Node2D) -> void:
	"""Hit something solid (wall, platform, player, or enemy)."""
	# Check if it's the player (CharacterBody2D in "player" group)
	if body.is_in_group("player") and not was_parried:
		# Trigger player hitstun
		if body.has_method("_on_enemy_touched"):
			body._on_enemy_touched(shooter_enemy)
			print("[BULLET] Hit player! Triggering hitstun")
		
		# Destroy bullet
		queue_free()
		return
	
	# Hit a wall or platform - just destroy
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	"""Hit an area (including enemies)."""
	# If parried bullet hits an enemy area, make it physics object
	if was_parried and area.is_in_group("enemies"):
		if area.has_method("_hit_by_parried_bullet") and area == shooter_enemy:
			# Hit the enemy that shot this bullet
			var hit_direction = velocity.normalized()
			area._hit_by_parried_bullet(hit_direction, speed)
			print("[BULLET] Parried bullet hit enemy! Enemy becoming physics object")
		
		# Destroy bullet
		queue_free()
		return
	
	# Just destroy bullet on other area collisions
	queue_free()

func parry(parry_direction: Vector2) -> void:
	"""Called when player parries this bullet - reverse direction towards shooter."""
	if not can_be_parried:
		return
	
	can_be_parried = false
	was_parried = true
	
	# Calculate direction to shooter enemy
	var target_direction: Vector2
	if shooter_enemy and is_instance_valid(shooter_enemy) and not shooter_enemy.is_destroyed:
		# Aim at the enemy that shot this bullet
		target_direction = (shooter_enemy.global_position - global_position).normalized()
	else:
		# Fallback: reverse bullet direction
		target_direction = -velocity.normalized()
	
	# Set new velocity towards the enemy (no speed boost)
	velocity = target_direction * speed
	
	# Change color to indicate parried bullet (bright cyan/blue)
	if has_node("Visual"):
		var visual = get_node("Visual")
		if visual is Polygon2D:
			visual.color = Color(0.3, 1.0, 1.0, 1.0)  # Bright cyan
	
	# Update particle trail to cyan
	if particle_trail:
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color(0.3, 1.0, 1.0, 1.0))  # Bright cyan
		gradient.add_point(0.5, Color(0.2, 0.8, 1.0, 0.6))  # Lighter cyan
		gradient.add_point(1.0, Color(0.1, 0.5, 0.8, 0.0))  # Fade to transparent
		particle_trail.color_ramp = gradient
	
	# Update collision mask to hit enemies instead of player
	collision_mask = 0  # Clear mask
	set_collision_mask_value(1, true)  # Still detect walls/platforms
	
	print("[BULLET] Parried! Redirecting towards shooter at speed ", velocity.length())

func _create_particle_trail() -> void:
	"""Create a CPUParticles2D trail for the bullet."""
	particle_trail = CPUParticles2D.new()
	
	# Basic setup
	particle_trail.emitting = true
	particle_trail.amount = 50
	particle_trail.lifetime = 0.4
	particle_trail.one_shot = false
	particle_trail.explosiveness = 0.0
	particle_trail.randomness = 0.2
	particle_trail.local_coords = false
	particle_trail.draw_order = CPUParticles2D.DRAW_ORDER_INDEX
	
	# Emission
	particle_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	
	# Direction - particles emit backwards from bullet direction
	particle_trail.direction = Vector2(-1, 0)  # Will be rotated with bullet
	particle_trail.spread = 5.0
	
	# Velocity
	particle_trail.initial_velocity_min = 0.0
	particle_trail.initial_velocity_max = 50.0
	
	# Scale
	particle_trail.scale_amount_min = 3.0
	particle_trail.scale_amount_max = 6.0
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.5, 0.8))
	scale_curve.add_point(Vector2(1.0, 0.3))
	particle_trail.scale_amount_curve = scale_curve
	
	# Color gradient - orange to transparent
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.6, 0.0, 1.0))  # Bright orange
	gradient.add_point(0.4, Color(1.0, 0.4, 0.0, 0.7))  # Orange
	gradient.add_point(1.0, Color(0.8, 0.2, 0.0, 0.0))  # Dark orange fade
	particle_trail.color_ramp = gradient
	
	# Damping (slow down over time)
	particle_trail.damping_min = 20.0
	particle_trail.damping_max = 40.0
	
	# Add to bullet
	add_child(particle_trail)
	particle_trail.position = Vector2.ZERO
