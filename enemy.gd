extends Area2D

signal enemy_touched_by_player
signal enemy_destroyed

var is_destroyed: bool = false
var is_kicked: bool = false
var kick_velocity: Vector2 = Vector2.ZERO
var has_collided: bool = false
var flight_timer: float = 0.0
var despawn_timer: float = 0.0
var despawn_duration: float = 1.0  # Fast despawn after collision (1 second)
const MAX_FLIGHT_TIME: float = 1.0  # Max time to fly in straight line before timeout
var rotation_speed: float = 0.0

# Targeting/outline variables
var is_targeted: bool = false
var outline_shake_intensity: float = 2.0
var outline_node: Line2D = null

# Raycast and Shapecast for collision detection while flying
var raycast: RayCast2D
var shapecast: ShapeCast2D

# ====================================
# RANGED ATTACK CONFIGURATION
# ====================================
@export_group("Ranged Attack")
@export var shooting_enabled: bool = true  ## Enable ranged attacks
@export var shoot_interval: float = 1.0  ## Time between shots (seconds)
@export var warning_duration: float = 1.0  ## Duration of warning indicator before shooting (seconds)
@export var bullet_speed: float = 2000.0  ## Speed of fired bullets (pixels per second)
@export var detection_range: float = 800.0  ## Range to detect and shoot at player
@export var warning_shake_intensity: float = 3.0  ## Intensity of exclamation mark shake
@export var laser_color: Color = Color(1.0, 0.0, 0.0, 0.5) ## Default laser color
@export var laser_flash_color: Color = Color(1.0, 1.0, 0.0, 1.0) ## Flash color (Yellow)
@export var laser_width: float = 2.0 ## Default laser width
@export var laser_flash_width: float = 4.0 ## Flash laser width
@export var flash_threshold: float = 0.2 ## Time before firing to start flashing
@export var flash_interval: float = 0.05 ## Speed of flashing

# Bullet scene
const BulletScene = preload("res://enemy_bullet.tscn")

# Shooting state variables
var shoot_timer: float = 0.0
var warning_timer: float = 0.0
var is_warning: bool = false
var warning_indicator: Node2D = null
var warning_text: Label = null
var player_ref: Node2D = null
var laser_sight: Line2D = null

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
	
	# Create shapecast for more robust high-speed collision detection
	shapecast = ShapeCast2D.new()
	shapecast.enabled = false
	shapecast.collide_with_areas = false
	shapecast.collide_with_bodies = true
	shapecast.exclude_parent = true
	
	# Use a circle shape for the shapecast (roughly matching enemy size)
	var circle = CircleShape2D.new()
	circle.radius = 20.0
	shapecast.shape = circle
	shapecast.max_results = 1
	add_child(shapecast)
	
	# Create outline for targeting indicator
	outline_node = Line2D.new()
	outline_node.width = 3.0
	outline_node.default_color = Color(1.0, 0.0, 0.0, 1.0)  # Red outline
	outline_node.closed = true
	outline_node.visible = false
	outline_node.z_index = 10  # Draw on top
	add_child(outline_node)
	
	# Create laser sight for shooting warning
	laser_sight = Line2D.new()
	laser_sight.width = 2.0
	laser_sight.default_color = Color(1.0, 0.0, 0.0, 0.5)  # Transparent red
	laser_sight.visible = false
	laser_sight.z_index = 5
	add_child(laser_sight)
	
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
		flight_timer += delta
		
		# Check for timeout (didn't hit wall within 1 second)
		if flight_timer >= MAX_FLIGHT_TIME:
			_on_timeout()
			return
			
		# Check for collisions using both raycast and shapecast for maximum reliability
		# ShapeCast is better for high speed as it checks a volume
		var move_step = kick_velocity * delta
		shapecast.target_position = move_step * 1.5
		shapecast.force_shapecast_update()
		
		raycast.target_position = move_step * 1.5
		raycast.force_raycast_update()
		
		if shapecast.is_colliding() or raycast.is_colliding():
			# Hit something! Start falling
			_on_collision()
		else:
			# Keep flying in straight line
			global_position += move_step
			
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
	# If kicked and hit a solid body (wall/platform), trigger collision
	if is_kicked and not has_collided and body.collision_layer & 1: # Layer 1 is typical for walls
		_on_collision()
		return

	# Check if the body is the player (more robust detection)
	if body.has_method("_on_enemy_touched") and not is_destroyed:
		# Emit signal that player touched enemy, passing this enemy as parameter
		enemy_touched_by_player.emit(self)

