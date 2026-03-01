extends Area2D

# Movement properties
@export_group("Bullet Movement")
@export var speed: float = 1400.0  ## Reduced speed (was 2000.0)
@export var lifetime: float = 5.0  ## Auto-destroy after this many seconds

@export_group("Visuals")
@export var bullet_scale: Vector2 = Vector2(3.0, 3.0) ## Much larger scale (was 1.5)
@export var collision_scale: Vector2 = Vector2(2.5, 2.5) ## Larger collision (was 1.2)
@export var particle_amount: int = 30 ## More particles for larger bullet
@export var particle_lifetime: float = 0.4 ## Longer trail
@export var particle_scale_min: float = 6.0 ## larger particles
@export var particle_scale_max: float = 12.0 ## larger particles

# Signals
signal bullet_parried  ## Emitted when this bullet is parried by the player

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
	
	# Make visual more visible and larger
	if has_node("Visual"):
		var visual = get_node("Visual")
		visual.scale = bullet_scale
		if visual is Polygon2D:
			visual.color = Color(1.0, 0.0, 0.0, 1.0)  # Pure red
			
			# Flashing tween
			var tween = create_tween().set_loops()
			tween.tween_property(visual, "color", Color(1.0, 0.5, 0.5, 1.0), 0.1) # Flash to lighter red
			tween.tween_property(visual, "color", Color(1.0, 0.0, 0.0, 1.0), 0.1) # Back to pure red
	
	# Scale collision shape to match
	if has_node("CollisionShape2D"):
		var shape = get_node("CollisionShape2D")
		shape.scale = collision_scale
	
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

func initialize(direction: Vector2, start_speed: float = 2000.0, shooter: Node2D = null) -> void:
	"""Initialize the bullet with direction, speed, and shooter reference."""
	speed = start_speed
	velocity = direction.normalized() * speed
	shooter_enemy = shooter

func _on_body_entered(body: Node2D) -> void:
	"""Hit something solid (wall, platform, player, or enemy)."""
	# Check if it's the player (CharacterBody2D in "player" group)
	if body.is_in_group("player") and not was_parried:
		# Trigger player bullet hit (with grace period for parrying)
		if body.has_method("_on_bullet_hit"):
			body._on_bullet_hit(self, shooter_enemy)
		elif body.has_method("_on_enemy_touched"):
			# Fallback for older version
			body._on_enemy_touched(shooter_enemy)
		
		# Destroy bullet
		queue_free()
		return
	
	# If parried, ignore wall collisions (go through walls)
	if was_parried:
		return
	
	# Hit a wall or platform - destroy (only for non-parried bullets)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	"""Hit an area (including enemies)."""
	# If parried bullet hits an enemy area, make it physics object
	if was_parried and area.is_in_group("enemies"):
		if area.has_method("_hit_by_parried_bullet"):
			# Hit any enemy when parried (prioritize shooter but hit any)
			var hit_direction = velocity.normalized()
			area._hit_by_parried_bullet(hit_direction, speed)
		
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
	
	# Emit signal to notify shooter enemy
	bullet_parried.emit()
	
	# Show Parry! text
	_show_parry_text()
	
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
	
	# Update collision mask to hit enemies only (go through walls on return trip)
	collision_mask = 0  # Clear mask
	set_collision_mask_value(3, true)  # Layer 3 for enemy areas (collision_layer = 4 = 2^2)
	

func _create_particle_trail() -> void:
	"""Create a CPUParticles2D trail for the bullet."""
	particle_trail = CPUParticles2D.new()
	
	# Basic setup
	particle_trail.emitting = true
	particle_trail.amount = particle_amount
	particle_trail.lifetime = particle_lifetime
	particle_trail.one_shot = false
	particle_trail.explosiveness = 0.0
	particle_trail.randomness = 0.2
	particle_trail.local_coords = false
	particle_trail.draw_order = CPUParticles2D.DRAW_ORDER_INDEX
	
	# Emission
	particle_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particle_trail.emission_rect_extents = Vector2(5, 10)  # Smaller emission
	
	# Direction - particles emit backwards from bullet direction
	particle_trail.direction = Vector2(-1, 0)  # Will be rotated with bullet
	particle_trail.spread = 10.0
	
	# Velocity
	particle_trail.initial_velocity_min = 20.0
	particle_trail.initial_velocity_max = 100.0
	
	# Scale
	particle_trail.scale_amount_min = particle_scale_min
	particle_trail.scale_amount_max = particle_scale_max
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.5, 0.8))
	scale_curve.add_point(Vector2(1.0, 0.3))
	particle_trail.scale_amount_curve = scale_curve
	
	# Color gradient - red to transparent
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.0, 0.0, 1.0))  # Bright red
	gradient.add_point(0.4, Color(1.0, 0.2, 0.2, 0.7))  # Light red
	gradient.add_point(1.0, Color(0.5, 0.0, 0.0, 0.0))  # Dark red fade
	particle_trail.color_ramp = gradient
	
	# Damping (slow down over time)
	particle_trail.damping_min = 20.0
	particle_trail.damping_max = 40.0
	
	# Add to bullet
	add_child(particle_trail)
	particle_trail.position = Vector2.ZERO

func _show_parry_text() -> void:
	"""Show flashing 'Parry!' text at the bullet's location."""
	var label = Label.new()
	label.text = "Parry!"
	label.z_index = 100
	
	# Style the label
	# Using system fonts if custom ones aren't available, but try to match style
	label.add_theme_font_size_override("font_size", 45) # 30% smaller (64 -> 45)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Center the label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Add to the level (parent of the bullet)
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(-100, -100)
	
	# Flashing effect (yellow and pink) - bind to label so it persists if bullet is destroyed
	var flash_tween = label.create_tween().set_loops(8)
	flash_tween.tween_callback(func(): label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))) # Yellow
	flash_tween.tween_interval(0.05)
	flash_tween.tween_callback(func(): label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.8))) # Pink/Magenta
	flash_tween.tween_interval(0.05)
	
	# Fade out and movement - bind to label
	var move_tween = label.create_tween()
	var final_color = label.modulate
	final_color.a = 0.0
	
	move_tween.tween_property(label, "global_position:y", label.global_position.y - 60, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	move_tween.parallel().tween_property(label, "modulate", final_color, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	move_tween.tween_callback(label.queue_free)