func kick(knockback_direction: Vector2, force: float) -> void:
	"""Called when player kicks this enemy - send flying in straight line."""
	if not is_destroyed:
		is_destroyed = true
		is_kicked = true
		flight_timer = 0.0
		enemy_destroyed.emit()
		
		# Hide laser sight and warning
		if laser_sight: laser_sight.visible = false
		if warning_indicator: warning_indicator.visible = false
		
		# Set velocity for straight-line flight
		kick_velocity = knockback_direction * force
		
		# Add random spin
		rotation_speed = randf_range(-15.0, 15.0)
		
		# Disable player collision while flying
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		
		# Enable raycast and shapecast for collision detection
		raycast.enabled = true
		shapecast.enabled = true
		
		# Change color to indicate it's been kicked
		modulate = Color(1.5, 0.5, 0.5)  # Red tint
		

func _on_collision() -> void:
	"""Called when kicked enemy hits something - start falling."""
	has_collided = true
	raycast.enabled = false
	shapecast.enabled = false
	despawn_timer = 0.0
	
	# Screenshake on wall hit (lessened by 50%)
	if player_ref and player_ref.has_method("apply_camera_shake"):
		player_ref.apply_camera_shake(10.0, 0.3)
	
	# Show impact text
	_show_impact_text()
	
	# Reduce velocity significantly on impact
	kick_velocity *= 0.3
	

func _on_timeout() -> void:
	"""Called when flight time expires without hitting a wall."""
	# Trigger screenshake anyways (lessened by 50%)
	if player_ref and player_ref.has_method("apply_camera_shake"):
		player_ref.apply_camera_shake(7.5, 0.2)
	
	# Destroy the enemy
	queue_free()

func _show_impact_text() -> void:
	"""Show impact text (BAM, CRASH, THUMP) at collision point."""
	var words = ["BAM", "CRASH", "THUMP"]
	var word = words[randi() % words.size()]
	
	var label = Label.new()
	label.text = word
	label.z_index = 100
	
	# Style the label to match parry text size
	label.add_theme_font_size_override("font_size", 45)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Center the label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Add to the level
	get_parent().add_child(label)
	# Center label roughly on enemy
	label.global_position = global_position + Vector2(-50, -25)
	
	# Flame red and yellow flashing
	var flash_tween = label.create_tween().set_loops(6)
	flash_tween.tween_callback(func(): label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0))) # Red
	flash_tween.tween_interval(0.05)
	flash_tween.tween_callback(func(): label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))) # Yellow
	flash_tween.tween_interval(0.05)
	
	# Fade out and movement in direction of flight
	var move_tween = label.create_tween()
	var final_color = label.modulate
	final_color.a = 0.0
	
	# Normalize flight direction for consistent text movement
	var move_direction = kick_velocity.normalized()
	var movement_vector = move_direction * 100.0 # Move 100 pixels in impact direction
	
	move_tween.tween_property(label, "global_position", label.global_position + movement_vector, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	move_tween.parallel().tween_property(label, "modulate", final_color, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	move_tween.tween_callback(label.queue_free)

func destroy() -> void:
	"""Destroy the enemy (fallback for old system compatibility)"""
	if not is_destroyed:
		kick(Vector2.RIGHT, 0.0)  # Kick with no force

func disable(show_smiley_face: bool = false) -> void:
	"""Disable the enemy (non-violently, e.g. through dialogue)"""
	if not is_destroyed:
		is_destroyed = true
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		
		# Hide laser sight and warning
		if laser_sight: laser_sight.visible = false
		if warning_indicator: warning_indicator.visible = false
		
		if show_smiley_face:
			_show_smiley_face()
		
		# Fade out
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(self, "modulate:a", 0.0, 0.5)
		tween.finished.connect(queue_free)

func _show_smiley_face() -> void:
	"""Show a smiley face icon above the enemy."""
	var label = Label.new()
	label.text = ":)"
	label.z_index = 100
	
	# Style the label
	label.add_theme_font_size_override("font_size", 60)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Center the label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Add to the level
	get_parent().add_child(label)
	# Position above enemy
	label.global_position = global_position + Vector2(-25, -100)
	
	# Float up and fade out
	var tween = label.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(label, "global_position:y", label.global_position.y - 50, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)

func become_physics_object(direction: Vector2, speed: float) -> void:
	"""Turn into physics object when hit by kicked object - behaves like kick but synchronized with object."""
	if not is_destroyed:
		is_destroyed = true
		is_kicked = true
		has_collided = true  # Start as physics object immediately
		enemy_destroyed.emit()
		
		# Hide laser sight and warning
		if laser_sight: laser_sight.visible = false
		if warning_indicator: warning_indicator.visible = false
		
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
		
		# Show "Bonk!" text
		_show_bonk_text()
		

func _show_bonk_text() -> void:
	"""Show 'Bonk!' text when hit by a kicked object."""
	var label = Label.new()
	label.text = "Bonk!"
	label.z_index = 100
	
	# Style the label
	label.add_theme_font_size_override("font_size", 30) # Small popup text
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8)) # Light grey
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Center the label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Add to the level
	get_parent().add_child(label)
	# Center label roughly on enemy
	label.global_position = global_position + Vector2(-50, -40) # Slightly higher up
	
	# Fade out and movement upwards
	var tween = label.create_tween()
	var final_color = label.modulate
	final_color.a = 0.0
	
	tween.tween_property(label, "global_position:y", label.global_position.y - 60, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate", final_color, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)

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
		if laser_sight: laser_sight.visible = false
		return
	
	# Update warning state
	if is_warning:
		warning_timer += delta
		_update_warning_shake()
		
		# Rapid flashing logic 0.2 seconds before firing
		var time_until_fire = warning_duration - warning_timer
		var is_flashing_phase = time_until_fire <= flash_threshold
		var flash_on = int(warning_timer / flash_interval) % 2 == 0
		
		# Update laser sight
		if laser_sight:
			laser_sight.visible = true
			laser_sight.clear_points()
			laser_sight.add_point(Vector2.ZERO)
			laser_sight.add_point(to_local(player_ref.global_position))
			
			if is_flashing_phase:
				# Flash between Red and Yellow
				laser_sight.default_color = Color(1.0, 0.0, 0.0, 1.0) if flash_on else laser_flash_color
				laser_sight.width = laser_flash_width if flash_on else laser_width
			else:
				laser_sight.default_color = laser_color
				laser_sight.width = laser_width
		
		# Sync exclamation mark with flashing
		if warning_text:
			if is_flashing_phase:
				# Match laser flashing (Red/Yellow)
				warning_text.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0) if flash_on else laser_flash_color)
				warning_text.visible = true # Ensure it stays visible but changes color
			else:
				warning_text.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0)) # Default Yellow
				warning_text.visible = true
		
		if warning_timer >= warning_duration:
			# Warning complete - shoot!
			_shoot_at_player()
			is_warning = false
			warning_timer = 0.0
			if warning_indicator:
				warning_indicator.visible = false
			if laser_sight:
				laser_sight.visible = false
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
	

func _hit_by_parried_bullet(hit_direction: Vector2, bullet_speed: float) -> void:
	"""Called when this enemy is hit by a parried bullet."""
	if not is_destroyed:
		# Become physics object with bullet's velocity
		become_physics_object(hit_direction, bullet_speed)
