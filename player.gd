extends CharacterBody2D

# ====================================
# 2D PLATFORMER CONTROLLER
# ====================================
# Implements industry-standard platformer mechanics:
# - Variable jump height
# - Coyote time (grace period for jumping after leaving ground)
# - Jump buffering (input prediction before landing)
# - Physics-based movement with context-aware acceleration

# AFTERIMAGE EFFECT
const AfterimageScene = preload("res://afterimage.tscn")

# MOVEMENT CONFIGURATION
@export_group("Horizontal Movement")
@export var max_speed: float = 300.0  ## Maximum horizontal movement speed
@export var ground_acceleration: float = 1500.0  ## Acceleration when on ground
@export var ground_deceleration: float = 2000.0  ## Deceleration when on ground (no input)
@export var air_acceleration: float = 800.0  ## Acceleration when airborne (reduced control)
@export var air_deceleration: float = 400.0  ## Deceleration when airborne (reduced control)
@export var sprint_speed_threshold: float = 700.0  ## Speed required to enter sprint state
@export var run_speed_multiplier: float = 1.75  ## Speed multiplier when in sprint state
@export var run_acceleration_multiplier: float = 1.3  ## Acceleration multiplier when in sprint state
@export var run_activation_delay: float = 0.1  ## [UNUSED] Previously used for hold-to-sprint delay

# JUMP CONFIGURATION
@export_group("Jump Mechanics")
@export var jump_velocity: float = -612.5  ## Initial upward velocity for jump (adjusted to maintain jump height with increased gravity)
@export var jump_early_release_multiplier: float = 2.5  ## Gravity multiplier when jump released early
@export var coyote_time: float = 0.15  ## Grace period to jump after leaving ground
@export var jump_buffer_time: float = 0.1  ## Window to buffer jump input before landing
@export var empowered_jump_velocity_multiplier: float = 1.35  ## Vertical velocity multiplier for empowered jump (in sprint state)
@export var empowered_jump_horizontal_boost: float = 150.0  ## Extra horizontal velocity added to empowered jump (in sprint state)

# PHYSICS CONFIGURATION
@export_group("Physics")
@export var gravity: float = 2250.0  ## Base gravity acceleration (increased for faster falling)
@export var max_fall_speed: float = 800.0  ## Terminal velocity (maximum fall speed)
@export var ground_snap_force: float = 100.0  ## Force to keep player grounded on slopes

# INPUT CONFIGURATION
@export_group("Input")
@export var horizontal_dead_zone: float = 0.1  ## Dead zone for horizontal input (ignore small values)
@export var input_snap_threshold: float = 0.8  ## Threshold to snap analog input to full value

# QUALITY OF LIFE FEATURES
@export_group("Quality of Life")
@export var jump_peak_hangtime_multiplier: float = 0.3  ## Gravity multiplier at jump peak for extra hangtime (lower = more hangtime)
@export var jump_peak_threshold: float = 50.0  ## Velocity threshold to detect jump peak (abs value)
@export var turnaround_multiplier: float = 3.0  ## Acceleration multiplier when changing direction (higher = snappier)
@export var corner_correction_enabled: bool = true  ## Enable edge detection to avoid head bonking
@export var corner_correction_distance: float = 8.0  ## How far to check for corners
@export var ledge_climb_enabled: bool = true  ## Enable automatic ledge climbing when near ledge tops (requires sprint state)
@export var ledge_climb_detection_height: float = 12.0  ## Maximum height above player to detect ledges
@export var ledge_climb_min_height: float = 4.0  ## Minimum height above player to trigger climb (prevents climbing tiny steps)
@export var ledge_climb_duration: float = 0.3  ## Time to complete the climb animation
@export var ledge_climb_forward_offset: float = 4.0  ## How far forward to move player during climb
@export var ledge_climb_preserve_momentum: bool = true  ## Preserve horizontal velocity through ledge climb
@export var ledge_climb_momentum_retention: float = 0.85  ## Percentage of horizontal velocity to retain (0.0-1.0)
@export var ledge_climb_apply_momentum_during: bool = true  ## Apply horizontal movement during climb animation
@export var ledge_climb_min_exit_speed: float = 100.0  ## Minimum horizontal speed when finishing climb
@export var ledge_climb_momentum_grace_period: float = 0.15  ## Time after climb where momentum is protected from deceleration

@export_subgroup("Stun & Grace Period")
@export var stun_duration: float = 1.0  ## Duration of stun when touching enemy (seconds)
@export var grace_period_duration: float = 0.2  ## Grace period to cancel stun with kick (seconds)
@export var stun_invulnerability_duration: float = 0.5  ## Invulnerability after stun ends (seconds)
@export var stun_shake_intensity: float = 3.0  ## Intensity of shake effect during stun

# WALL JUMP CONFIGURATION
@export_group("Wall Jump")
@export var wall_jump_enabled: bool = true  ## Enable wall jump mechanics
@export var wall_check_distance: float = 8.0  ## Distance to check for walls from player edge
@export var wall_slide_speed: float = 60.0  ## Speed when sliding down a wall (slower fall)
@export var wall_jump_horizontal_velocity: float = 400.0  ## Horizontal push away from wall
@export var wall_jump_vertical_velocity: float = -551.25  ## Vertical jump force from wall (adjusted to maintain jump height with increased gravity)

# WALL RUN CONFIGURATION
@export_group("Wall Run")
@export var wall_run_enabled: bool = true  ## Enable wall run mechanics
@export var wall_run_min_velocity: float = 250.0  ## Minimum horizontal velocity to start a wall run
@export var wall_run_min_speed: float = 250.0  ## Minimum wall run upward speed
@export var wall_run_max_speed: float = 650.0  ## Maximum wall run upward speed
@export var wall_run_max_duration: float = 2.0  ## Maximum duration of wall run in seconds
@export var wall_run_speed_decay: float = 300.0  ## Speed decay per second during wall run
@export var wall_run_empowered_jump_horizontal: float = 600.0  ## Horizontal velocity for empowered wall jump
@export var wall_run_empowered_jump_vertical: float = -600.0  ## Vertical velocity for empowered wall jump

# DASH CONFIGURATION
@export_group("Dash")
@export var dash_enabled: bool = true  ## Enable dash mechanics

@export_subgroup("Ground Slide")
@export var ground_slide_speed: float = 1500.0  ## Speed during ground slide
@export var ground_slide_duration: float = 0.5  ## Duration of ground slide in seconds
@export var ground_slide_height_reduction: float = 0.5  ## Height reduction during slide (0.5 = 50% height)
@export var ground_slide_cooldown: float = 1.0  ## Cooldown between ground slides
@export var ground_slide_end_speed: float = 1000.0  ## Speed after slide ends
@export var ground_slide_empowered_jump_multiplier: float = 1.5  ## Jump height multiplier when jumping out of slide

@export_subgroup("Air Dash")
@export var air_dash_speed: float = 1200.0  ## Horizontal speed during air dash
@export var air_dash_duration: float = 0.2  ## Duration of air dash in seconds
@export var air_dash_cooldown: float = 0.35  ## Cooldown between air dashes

# KICK ATTACK CONFIGURATION
@export_group("Kick Attack")
@export var attack_enabled: bool = true  ## Enable kick attack mechanics
@export var attack_detection_range: float = 80.0  ## Range to detect enemies for attack (smaller range)
@export var attack_knockback_speed: float = 700.0  ## Speed at which player is knocked back from enemy
@export var attack_duration: float = 0.2  ## Duration of the attack knockback (seconds)
@export var attack_momentum_retention: float = 0.6  ## How much momentum is kept after attack (0.0-1.0)
@export var attack_cooldown: float = 0.2  ## Cooldown between attacks
@export var attack_enemy_knockback_force: float = 1200.0  ## Force applied to enemy when kicked

# BULLET PARRY CONFIGURATION
@export_group("Bullet Parry")
@export var parry_enabled: bool = true  ## Enable bullet parry mechanics
@export var parry_detection_range: float = 100.0  ## Range to detect bullets for parrying
@export var parry_angle_cone: float = 120.0  ## Cone angle in front of player for bullet detection (degrees)
@export var bullet_hit_grace_period: float = 0.1  ## Time window to press kick after being hit by bullet to parry instead of taking hitstun (seconds)

# KICK OBJECT CONFIGURATION
@export_group("Kick Object")
@export var kick_object_enabled: bool = true  ## Enable kicking objects
@export var kick_object_detection_range: float = 60.0  ## Range to detect kickable objects
@export var kick_object_speed: float = 2500.0  ## Speed at which kicked objects fly
@export var kick_object_cone_angle: float = 90.0  ## Cone angle in front of player for detection (degrees)

# DIVE CONFIGURATION
@export_group("Dive")
@export var dive_enabled: bool = true  ## Enable dive mechanics
@export var dive_speed: float = 1100.0  ## Fixed speed of the dive
@export var dive_angle_degrees: float = 45.0  ## Angle of dive from horizontal (45 degrees)
@export var dive_landing_speed_boost: float = 1.15  ## Speed multiplier on landing (15% boost)
@export var dive_attack_range: float = 400.0  ## Range to detect enemies for dive attack (checked continuously during dive)
@export var dive_attack_knockback_speed: float = 2500.0  ## Speed at which enemies are knocked downward by dive attack
@export var dive_attack_bounce_impulse: float = 500.0  ## Upward velocity given to player when hitting enemy with dive attack

# Internal state variables
var is_jump_held: bool = false  # Is jump button currently held
var is_jumping: bool = false  # Is player currently in jump state
var was_grounded: bool = false  # Was player grounded last frame
var jump_buffered: bool = false  # Is there a buffered jump input
var last_input_direction: float = 0.0  # Track previous input direction for turnaround detection
var is_running: bool = false  # Is player in sprint state (speed > sprint_speed_threshold)
var run_input_held_time: float = 0.0  # [UNUSED] Previously tracked run input hold time

# Performance optimization variables
var ledge_check_timer: float = 0.0
var ledge_check_interval: float = 0.2  # Check ledge climb every 0.2 seconds

# Wall jump state variables
var is_on_wall: bool = false  # Is player touching a wall
var wall_normal: Vector2 = Vector2.ZERO  # Direction pointing away from the wall
var is_wall_sliding: bool = false  # Is player currently sliding down a wall

# Wall run state variables
var is_wall_running: bool = false  # Is player currently wall running
var wall_run_timer: float = 0.0  # Time elapsed in current wall run
var wall_run_speed: float = 0.0  # Current upward speed during wall run
var wall_jump_cooldown: float = 0.0  # Cooldown after wall jump to prevent re-attachment

# Ledge climb state variables
var is_ledge_climbing: bool = false  # Is player currently climbing a ledge
var ledge_climb_progress: float = 0.0  # Progress through climb animation (0.0 to 1.0)
var ledge_climb_start_pos: Vector2 = Vector2.ZERO  # Starting position of climb
var ledge_climb_target_pos: Vector2 = Vector2.ZERO  # Target position on top of ledge
var ledge_climb_stored_velocity: float = 0.0  # Stored horizontal velocity to preserve through climb
var ledge_climb_grace_timer: float = 0.0  # Timer for momentum protection after climb
var ledge_climb_cooldown_timer: float = 0.0  # Cooldown to prevent re-triggering same ledge

# Attack state variables
var is_attacking: bool = false  # Is player currently performing an attack
var attack_timer: float = 0.0  # Time elapsed in current attack
var attack_cooldown_timer: float = 0.0  # Time remaining until next attack can be performed
var attack_direction: Vector2 = Vector2.RIGHT  # Direction of the knockback (away from enemy)
var attack_velocity: Vector2 = Vector2.ZERO  # Velocity during attack knockback
var attack_target_enemy: Node2D = null  # Enemy being kicked in current attack
var facing_direction: float = 1.0  # Direction player is facing (1 = right, -1 = left)
var nearby_enemies: Array[Node2D] = []  # Array of enemies within detection range
var last_targeted_enemy: Node2D = null  # Previously targeted enemy for outline management

# Kick object state variables
var nearby_kickable_objects: Array[Node2D] = []  # Array of kickable objects within range
var closest_kickable_object: Node2D = null  # Closest kickable object in front of player
var object_kick_indicator: Line2D = null  # Visual indicator for kick object direction

# Bullet parry state variables
var nearby_bullets: Array[Node2D] = []  # Array of bullets within parry range
var closest_bullet: Node2D = null  # Closest bullet in front of player
var bullet_parry_indicator: Line2D = null  # Visual indicator for parryable bullet
var bullet_grace_period_active: bool = false  # Is bullet hit grace period currently active
var bullet_grace_period_timer: float = 0.0  # Time remaining in bullet grace period
var bullet_that_hit: Node2D = null  # Bullet that triggered grace period

# Dash state variables
var is_ground_sliding: bool = false  # Is player currently ground sliding
var is_air_dashing: bool = false  # Is player currently air dashing
var ground_slide_timer: float = 0.0  # Time elapsed in current ground slide
var air_dash_timer: float = 0.0  # Time elapsed in current air dash
var ground_slide_cooldown_timer: float = 0.0  # Cooldown timer for ground slide
var air_dash_cooldown_timer: float = 0.0  # Cooldown timer for air dash
var dash_direction: float = 1.0  # Horizontal direction of dash (1 = right, -1 = left)
var pre_air_dash_horizontal_speed: float = 0.0  # Horizontal speed before air dash
var original_collision_shape_height: float = 64.0  # Original height of collision shape
var is_slide_jump_available: bool = false  # Can player perform empowered jump from slide
var is_invulnerable: bool = false  # Is player currently invulnerable (during dashes)
var run_input_just_pressed: bool = false  # Track if run input was just pressed this frame

# Dive state variables
var is_diving: bool = false  # Is player currently diving
var dive_velocity: Vector2 = Vector2.ZERO  # Velocity of the dive
var dive_pre_landing_horizontal_speed: float = 0.0  # Horizontal speed stored before landing
var dive_attack_visual: Node2D = null  # Visual indicator for dive attack range
var dive_range_circle: Polygon2D = null  # Circle showing dive attack range

# Stun state variables (internal - durations configured in Quality of Life section)
var is_stunned: bool = false  # Is player currently stunned
var stun_timer: float = 0.0  # Time remaining in stun
var stun_shake_offset: Vector2 = Vector2.ZERO  # Current shake offset applied to position
var stun_invulnerability_timer: float = 0.0  # Time remaining for post-stun invulnerability
var grace_period_timer: float = 0.0  # Time remaining in grace period
var grace_period_active: bool = false  # Is grace period currently active
var grace_period_colliding_enemy: Node2D = null  # Enemy that triggered grace period

# Afterimage state variables
var afterimage_timer: float = 0.0  # Timer for spawning afterimages
var afterimage_spawn_interval: float = 0.125  # Spawn an afterimage every 0.125 seconds (8 over 1 second)
var afterimage_enabled: bool = true  # Whether afterimages are enabled

# Component references
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer
@onready var attack_visual: Node2D = $AttackVisual
@onready var attack_indicator: Line2D = $AttackVisual/AttackIndicator
@onready var attack_target_marker: Marker2D = $AttackVisual/AttackTarget


func _ready() -> void:
	# Configure timers
	coyote_timer.wait_time = coyote_time
	jump_buffer_timer.wait_time = jump_buffer_time
	
	# Connect timer signals
	jump_buffer_timer.timeout.connect(_on_jump_buffer_timeout)
	
	# Store original collision shape height
	var collision_shape = $CollisionShape2D
	if collision_shape and collision_shape.shape:
		var shape = collision_shape.shape as RectangleShape2D
		if shape:
			original_collision_shape_height = shape.size.y
	
	# Create dive attack visual indicator
	_create_dive_attack_visual()
	
	# Create kick object visual indicator
	_create_kick_object_indicator()
	
	# Create bullet parry visual indicator
	_create_bullet_parry_indicator()
	
	# Connect to enemy signals
	_connect_to_enemies()


func _connect_to_enemies() -> void:
	"""Connect to all enemy signals for stun detection."""
	# Wait a frame for the scene to be fully loaded
	await get_tree().process_frame
	
	# Find all enemies and connect to their signals
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			# Reset enemy state when connecting (in case scene was reused or enemy was duplicated)
			enemy.is_destroyed = false
			enemy.visible = true
			enemy.monitoring = true
			enemy.monitorable = true
			
			if not enemy.enemy_touched_by_player.is_connected(_on_enemy_touched):
				enemy.enemy_touched_by_player.connect(_on_enemy_touched)
			if not enemy.enemy_destroyed.is_connected(_on_enemy_destroyed):
				enemy.enemy_destroyed.connect(_on_enemy_destroyed)
			print("Connected to enemy: ", enemy.name, " - reset state")


func _create_dive_attack_visual() -> void:
	"""Create the visual indicator for dive attack range."""
	# Create a container node for the dive attack visual
	dive_attack_visual = Node2D.new()
	dive_attack_visual.name = "DiveAttackVisual"
	add_child(dive_attack_visual)
	
	# Create a circle polygon to show the attack range
	dive_range_circle = Polygon2D.new()
	dive_range_circle.name = "DiveRangeCircle"
	dive_attack_visual.add_child(dive_range_circle)
	
	# Update the visual with current range
	_update_dive_attack_visual()
	
	# Hide by default
	dive_attack_visual.visible = false


func _update_dive_attack_visual() -> void:
	"""Update the dive attack visual indicator size based on current range."""
	if not dive_range_circle:
		return
	
	# Generate circle points (270-degree arc, excluding upper 90 degrees)
	var points: PackedVector2Array = []
	var num_segments = 64  # Number of segments for smooth circle
	
	# Add center point
	points.append(Vector2.ZERO)
	
	# Add arc points (going clockwise through bottom 270 degrees)
	# Start at 315 degrees (upper-right), sweep 270 degrees clockwise to 225 degrees (upper-left)
	# This excludes the upper 90-degree cone (225 to 315)
	var start_angle_deg = 315.0
	var arc_degrees = 270.0
	
	for i in range(num_segments + 1):
		var t = float(i) / num_segments
		var angle_deg = start_angle_deg + t * arc_degrees
		# Normalize angle to 0-360 range
		if angle_deg >= 360.0:
			angle_deg -= 360.0
		
		var angle_rad = deg_to_rad(angle_deg)
		var point = Vector2(cos(angle_rad), sin(angle_rad)) * dive_attack_range
		points.append(point)
	
	dive_range_circle.polygon = points
	dive_range_circle.color = Color(1.0, 0.5, 0.0, 0.3)  # Orange with transparency


func _create_kick_object_indicator() -> void:
	"""Create the visual indicator for kick object direction."""
	object_kick_indicator = Line2D.new()
	object_kick_indicator.name = "ObjectKickIndicator"
	object_kick_indicator.width = 3.0
	object_kick_indicator.default_color = Color(0.2, 1.0, 0.2, 0.8)  # Green
	object_kick_indicator.visible = false
	add_child(object_kick_indicator)


func _physics_process(delta: float) -> void:
	# Debug: Check if physics process is running
	if Engine.get_process_frames() % 300 == 0:  # Print every 300 frames (5 seconds at 60fps)
		print("Physics process running - attack_enabled: ", attack_enabled)
	
	# Update afterimage timer and spawn afterimages
	if afterimage_enabled:
		afterimage_timer += delta
		if afterimage_timer >= afterimage_spawn_interval:
			_spawn_afterimage()
			afterimage_timer = 0.0
	
	# Cache world space state once per frame for performance
	var space_state = get_world_2d().direct_space_state
	
	# Update performance timers
	ledge_check_timer += delta
	
	# 1. Process Input
	var input_vector := _get_input_vector()
	
	# Track if run input was just pressed this frame (for dash detection)
	run_input_just_pressed = Input.is_action_just_pressed("run")
	
	# Update cooldown timers
	if ground_slide_cooldown_timer > 0:
		ground_slide_cooldown_timer -= delta
	if air_dash_cooldown_timer > 0:
		air_dash_cooldown_timer -= delta
	
	# Handle dash input (shift press takes priority over run)
	if dash_enabled and run_input_just_pressed and not is_ground_sliding and not is_air_dashing and not is_stunned:
		if is_on_floor() and ground_slide_cooldown_timer <= 0:
			# Ground slide
			_start_ground_slide(input_vector.x)
		elif not is_on_floor() and air_dash_cooldown_timer <= 0:
			# Air dash
			_start_air_dash(input_vector.x)
	
	# Update run state based on speed (sprint state when speed exceeds threshold)
	var current_speed = velocity.length()
	is_running = current_speed > sprint_speed_threshold
	
	# Visual feedback: Turn player red when in sprint state, purple when diving, cyan when wall running, yellow when dashing
	# Stun visual feedback is handled in _process_stun()
	if not is_stunned:
		if bullet_grace_period_active:
			# Flash cyan/white during bullet grace period to indicate player can parry
			var flash = sin(bullet_grace_period_timer * 50.0) * 0.5 + 0.5
			modulate = Color(0.3 + flash * 0.7, 1.0, 1.0)  # Bright cyan flash (faster flash)
		elif grace_period_active:
			# Flash orange/white during grace period to indicate player can cancel stun
			var flash = sin(grace_period_timer * 40.0) * 0.5 + 0.5
			modulate = Color(1.0, 0.5 + flash * 0.5, 0.0)  # Orange flash
		elif stun_invulnerability_timer > 0:
			# Flash blue during post-stun invulnerability
			var flash = sin(stun_invulnerability_timer * 20.0) * 0.5 + 0.5
			modulate = Color(0.5 + flash * 0.5, 0.5 + flash * 0.5, 1.5)  # Blue flash
		elif is_ground_sliding or is_air_dashing:
			modulate = Color(1.5, 1.5, 0.5)  # Yellow tint for dashes (invulnerable)
		elif is_wall_running:
			modulate = Color(0.5, 1.5, 1.5)  # Cyan tint for wall run
		elif is_diving:
			modulate = Color(1.0, 0.5, 1.5)  # Purple tint
		elif is_running:
			modulate = Color(1.5, 0.5, 0.5)  # Red tint
		else:
			modulate = Color.WHITE  # Normal color
	
	# Update facing direction based on movement
	if input_vector.x != 0 and not is_attacking and not is_ground_sliding and not is_air_dashing:
		facing_direction = sign(input_vector.x)
	
	# Update attack cooldown timer
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	
	# Update ledge climb grace timer
	if ledge_climb_grace_timer > 0:
		ledge_climb_grace_timer -= delta
	
	# Update ledge climb cooldown timer
	if ledge_climb_cooldown_timer > 0:
		ledge_climb_cooldown_timer -= delta
	
	# Update wall jump cooldown timer
	if wall_jump_cooldown > 0:
		wall_jump_cooldown -= delta
	
	# Update stun timer
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0:
			_end_stun()
	
	# Update stun invulnerability timer (after stun ends)
	if stun_invulnerability_timer > 0:
		stun_invulnerability_timer -= delta
	
	# Update grace period timer
	if grace_period_active:
		grace_period_timer -= delta
		if grace_period_timer <= 0:
			# Grace period expired - apply stun
			_apply_stun_after_grace_period()
		else:
			# Check if kick button pressed during grace period
			if Input.is_action_just_pressed("melee_attack") and grace_period_colliding_enemy:
				# Cancel stun, perform kick attack instead!
				_cancel_grace_period_with_kick()
	
	# Update bullet grace period timer
	if bullet_grace_period_active:
		bullet_grace_period_timer -= delta
		if bullet_grace_period_timer <= 0:
			# Bullet grace period expired - apply hitstun
			_apply_bullet_hitstun()
		else:
			# Check if kick button pressed during bullet grace period
			if Input.is_action_just_pressed("melee_attack"):
				# Cancel hitstun, perform parry instead!
				_cancel_bullet_grace_period_with_parry()
	
	# 2. Handle Ground State Changes
	_update_ground_state()
	
	# 3. Update Wall State
	if wall_jump_enabled:
		_update_wall_state(input_vector.x, space_state)
	
	# 4. Process Ground Slide (if active, skip most normal movement)
	if is_ground_sliding:
		# Check for jump input to cancel slide with empowered jump
		if Input.is_action_just_pressed("jump") and not is_stunned:
			_perform_jump()  # Will automatically use slide jump bonus
			move_and_slide()
			_post_movement_updates()
			return
		
		_process_ground_slide(delta)
		# Check for wall run during slide
		if is_on_wall and wall_run_enabled:
			_start_wall_run(abs(velocity.x))
		# Skip normal physics when sliding
		move_and_slide()
		_post_movement_updates()
		return
	
	# 5. Process Air Dash (if active, skip most normal movement)
	if is_air_dashing:
		# Check for jump input to perform dive out of air dash
		if Input.is_action_just_pressed("jump") and not is_stunned:
			# End air dash
			_end_air_dash()
			# Perform dive instead of jump
			if dive_enabled:
				_start_dive(input_vector)
			move_and_slide()
			_post_movement_updates()
			return
		
		_process_air_dash(delta)
		# Check for wall run during air dash
		if is_on_wall and wall_run_enabled:
			_start_wall_run(abs(velocity.x))
		# Skip normal physics when air dashing
		move_and_slide()
		_post_movement_updates()
		return
	
	# 6. Process Dive (if active, skip most normal movement)
	if is_diving:
		_process_dive(delta)
		# Skip normal physics when diving
		move_and_slide()
		_post_movement_updates()
		return
	
	# 7. Process Wall Run (if active, skip most normal movement)
	if is_wall_running:
		# Check for jump input BEFORE processing wall run
		# This allows player to jump out of wall run
		if Input.is_action_just_pressed("jump") and not is_stunned:
			print("[WALL RUN] Jump pressed during wall run, performing empowered wall jump")
			_perform_wall_jump()
			# After jump, is_wall_running is false, so continue with normal physics below
		
		# Check if player is pressing away from the wall (end wall run)
		if is_wall_running:
			# wall_normal points AWAY from the wall
			# If player is pressing in the direction of wall_normal, they're pushing away from wall
			if (wall_normal.x > 0 and input_vector.x > 0.1) or (wall_normal.x < 0 and input_vector.x < -0.1):
				print("[WALL RUN] Player pushing away from wall, ending wall run")
				_end_wall_run()
		
		# Only process wall run if still wall running (jump or input might have cancelled it)
		if is_wall_running:
			_process_wall_run(delta)
			# Skip normal physics when wall running
			move_and_slide()
			_post_movement_updates()
			return
	
	# 8. Update Enemy Detection
	if attack_enabled:
		_update_enemy_detection()
		_update_attack_indicator()
	
	# 9. Update Kickable Object Detection
	if kick_object_enabled:
		_update_kickable_object_detection()
		_update_kick_object_indicator()
	
	# 9.5. Update Bullet Parry Detection
	if parry_enabled:
		_update_bullet_detection()
		_update_bullet_parry_indicator()
	
	# 10. Handle Attack/Kick Input
	if attack_enabled or kick_object_enabled or parry_enabled:
		_handle_kick_input()
	
	# 11. Process Attack (if active, skip normal movement)
	if is_attacking:
		_process_attack(delta)
		# Skip normal physics when attacking
		move_and_slide()
		_post_movement_updates()
		return
	
	# 12. Process Stun (if stunned, skip normal movement)
	if is_stunned:
		_process_stun(delta)
		# Skip normal physics when stunned
		move_and_slide()
		_post_movement_updates()
		return
	
	# 13. QOL: Ledge Climb (if enabled and active, skip normal movement)
	if is_ledge_climbing:
		_process_ledge_climb(delta)
		move_and_slide()
		_post_movement_updates()
		return
	
	# 14. QOL: Check for Ledge Climb Opportunity (only when airborne and timer allows)
	if ledge_climb_enabled and not is_on_floor() and is_on_wall and ledge_check_timer >= ledge_check_interval:
		_check_ledge_climb(space_state)
		ledge_check_timer = 0.0
	
	# 15. Apply Gravity
	_apply_gravity(delta)
	
	# 16. Handle Jump Input
	_handle_jump_input()
	
	# 17. Apply Horizontal Movement
	_apply_horizontal_movement(input_vector.x, delta)
	
	# 18. Execute Jump (if buffered or triggered)
	_execute_buffered_jump()
	
	# 19. Move Character
	move_and_slide()
	
	# 20. QOL: Corner Correction (only when moving up fast)
	if corner_correction_enabled and velocity.y < 0 and abs(velocity.y) > 50:
		_apply_corner_correction(space_state)
	
	# 21. Post-Movement Updates
	_post_movement_updates()


# ====================================
# INPUT PROCESSING
# ====================================

func _get_input_vector() -> Vector2:
	"""Process and filter input to create clean movement vector."""
	var input_vec := Vector2.ZERO
	
	# Get raw input (supports both keyboard and gamepad)
	input_vec.x = Input.get_axis("move_left", "move_right")
	input_vec.y = Input.get_axis("move_up", "move_down")
	
	# Apply dead zone filtering
	if abs(input_vec.x) < horizontal_dead_zone:
		input_vec.x = 0.0
	
	# Snap to full value if close to maximum (for analog sticks)
	if abs(input_vec.x) > input_snap_threshold:
		input_vec.x = sign(input_vec.x)
	
	return input_vec


# ====================================
# GROUND STATE MANAGEMENT
# ====================================

func _update_ground_state() -> void:
	"""Track ground state changes and manage coyote time."""
	var currently_grounded := is_on_floor()
	
	# Detect landing (transition from air to ground)
	if currently_grounded and not was_grounded:
		_on_landed()
	
	# Detect leaving ground (transition from ground to air)
	elif not currently_grounded and was_grounded:
		_on_left_ground()
	
	was_grounded = currently_grounded


func _on_landed() -> void:
	"""Called when player lands on ground."""
	is_jumping = false
	# Reset ledge climb cooldown on landing (allows fresh ledge climb attempts)
	ledge_climb_cooldown_timer = 0.0
	
	# End wall run if landing
	if is_wall_running:
		_end_wall_run()
	
	# Handle dive landing with speed boost
	if is_diving:
		# Preserve horizontal momentum and apply landing speed boost multiplier
		velocity.x = dive_pre_landing_horizontal_speed * dive_landing_speed_boost
		velocity.y = 0  # Cancel vertical velocity
		is_diving = false
		# Hide dive attack visual
		if dive_attack_visual:
			dive_attack_visual.visible = false
		# Dive landed with speed boost
	
	# Could trigger landing effects here (particles, sound, etc.)


func _on_left_ground() -> void:
	"""Called when player leaves ground (start coyote time)."""
	# Only start coyote timer if not jumping (i.e., walked off ledge)
	if not is_jumping:
		coyote_timer.start()


# ====================================
# WALL DETECTION & STATE
# ====================================

func _update_wall_state(input_direction: float, space_state: PhysicsDirectSpaceState2D) -> void:
	"""Detect walls and update wall sliding state."""
	# Save previous wall state for wall run detection
	var was_on_wall = is_on_wall
	var was_wall_normal = wall_normal
	
	# Always reset wall state - we'll re-detect it below
	# This ensures is_on_wall accurately reflects current wall contact
	is_on_wall = false
	is_wall_sliding = false
	wall_normal = Vector2.ZERO
	
	# Get collision shape for positioning raycasts
	var collision_shape = $CollisionShape2D
	if not collision_shape or not collision_shape.shape:
		return
	
	var shape = collision_shape.shape as RectangleShape2D
	if not shape:
		return
	
	var half_width = shape.size.x / 2.0
	var half_height = shape.size.y / 2.0
	
	# During wall run, check at multiple heights for more accurate wall detection
	var check_heights = [0.0]  # Default: center only
	
	var left_hit_any = false
	var right_hit_any = false
	
	# Check for walls at each height
	for height_offset in check_heights:
		# Check for wall on the left
		var left_ray_origin = global_position + Vector2(-half_width, height_offset)
		var left_ray_end = left_ray_origin + Vector2(-wall_check_distance, 0)
		var query_left = PhysicsRayQueryParameters2D.create(left_ray_origin, left_ray_end)
		query_left.exclude = [self]
		var left_hit = space_state.intersect_ray(query_left)
		if left_hit:
			left_hit_any = true
		
		# Check for wall on the right
		var right_ray_origin = global_position + Vector2(half_width, height_offset)
		var right_ray_end = right_ray_origin + Vector2(wall_check_distance, 0)
		var query_right = PhysicsRayQueryParameters2D.create(right_ray_origin, right_ray_end)
		query_right.exclude = [self]
		var right_hit = space_state.intersect_ray(query_right)
		if right_hit:
			right_hit_any = true
	
	# Determine if player is on a wall
	if left_hit_any:
		is_on_wall = true
		wall_normal = Vector2.RIGHT  # Wall is on left, so push right
		# Reset air dash cooldown when touching wall
		air_dash_cooldown_timer = 0.0
		# Player is wall sliding if moving down and pressing toward wall
		if velocity.y > 0 and input_direction < 0:
			is_wall_sliding = true
	elif right_hit_any:
		is_on_wall = true
		wall_normal = Vector2.LEFT  # Wall is on right, so push left
		# Reset air dash cooldown when touching wall
		air_dash_cooldown_timer = 0.0
		# Player is wall sliding if moving down and pressing toward wall
		if velocity.y > 0 and input_direction > 0:
			is_wall_sliding = true
	
	# Debug wall detection changes
	if is_on_wall != was_on_wall:
		print("[WALL DETECT] Wall state changed - is_on_wall: ", is_on_wall, " wall_normal: ", wall_normal, " cooldown: ", wall_jump_cooldown)
	
	# Check for wall run activation (only if not on cooldown from wall jump)
	if wall_run_enabled and is_on_wall and not was_on_wall and not is_wall_running and wall_jump_cooldown <= 0:
		# Check if horizontal velocity is high enough to start a wall run
		var horizontal_speed = abs(velocity.x)
		if horizontal_speed >= wall_run_min_velocity:
			print("[WALL RUN] Activating wall run - horizontal_speed: ", horizontal_speed, " wall_normal: ", wall_normal)
			_start_wall_run(horizontal_speed)
	elif wall_run_enabled and is_on_wall and not was_on_wall and not is_wall_running and wall_jump_cooldown > 0:
		print("[WALL RUN] Wall run blocked by cooldown: ", "%.2f" % wall_jump_cooldown, "s remaining")
	
	# End wall run if wall ends
	if is_wall_running and not is_on_wall:
		print("[WALL RUN] Wall ended, stopping wall run")
		_end_wall_run()


# ====================================
# WALL RUN
# ====================================

func _start_wall_run(horizontal_speed: float) -> void:
	"""Initiate a wall run up the wall."""
	is_wall_running = true
	wall_run_timer = 0.0
	
	# Calculate wall run speed proportional to horizontal velocity
	# Clamp between min and max wall run speed
	wall_run_speed = clamp(horizontal_speed, wall_run_min_speed, wall_run_max_speed)
	
	print("[WALL RUN] Started - Speed: ", wall_run_speed, " Wall normal: ", wall_normal, " Position: ", global_position)
	
	# Set upward velocity
	velocity.y = -wall_run_speed
	
	# Maintain some horizontal velocity towards the wall to stay attached
	velocity.x = velocity.x * 0.3  # Reduce horizontal speed but keep direction
	
	# Cancel other states
	is_jumping = false
	is_wall_sliding = false
	is_diving = false
	# Hide dive attack visual
	if dive_attack_visual:
		dive_attack_visual.visible = false
	
	# End ground slide or air dash if wall running
	if is_ground_sliding:
		_end_ground_slide()
	if is_air_dashing:
		_end_air_dash()
	
	# Could trigger wall run effects here (particles, sound, animation, etc.)


func _process_wall_run(delta: float) -> void:
	"""Update wall run state - move upward with decaying speed."""
	# Increment timer
	wall_run_timer += delta
	
	# Check if max duration reached
	if wall_run_timer >= wall_run_max_duration:
		print("[WALL RUN] Max duration reached (", wall_run_max_duration, "s)")
		_end_wall_run()
		return
	
	# Apply speed decay
	wall_run_speed -= wall_run_speed_decay * delta
	
	# Check if speed dropped below minimum
	if wall_run_speed < wall_run_min_speed:
		print("[WALL RUN] Speed dropped below minimum (", wall_run_speed, " < ", wall_run_min_speed, ")")
		_end_wall_run()
		return
	
	# Set upward velocity based on current wall run speed
	velocity.y = -wall_run_speed
	
	# Maintain slight horizontal velocity to stay on wall
	# Push slightly into the wall
	velocity.x = -wall_normal.x * 50.0
	
	# Debug output every 0.5 seconds
	if int(wall_run_timer * 2) != int((wall_run_timer - delta) * 2):
		print("[WALL RUN] Running - timer: ", "%.2f" % wall_run_timer, "s, speed: ", "%.1f" % wall_run_speed, ", velocity: ", velocity)


func _end_wall_run() -> void:
	"""End the wall run."""
	if not is_wall_running:
		return
	
	var velocity_before = velocity
	print("[WALL RUN] Ending - Velocity before: ", velocity_before, " | Position: ", global_position)
		
	is_wall_running = false
	wall_run_timer = 0.0
	wall_run_speed = 0.0
	
	# Allow gravity to take over
	# Velocity is maintained but wall run state is cleared
	
	print("[WALL RUN] Ended - Velocity after: ", velocity, " | Changed: ", velocity != velocity_before)
	
	# Could trigger wall run end effects here (particles fade, etc.)


# ====================================
# GRAVITY & PHYSICS
# ====================================

func _apply_gravity(delta: float) -> void:
	"""Apply gravity with variable strength based on jump state."""
	if not is_on_floor():
		# WALL RUNNING: No gravity during wall run (handled in _process_wall_run)
		if is_wall_running:
			return
		# WALL SLIDING: Apply gravity but cap at wall slide speed
		elif is_wall_sliding:
			velocity.y += gravity * delta
			velocity.y = min(velocity.y, wall_slide_speed)
		else:
			var gravity_multiplier := 1.0
			
			# QOL FEATURE: Jump peak hangtime - reduce gravity at peak of jump
			# Creates a more floaty, controlled feel at the apex
			if abs(velocity.y) < jump_peak_threshold and is_jumping:
				gravity_multiplier = jump_peak_hangtime_multiplier
			# Apply stronger gravity for variable jump height
			# If player released jump during ascent, fall faster
			elif velocity.y < 0 and not is_jump_held and is_jumping:
				gravity_multiplier = jump_early_release_multiplier
			
			velocity.y += gravity * gravity_multiplier * delta
			
			# Cap fall speed (terminal velocity)
			velocity.y = min(velocity.y, max_fall_speed)
	else:
		# Apply small downward force to maintain ground contact on slopes
		velocity.y = ground_snap_force


# ====================================
# HORIZONTAL MOVEMENT
# ====================================

func _apply_horizontal_movement(input_direction: float, delta: float) -> void:
	"""Apply horizontal movement with context-aware acceleration."""
	var speed := max_speed
	
	# Apply run speed multiplier when running
	if is_running:
		speed *= run_speed_multiplier
	
	var target_velocity := input_direction * speed
	
	# Determine acceleration/deceleration based on ground state
	var acceleration: float
	var deceleration: float
	
	if is_on_floor():
		acceleration = ground_acceleration
		deceleration = ground_deceleration
		# Apply run acceleration multiplier when running
		if is_running:
			acceleration *= run_acceleration_multiplier
	else:
		acceleration = air_acceleration
		deceleration = air_deceleration
	
	# QOL FEATURE: Turnaround multiplier - detect direction change for snappier turns
	var is_turning_around := false
	if input_direction != 0.0 and last_input_direction != 0.0:
		# Check if we're changing direction (signs are opposite)
		if sign(input_direction) != sign(velocity.x) and abs(velocity.x) > 10.0:
			is_turning_around = true
			acceleration *= turnaround_multiplier
	
	# Apply acceleration or deceleration
	if input_direction != 0.0:
		# Accelerating toward target velocity
		velocity.x = move_toward(velocity.x, target_velocity, acceleration * delta)
		last_input_direction = input_direction
	else:
		# Check if momentum is protected by ledge climb grace period
		if ledge_climb_grace_timer > 0:
			# Maintain velocity during grace period (no deceleration)
			pass
		else:
			# Decelerating to stop
			velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		last_input_direction = 0.0


# ====================================
# JUMP MECHANICS
# ====================================

func _handle_jump_input() -> void:
	"""Process jump input with buffering and state tracking."""
	# Can't jump when stunned
	if is_stunned:
		return
	
	# Track jump hold state
	is_jump_held = Input.is_action_pressed("jump")
	
	# Check for jump button press this frame
	if Input.is_action_just_pressed("jump"):
		print("[JUMP INPUT] Jump pressed - is_on_wall: ", is_on_wall, " is_wall_running: ", is_wall_running, " is_on_floor: ", is_on_floor())
		
		# Check for wall jump first (highest priority)
		# Note: Wall run jump is handled earlier in _physics_process
		if wall_jump_enabled and is_on_wall and not is_wall_running:
			_perform_wall_jump()
		else:
			# Check if we can jump immediately
			var can_jump := is_on_floor() or not coyote_timer.is_stopped()
			
			if can_jump:
				_perform_jump()
			else:
				# If in air, check if we can dive instead
				if dive_enabled and not is_diving and is_running:
					var input_vector = _get_input_vector()
					_start_dive(input_vector)
				else:
					# Buffer the jump input for when we land
					jump_buffered = true
					jump_buffer_timer.start()


func _execute_buffered_jump() -> void:
	"""Execute a buffered jump if player just landed."""
	if jump_buffered and is_on_floor():
		_perform_jump()
		jump_buffered = false
		jump_buffer_timer.stop()


func _perform_jump() -> void:
	"""Execute a jump, with empowered jump if in sprint state or jumping out of slide."""
	# Check if jumping out of ground slide (empowered jump)
	if is_slide_jump_available:
		# End the slide first
		_end_ground_slide()
		
		# Empowered slide jump - even better than sprint jump
		velocity.y = jump_velocity * ground_slide_empowered_jump_multiplier
		
		# Add horizontal boost in current direction
		var jump_direction = sign(velocity.x) if abs(velocity.x) > 10.0 else last_input_direction
		if jump_direction != 0:
			velocity.x += jump_direction * empowered_jump_horizontal_boost
		
		is_slide_jump_available = false
		print("[SLIDE JUMP] Empowered jump from slide! Jump multiplier: ", ground_slide_empowered_jump_multiplier)
	# Apply empowered jump when in sprint state
	elif is_running:
		# Vertical boost - jump higher
		velocity.y = jump_velocity * empowered_jump_velocity_multiplier
		
		# Horizontal boost - add momentum in current direction
		var jump_direction = sign(velocity.x) if abs(velocity.x) > 10.0 else last_input_direction
		if jump_direction != 0:
			velocity.x += jump_direction * empowered_jump_horizontal_boost
	else:
		# Normal jump
		velocity.y = jump_velocity
	
	is_jumping = true
	coyote_timer.stop()  # Consume coyote time
	# Could trigger jump effects here (particles, sound, animation, etc.)


func _perform_wall_jump() -> void:
	"""Execute a wall jump away from the wall."""
	# Store wall normal before clearing wall state (important!)
	var jump_wall_normal = wall_normal
	
	# If wall_normal is zero, we might have lost it, try to infer from velocity
	if jump_wall_normal.length_squared() == 0:
		if velocity.x < 0:
			jump_wall_normal = Vector2.RIGHT  # Was on left wall
		else:
			jump_wall_normal = Vector2.LEFT  # Was on right wall
		print("[WALL JUMP] Wall normal was zero, inferred: ", jump_wall_normal, " from velocity.x: ", velocity.x)
	
	print("[WALL JUMP] Starting wall jump - is_wall_running: ", is_wall_running, " wall_normal: ", jump_wall_normal, " position: ", global_position)
	
	# Check if jumping from a wall run (empowered wall jump)
	if is_wall_running:
		# Empowered wall jump with higher velocities
		velocity.y = wall_run_empowered_jump_vertical
		velocity.x = jump_wall_normal.x * wall_run_empowered_jump_horizontal
		
		print("[WALL JUMP] ⚡ EMPOWERED ⚡ - velocity: ", velocity, " | horizontal: ", velocity.x, " | vertical: ", velocity.y)
		
		# End wall run
		_end_wall_run()
	else:
		# Normal wall jump
		velocity.y = wall_jump_vertical_velocity
		velocity.x = jump_wall_normal.x * wall_jump_horizontal_velocity
		
		print("[WALL JUMP] Normal - velocity: ", velocity, " | horizontal: ", velocity.x, " | vertical: ", velocity.y)
	
	# Set jump state
	is_jumping = true
	
	# Set cooldown to prevent immediate re-attachment to wall
	wall_jump_cooldown = 0.3  # 0.3 second cooldown
	
	# Clear wall state to prevent immediate re-attachment
	is_on_wall = false
	is_wall_sliding = false
	
	print("[WALL JUMP] ✓ Complete - Final velocity: ", velocity, " | Cooldown: ", wall_jump_cooldown, "s")
	
	# Could trigger wall jump effects here (particles, sound, animation, etc.)


func _on_jump_buffer_timeout() -> void:
	"""Clear buffered jump when timer expires."""
	jump_buffered = false


# ====================================
# CORNER CORRECTION (EDGE DETECTION)
# ====================================

func _apply_corner_correction(space_state: PhysicsDirectSpaceState2D) -> void:
	"""QOL FEATURE: Nudge player past corners to avoid head bonking on edges."""
	# Only apply when moving upward (before/during collision, not after stopped)
	if velocity.y >= 0:
		return
	
	# Get collision shape dimensions
	var collision_shape = $CollisionShape2D
	if not collision_shape or not collision_shape.shape:
		return
	
	var shape = collision_shape.shape as RectangleShape2D
	if not shape:
		return
	
	var half_width = shape.size.x / 2.0
	var half_height = shape.size.y / 2.0
	
	# Cast upward from left corner of player's head
	var left_corner_pos = global_position + Vector2(-half_width + 2, -half_height)
	var left_cast_end = left_corner_pos + Vector2(0, -corner_correction_distance)
	var query_left = PhysicsRayQueryParameters2D.create(left_corner_pos, left_cast_end)
	query_left.exclude = [self]
	var left_hit = space_state.intersect_ray(query_left)
	
	# Cast upward from right corner of player's head
	var right_corner_pos = global_position + Vector2(half_width - 2, -half_height)
	var right_cast_end = right_corner_pos + Vector2(0, -corner_correction_distance)
	var query_right = PhysicsRayQueryParameters2D.create(right_corner_pos, right_cast_end)
	query_right.exclude = [self]
	var right_hit = space_state.intersect_ray(query_right)
	
	# Corner correction logic: if one side hits a corner but the other doesn't, nudge toward the clear side
	if left_hit and not right_hit:
		# Left corner is blocked, right is clear -> nudge right to slip past
		position.x += corner_correction_distance * 0.75
	elif right_hit and not left_hit:
		# Right corner is blocked, left is clear -> nudge left to slip past
		position.x -= corner_correction_distance * 0.75


# ====================================
# LEDGE CLIMB
# ====================================

func _check_ledge_climb(space_state: PhysicsDirectSpaceState2D) -> void:
	"""QOL FEATURE: Detect if player is near a climbable ledge and initiate climb."""
	# Don't start a new climb if already climbing
	if is_ledge_climbing:
		return
	
	# Don't allow ledge climb if on cooldown (prevents hover bug)
	if ledge_climb_cooldown_timer > 0:
		return
	
	# Require sprint state (speed > threshold) to perform ledge climb
	if not is_running:
		return
	
	# Only check when airborne and near a wall
	if not is_on_wall:
		return
	
	# Get collision shape for positioning raycasts
	var collision_shape = $CollisionShape2D
	if not collision_shape or not collision_shape.shape:
		return
	
	var shape = collision_shape.shape as RectangleShape2D
	if not shape:
		return
	
	var half_width = shape.size.x / 2.0
	var half_height = shape.size.y / 2.0
	
	# Determine which side the wall is on
	var wall_side = -wall_normal.x  # -1 for left wall, 1 for right wall
	var check_x_offset = half_width * wall_side
	
	# Check if there's a ledge above (wall ends within detection range)
	var ledge_found := false
	var ledge_height := 0.0
	
	# Cast multiple rays upward to find where the wall ends (optimized: check every 4 pixels instead of 2)
	for height_offset in range(int(ledge_climb_min_height), int(ledge_climb_detection_height), 4):
		var ray_origin = global_position + Vector2(check_x_offset, -half_height - height_offset)
		var ray_end = ray_origin + Vector2(wall_check_distance * wall_side, 0)
		
		var query = PhysicsRayQueryParameters2D.create(ray_origin, ray_end)
		query.exclude = [self]
		var hit = space_state.intersect_ray(query)
		
		# If no wall detected at this height, we found the ledge top
		if not hit:
			ledge_height = height_offset
			
			# Now check if there's solid ground on top of the ledge
			var ground_check_origin = global_position + Vector2(check_x_offset + ledge_climb_forward_offset * wall_side, -half_height - height_offset)
			var ground_check_end = ground_check_origin + Vector2(0, half_height + 4)
			
			var ground_query = PhysicsRayQueryParameters2D.create(ground_check_origin, ground_check_end)
			ground_query.exclude = [self]
			var ground_hit = space_state.intersect_ray(ground_query)
			
			# If we found ground on top, this is a valid ledge
			if ground_hit:
				ledge_found = true
				# Calculate target position on top of ledge
				ledge_climb_target_pos = Vector2(
					global_position.x + (ledge_climb_forward_offset + half_width + 2) * wall_side,
					ground_hit.position.y - half_height - 1
				)
				break
	
	# Start the ledge climb if a valid ledge was found
	if ledge_found:
		_start_ledge_climb()


func _start_ledge_climb() -> void:
	"""Initiate the ledge climb animation."""
	is_ledge_climbing = true
	ledge_climb_progress = 0.0
	ledge_climb_start_pos = global_position
	
	# Store horizontal velocity if momentum preservation is enabled
	if ledge_climb_preserve_momentum:
		ledge_climb_stored_velocity = velocity.x
	else:
		ledge_climb_stored_velocity = 0.0
	
	# Zero out velocity (will be restored/applied later)
	velocity = Vector2.ZERO
	is_jumping = false
	is_wall_sliding = false
	# Could trigger climb effects here (animation, sound, etc.)


func _process_ledge_climb(delta: float) -> void:
	"""Smoothly animate the player climbing up the ledge."""
	# Advance climb progress
	ledge_climb_progress += delta / ledge_climb_duration
	
	# Clamp progress to 0-1 range
	ledge_climb_progress = min(ledge_climb_progress, 1.0)
	
	# Use ease-out curve for smooth deceleration at the end
	var ease_progress = _ease_out_cubic(ledge_climb_progress)
	
	# Calculate the movement needed this frame using velocity-based approach
	var current_target = ledge_climb_start_pos.lerp(ledge_climb_target_pos, ease_progress)
	var movement_delta = current_target - global_position
	
	# Convert position delta to velocity for this frame
	if delta > 0:
		velocity.y = movement_delta.y / delta
	else:
		velocity.y = 0.0
	
	# Apply horizontal momentum during climb if enabled
	if ledge_climb_preserve_momentum and ledge_climb_apply_momentum_during:
		# Apply retained horizontal velocity during climb
		var applied_velocity = ledge_climb_stored_velocity * ledge_climb_momentum_retention
		velocity.x = applied_velocity
	else:
		# Use the calculated horizontal movement from lerp
		if delta > 0:
			velocity.x = movement_delta.x / delta
		else:
			velocity.x = 0.0
	
	# Finish climb when progress reaches 1.0
	if ledge_climb_progress >= 1.0:
		_finish_ledge_climb()


func _finish_ledge_climb() -> void:
	"""Complete the ledge climb and return to normal movement."""
	is_ledge_climbing = false
	ledge_climb_progress = 0.0
	
	# Set cooldown to prevent immediate re-trigger (fixes hover bug)
	ledge_climb_cooldown_timer = 0.3  # 0.3 second cooldown
	
	# Restore horizontal velocity with momentum preservation
	if ledge_climb_preserve_momentum:
		# Apply retained velocity
		var restored_velocity = ledge_climb_stored_velocity * ledge_climb_momentum_retention
		
		# Ensure minimum exit speed in the direction of movement
		if abs(restored_velocity) < ledge_climb_min_exit_speed and ledge_climb_stored_velocity != 0.0:
			restored_velocity = sign(ledge_climb_stored_velocity) * ledge_climb_min_exit_speed
		
		velocity.x = restored_velocity
		velocity.y = 0.0
		
		# Activate grace period to protect momentum from immediate deceleration
		ledge_climb_grace_timer = ledge_climb_momentum_grace_period
	else:
		# No momentum preservation - zero velocity
		velocity = Vector2.ZERO
	
	# Clear stored velocity
	ledge_climb_stored_velocity = 0.0
	
	# Could trigger landing effects here (particles, sound, etc.)


func _ease_out_cubic(t: float) -> float:
	"""Ease-out cubic function for smooth deceleration."""
	var f = t - 1.0
	return f * f * f + 1.0


# ====================================
# KICK ATTACK
# ====================================

func _update_enemy_detection() -> void:
	"""Detect nearby enemies for potential attacks."""
	nearby_enemies.clear()
	
	# Get all enemies in the scene - try both group names
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		enemies = get_tree().get_nodes_in_group("enemy")
	
	# Also try finding by node name as fallback
	if enemies.is_empty():
		var all_nodes = get_tree().get_nodes_in_group("_")
		for node in all_nodes:
			if node.name.to_lower().contains("enemy"):
				enemies.append(node)
	
	# Final fallback: search by node name directly
	if enemies.is_empty():
		var enemy_node = get_tree().get_first_node_in_group("enemies")
		if enemy_node:
			enemies.append(enemy_node)
		else:
			# Try to find enemy by name
			var enemy_by_name = get_node_or_null("/root/Level/Enemy")
			if enemy_by_name:
				enemies.append(enemy_by_name)
	
	# Debug: Print enemy detection results (only when debugging)
	# if Engine.get_process_frames() % 60 == 0:  # Print every 60 frames (1 second)
	#	print("Enemy detection - found ", enemies.size(), " total enemies")
	
	# Check each enemy for distance and filter out destroyed enemies
	for enemy in enemies:
		if enemy and is_instance_valid(enemy) and not enemy.is_destroyed:
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= attack_detection_range:
				nearby_enemies.append(enemy)
	
	# Debug output (only when debugging)
	# if nearby_enemies.size() > 0 and Engine.get_process_frames() % 60 == 0:
	#	print("Found ", nearby_enemies.size(), " nearby enemies")


func _update_attack_indicator() -> void:
	"""Update the visual indicator showing knockback direction when near enemies."""
	# Clear previous targeted enemy outline if it changed
	if last_targeted_enemy and is_instance_valid(last_targeted_enemy):
		if last_targeted_enemy.has_method("set_targeted"):
			last_targeted_enemy.set_targeted(false)
	
	if nearby_enemies.is_empty():
		attack_visual.visible = false
		last_targeted_enemy = null
		return
	
	# Find the closest enemy (filter out destroyed enemies)
	var closest_enemy = null
	var closest_distance = INF
	
	for enemy in nearby_enemies:
		# Skip destroyed enemies
		if not enemy or not is_instance_valid(enemy) or enemy.is_destroyed:
			continue
		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy
	
	if closest_enemy:
		# Set this enemy as targeted (shows shaking red outline)
		if closest_enemy.has_method("set_targeted"):
			closest_enemy.set_targeted(true)
		last_targeted_enemy = closest_enemy
		
		# Calculate knockback direction (AWAY from enemy)
		var direction_to_enemy = (closest_enemy.global_position - global_position).normalized()
		var knockback_direction = -direction_to_enemy  # Opposite direction
		
		# Calculate knockback distance based on speed and duration
		var knockback_distance = attack_knockback_speed * attack_duration
		var knockback_end_pos = global_position + knockback_direction * knockback_distance
		
		# Convert global positions to local coordinates for Line2D
		var start_pos = Vector2.ZERO  # Player position in local space
		var end_pos = to_local(knockback_end_pos)
		
		# Update visual indicator with knockback line (shows where player will fly)
		attack_indicator.points = PackedVector2Array([
			start_pos,
			end_pos
		])
		
		# Position target marker at closest enemy
		attack_target_marker.global_position = closest_enemy.global_position
		
		attack_visual.visible = true
	else:
		attack_visual.visible = false
		last_targeted_enemy = null


func _handle_kick_input() -> void:
	"""Process kick input - prioritize bullet parry > objects > enemies."""
	# Can't kick when stunned
	if is_stunned:
		return
	
	# Can only kick if not on cooldown and not already attacking
	if is_attacking or attack_cooldown_timer > 0:
		return
	
	# Check for kick input (mapped to 'j' key)
	if Input.is_action_just_pressed("melee_attack"):
		# Priority 1: Parry bullet if one is available
		if parry_enabled and closest_bullet:
			_parry_bullet(closest_bullet)
		# Priority 2: Kick object if one is available
		elif kick_object_enabled and closest_kickable_object:
			_kick_object(closest_kickable_object)
		# Priority 3: Attack enemy if available
		elif attack_enabled and not nearby_enemies.is_empty():
			_start_attack()


func _start_attack() -> void:
	"""Initiate a kick attack that sends player away from the closest enemy."""
	# Find the closest enemy (filter out destroyed enemies)
	var closest_enemy = null
	var closest_distance = INF
	
	for enemy in nearby_enemies:
		# Skip destroyed enemies
		if not enemy or not is_instance_valid(enemy) or enemy.is_destroyed:
			continue
		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy
	
	if not closest_enemy:
		return
	
	# Set up attack state
	is_attacking = true
	attack_timer = 0.0
	attack_target_enemy = closest_enemy
	
	# Calculate direction to enemy and knockback direction (AWAY from enemy)
	var direction_to_enemy = (closest_enemy.global_position - global_position).normalized()
	attack_direction = -direction_to_enemy  # Player flies AWAY from enemy
	
	# Update facing direction toward the enemy (for the kick animation)
	if direction_to_enemy.x != 0:
		facing_direction = sign(direction_to_enemy.x)
	
	# Set knockback velocity (send player away from enemy)
	attack_velocity = attack_direction * attack_knockback_speed
	velocity = attack_velocity
	
	# Kick the enemy and send them flying
	if closest_enemy.has_method("kick"):
		# Kick enemy in direction away from player
		var enemy_knockback_direction = direction_to_enemy  # Enemy flies away from player
		closest_enemy.kick(enemy_knockback_direction, attack_enemy_knockback_force)
	
	# Hide attack indicator during attack
	attack_visual.visible = false
	
	# Cancel other states
	is_jumping = false
	is_diving = false
	# Hide dive attack visual
	if dive_attack_visual:
		dive_attack_visual.visible = false
	if is_ground_sliding:
		_end_ground_slide()
	if is_air_dashing:
		_end_air_dash()
	
	print("[KICK ATTACK] Started - player knockback direction: ", attack_direction, " speed: ", attack_velocity.length())
	
	# Could trigger attack effects here (animation, sound, screen shake, etc.)


func _process_attack(delta: float) -> void:
	"""Update attack state - maintain knockback momentum."""
	attack_timer += delta
	
	# Check if attack duration has elapsed
	if attack_timer >= attack_duration:
		_end_attack()
		return
	
	# Maintain knockback velocity (allow slight gravity to make it feel more natural)
	# Apply reduced gravity during attack so it's not completely locked
	if not is_on_floor():
		velocity.y += gravity * 0.3 * delta  # 30% gravity during attack
		velocity.y = min(velocity.y, max_fall_speed)  # Still respect terminal velocity
	
	# Keep horizontal momentum from attack
	velocity.x = attack_velocity.x
	
	# Debug output
	if int(attack_timer * 10) != int((attack_timer - delta) * 10):  # Every 0.1 seconds
		print("[KICK ATTACK] Knockback - timer: %.2f/%.2f, velocity: %s" % [attack_timer, attack_duration, velocity])


func _end_attack() -> void:
	"""Complete the attack and preserve momentum."""
	is_attacking = false
	attack_timer = 0.0
	attack_cooldown_timer = attack_cooldown
	attack_target_enemy = null
	
	# PRESERVE MOMENTUM: Keep knockback velocity with retention multiplier
	# This makes the attack feel like it flows into your movement
	velocity.x = attack_velocity.x * attack_momentum_retention
	
	# If on ground, maintain more horizontal velocity
	# If in air, gravity will naturally take over for vertical
	if is_on_floor():
		# Ground attack - keep most of horizontal momentum
		velocity.y = 0.0
	
	print("[KICK ATTACK] Ended - final velocity: ", velocity, " (retained ", attack_momentum_retention * 100, "% momentum)")
	
	# Could trigger attack end effects here (animation, sound, trail fade, etc.)


# ====================================
# STUN SYSTEM
# ====================================

func _process_stun(delta: float) -> void:
	"""Update stun state - player falls to ground and can't move, rotates horizontal and shakes."""
	# Remove previous shake offset before physics
	global_position -= stun_shake_offset
	
	# Apply gravity to make player fall
	_apply_gravity(delta)
	
	# Stop horizontal movement
	velocity.x = 0.0
	
	# Rotate player to horizontal (90 degrees)
	rotation = PI / 2.0
	
	# Visual feedback: make player flash red
	var flash = sin(stun_timer * 20.0) * 0.5 + 0.5
	modulate = Color(1.0, flash, flash, 1.0)


func _start_stun(colliding_enemy: Node2D = null) -> void:
	"""Start the stun effect when player touches enemy without attacking - but with grace period first."""
	# Start grace period instead of immediate stun
	grace_period_active = true
	grace_period_timer = grace_period_duration
	grace_period_colliding_enemy = colliding_enemy
	
	print("Grace period started! Press kick within ", grace_period_duration, " seconds to cancel stun!")


func _apply_stun_after_grace_period() -> void:
	"""Apply stun after grace period expires without kick input."""
	grace_period_active = false
	grace_period_timer = 0.0
	grace_period_colliding_enemy = null
	
	# Now actually stun the player
	is_stunned = true
	stun_timer = stun_duration
	
	# Stop all movement
	velocity = Vector2.ZERO
	
	# Cancel other states
	is_attacking = false
	is_diving = false
	is_ledge_climbing = false
	# Hide dive attack visual
	if dive_attack_visual:
		dive_attack_visual.visible = false
	if is_ground_sliding:
		_end_ground_slide()
	if is_air_dashing:
		_end_air_dash()
	
	print("Player stunned for ", stun_duration, " seconds!")


func _cancel_grace_period_with_kick() -> void:
	"""Cancel grace period and perform kick attack instead."""
	print("Grace period cancelled! Performing kick attack!")
	
	# Clear grace period state
	grace_period_active = false
	grace_period_timer = 0.0
	
	# Temporarily add the enemy to nearby_enemies if it's not already there
	var enemy = grace_period_colliding_enemy
	grace_period_colliding_enemy = null
	
	if enemy and is_instance_valid(enemy) and not enemy.is_destroyed:
		# Make sure the enemy is in the nearby_enemies array
		if not nearby_enemies.has(enemy):
			nearby_enemies.append(enemy)
		
		# Perform the attack
		_start_attack()


func _end_stun() -> void:
	"""End the stun effect and start invulnerability period."""
	# Remove any remaining shake offset
	global_position -= stun_shake_offset
	stun_shake_offset = Vector2.ZERO
	
	is_stunned = false
	stun_timer = 0.0
	
	# Reset rotation to upright
	rotation = 0.0
	
	# Reset visual feedback
	modulate = Color.WHITE
	
	# Start invulnerability period
	stun_invulnerability_timer = stun_invulnerability_duration
	
	print("Player stun ended! Invulnerable for ", stun_invulnerability_duration, " seconds!")


func _on_enemy_touched(enemy: Node2D = null) -> void:
	"""Called when player touches an enemy without attacking."""
	# Check for invulnerability from dashes, already stunned, grace period active, or post-stun invulnerability
	if not is_attacking and not is_stunned and not is_invulnerable and not grace_period_active and stun_invulnerability_timer <= 0:
		_start_stun(enemy)


func _on_enemy_destroyed() -> void:
	"""Called when an enemy is destroyed by attack."""
	print("Enemy destroyed by attack!")


func _on_bullet_hit(bullet: Node2D, shooter: Node2D = null) -> void:
	"""Called when player is hit by a bullet - starts grace period for parry."""
	# Check for invulnerability from dashes, already stunned, grace periods active, or post-stun invulnerability
	if not is_attacking and not is_stunned and not is_invulnerable and not grace_period_active and not bullet_grace_period_active and stun_invulnerability_timer <= 0:
		# Start bullet grace period
		bullet_grace_period_active = true
		bullet_grace_period_timer = bullet_hit_grace_period
		bullet_that_hit = bullet
		
		print("[BULLET HIT] Grace period started! Press kick within ", bullet_hit_grace_period, " seconds to parry!")


func _apply_bullet_hitstun() -> void:
	"""Apply hitstun after bullet grace period expires without parry."""
	bullet_grace_period_active = false
	bullet_grace_period_timer = 0.0
	bullet_that_hit = null
	
	# Apply stun effect (same as enemy touch)
	_on_enemy_touched(null)
	
	print("[BULLET HIT] Grace period expired - hitstun applied!")


func _cancel_bullet_grace_period_with_parry() -> void:
	"""Cancel bullet grace period by parrying nearby bullets."""
	print("[BULLET HIT] Grace period cancelled! Performing parry!")
	
	# Clear bullet grace period state
	bullet_grace_period_active = false
	bullet_grace_period_timer = 0.0
	bullet_that_hit = null
	
	# Detect and parry nearby bullets
	_update_bullet_detection()
	
	if closest_bullet and is_instance_valid(closest_bullet):
		# Parry the closest bullet
		_parry_bullet(closest_bullet)
	else:
		# No bullets to parry - just give brief invulnerability as reward
		stun_invulnerability_timer = 0.3
		print("[BULLET PARRY] No bullets to parry, but hitstun cancelled!")


# ====================================
# GROUND SLIDE & AIR DASH
# ====================================

func _start_ground_slide(input_x: float) -> void:
	"""Initiate a ground slide with reduced height."""
	# Determine slide direction
	if abs(input_x) > 0.1:
		dash_direction = sign(input_x)
	else:
		dash_direction = facing_direction
	
	# Start ground slide
	is_ground_sliding = true
	ground_slide_timer = 0.0
	ground_slide_cooldown_timer = ground_slide_cooldown
	is_slide_jump_available = true
	is_invulnerable = true  # Player is invulnerable during slide
	
	# Set velocity to slide speed
	velocity.x = dash_direction * ground_slide_speed
	velocity.y = 0  # Snap to ground
	
	# Reduce collision shape height
	_set_collision_height(original_collision_shape_height * ground_slide_height_reduction)
	
	# Update facing direction
	facing_direction = dash_direction
	
	# Cancel other states
	is_jumping = false
	is_wall_sliding = false
	is_diving = false
	# Hide dive attack visual
	if dive_attack_visual:
		dive_attack_visual.visible = false
	
	# End wall run if sliding
	if is_wall_running:
		_end_wall_run()
	
	print("[GROUND SLIDE] Started - direction: ", dash_direction, " speed: ", ground_slide_speed)
	
	# Could trigger slide effects here (particles, sound, animation, etc.)


func _process_ground_slide(delta: float) -> void:
	"""Update ground slide state - maintain velocity and check for end."""
	# Increment timer
	ground_slide_timer += delta
	
	# Check if slide duration has elapsed
	if ground_slide_timer >= ground_slide_duration:
		_end_ground_slide()
		return
	
	# Maintain slide velocity (horizontal only)
	velocity.x = dash_direction * ground_slide_speed
	
	# If player leaves ground during slide, end it
	if not is_on_floor():
		_end_ground_slide()
		return
	
	# Snap to ground
	velocity.y = ground_snap_force


func _end_ground_slide() -> void:
	"""End the ground slide and restore collision shape."""
	if not is_ground_sliding:
		return
	
	is_ground_sliding = false
	ground_slide_timer = 0.0
	is_slide_jump_available = false
	is_invulnerable = false  # End invulnerability
	
	# Restore collision shape height
	_set_collision_height(original_collision_shape_height)
	
	# Set horizontal speed to max speed
	velocity.x = dash_direction * ground_slide_end_speed
	
	print("[GROUND SLIDE] Ended - final speed: ", velocity.x)
	
	# Could trigger slide end effects here (particles fade, etc.)


func _start_air_dash(input_x: float) -> void:
	"""Initiate an air dash with horizontal-only movement."""
	# Store pre-dash horizontal speed
	pre_air_dash_horizontal_speed = velocity.x
	
	# Determine dash direction
	if abs(input_x) > 0.1:
		dash_direction = sign(input_x)
	else:
		dash_direction = facing_direction
	
	# Start air dash
	is_air_dashing = true
	air_dash_timer = 0.0
	air_dash_cooldown_timer = air_dash_cooldown
	is_invulnerable = true  # Player is invulnerable during air dash
	
	# Set velocity to air dash speed (horizontal only)
	velocity.x = dash_direction * air_dash_speed
	velocity.y = 0  # Cancel vertical velocity
	
	# Update facing direction
	facing_direction = dash_direction
	
	# Cancel other states
	is_jumping = false
	is_wall_sliding = false
	is_diving = false
	# Hide dive attack visual
	if dive_attack_visual:
		dive_attack_visual.visible = false
	
	# End wall run if air dashing
	if is_wall_running:
		_end_wall_run()
	
	print("[AIR DASH] Started - direction: ", dash_direction, " speed: ", air_dash_speed, " pre-dash speed: ", pre_air_dash_horizontal_speed)
	
	# Could trigger air dash effects here (particles, sound, animation, etc.)


func _process_air_dash(delta: float) -> void:
	"""Update air dash state - maintain horizontal velocity, no gravity."""
	# Increment timer
	air_dash_timer += delta
	
	# Check if air dash duration has elapsed
	if air_dash_timer >= air_dash_duration:
		_end_air_dash()
		return
	
	# Maintain air dash velocity (horizontal only, no gravity)
	velocity.x = dash_direction * air_dash_speed
	velocity.y = 0  # No vertical movement during air dash


func _end_air_dash() -> void:
	"""End the air dash and set horizontal speed to fixed value."""
	if not is_air_dashing:
		return
	
	is_air_dashing = false
	air_dash_timer = 0.0
	is_invulnerable = false  # End invulnerability
	
	# Set horizontal speed to fixed 1000 in the dash direction
	velocity.x = dash_direction * 1000.0
	
	# Cancel vertical velocity
	velocity.y = 0
	
	print("[AIR DASH] Ended - set speed to: ", velocity.x, " vertical speed canceled")
	
	# Could trigger air dash end effects here (particles fade, etc.)


func _set_collision_height(new_height: float) -> void:
	"""Adjust the collision shape height and visual polygon."""
	var collision_shape = $CollisionShape2D
	if not collision_shape or not collision_shape.shape:
		return
	
	var shape = collision_shape.shape as RectangleShape2D
	if not shape:
		return
	
	# Store the original width
	var width = shape.size.x
	
	# Set new size
	shape.size = Vector2(width, new_height)
	
	# Adjust position to keep the bottom of the collision shape at the same place
	var height_diff = original_collision_shape_height - new_height
	collision_shape.position.y = height_diff / 2.0
	
	# Update visual polygon to match collision shape
	var visual = $Visual
	if visual and visual is Polygon2D:
		var half_width = width / 2.0
		var half_height = new_height / 2.0
		var y_offset = height_diff / 2.0
		
		# Update polygon points to match new height
		visual.polygon = PackedVector2Array([
			Vector2(-half_width, -half_height + y_offset),
			Vector2(half_width, -half_height + y_offset),
			Vector2(half_width, half_height + y_offset),
			Vector2(-half_width, half_height + y_offset)
		])


# ====================================
# DIVE
# ====================================

func _start_dive(input_vector: Vector2) -> void:
	"""Initiate a dive at configured angle with fixed speed."""
	# Determine dive direction based on current movement or facing direction
	var dive_direction: float = 0.0
	if abs(velocity.x) > 10.0:
		dive_direction = sign(velocity.x)
	else:
		dive_direction = facing_direction
	
	# Calculate fixed dive speed components based on angle
	var angle_rad = deg_to_rad(dive_angle_degrees)
	var horizontal_component = dive_speed * cos(angle_rad) * dive_direction
	var vertical_component = dive_speed * sin(angle_rad)
	
	# Set dive velocity
	dive_velocity = Vector2(horizontal_component, vertical_component)
	velocity = dive_velocity
	
	# Store horizontal velocity (with direction) for landing boost
	dive_pre_landing_horizontal_speed = horizontal_component
	
	# Set dive state
	is_diving = true
	
	# Show dive attack visual indicator
	if dive_attack_visual:
		_update_dive_attack_visual()  # Update visual to match current range
		dive_attack_visual.visible = true
	
	# Cancel other states
	is_jumping = false
	is_wall_sliding = false
	if is_ground_sliding:
		_end_ground_slide()
	if is_air_dashing:
		_end_air_dash()
	
	# Update facing direction
	if horizontal_component != 0:
		facing_direction = sign(horizontal_component)
	
	# Could trigger dive effects here (particles, sound, animation, etc.)


func _process_dive(delta: float) -> void:
	"""Update dive state - maintain dive velocity until landing."""
	# Check for enemies within range for dive attack (anywhere except upper 90 degrees)
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy) and not enemy.is_destroyed:
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= dive_attack_range:
				# Check if enemy is NOT in the upper 90-degree cone
				# Calculate angle from player to enemy
				var direction_to_enemy = enemy.global_position - global_position
				var angle_to_enemy = atan2(direction_to_enemy.y, direction_to_enemy.x)
				
				# Convert to degrees (0-360 range)
				var angle_degrees = rad_to_deg(angle_to_enemy)
				if angle_degrees < 0:
					angle_degrees += 360
				
				# Upper 90 degrees is from 225 to 315 degrees (centered on 270 = straight up)
				# Allow hit if NOT in upper 90 degree cone
				var is_in_upper_cone = angle_degrees >= 225 and angle_degrees <= 315
				
				if not is_in_upper_cone:
					# Dive attack! Hit enemy
					_perform_dive_attack(enemy)
					return
	
	# Maintain dive velocity (no gravity, no air control)
	velocity = dive_velocity
	
	# Check if we hit the ground
	if is_on_floor():
		# Landing is handled in _on_landed()
		return
	
	# Check if we hit a wall (cancel dive)
	if is_on_wall:
		is_diving = false
		dive_pre_landing_horizontal_speed = 0.0
		# Hide dive attack visual
		if dive_attack_visual:
			dive_attack_visual.visible = false
		# Allow normal physics to take over
		# Dive cancelled by wall collision


func _perform_dive_attack(enemy: Node2D) -> void:
	"""Execute a dive attack on an enemy - bounce player upward and destroy enemy."""
	print("[DIVE ATTACK] Hit enemy at: ", enemy.global_position)
	
	# Kick the enemy downwards (destroy it)
	if enemy.has_method("kick"):
		# Kick enemy downwards with dive attack knockback speed
		var downward_direction = Vector2.DOWN
		enemy.kick(downward_direction, dive_attack_knockback_speed)
	
	# End dive state
	is_diving = false
	dive_pre_landing_horizontal_speed = 0.0
	
	# Hide dive attack visual
	if dive_attack_visual:
		dive_attack_visual.visible = false
	
	# Retain horizontal velocity
	var horizontal_vel = velocity.x
	
	# Lose all vertical velocity and gain upward impulse
	velocity.x = horizontal_vel
	velocity.y = -dive_attack_bounce_impulse  # Upward impulse when hitting enemy
	
	# Set jumping state to allow player control
	is_jumping = true
	
	print("[DIVE ATTACK] Bounce! New velocity: ", velocity)
	
	# Could trigger dive attack effects here (particles, sound, screen shake, etc.)


# ====================================
# POST-MOVEMENT
# ====================================

func _post_movement_updates() -> void:
	"""Handle any post-movement state updates."""
	# Handle ceiling collision (stop upward movement)
	if is_on_ceiling() and velocity.y < 0:
		velocity.y = 0
		is_jumping = false
	
	# Apply shake effect after physics when stunned
	if is_stunned:
		# Generate new shake offset
		stun_shake_offset = Vector2(
			randf_range(-stun_shake_intensity, stun_shake_intensity),
			randf_range(-stun_shake_intensity, stun_shake_intensity)
		)
		# Apply shake to position (will be removed at start of next frame)
		global_position += stun_shake_offset


# ====================================
# KICK OBJECT MECHANICS
# ====================================

func _update_kickable_object_detection() -> void:
	"""Detect kickable objects in front of player within cone angle."""
	nearby_kickable_objects.clear()
	closest_kickable_object = null
	
	# Get all kickable objects
	var objects = get_tree().get_nodes_in_group("kickable_objects")
	
	# Calculate facing direction vector
	var facing_vec = Vector2(facing_direction, 0)
	
	for obj in objects:
		if obj and is_instance_valid(obj) and obj.has_method("can_be_kicked") and obj.can_be_kicked():
			# Check distance
			var distance = global_position.distance_to(obj.global_position)
			if distance <= kick_object_detection_range:
				# Check if object is in front of player (not behind)
				var direction_to_obj = (obj.global_position - global_position).normalized()
				var dot_product = facing_vec.dot(direction_to_obj)
				
				# Check cone angle - dot product > cos(angle/2) means within cone
				var half_cone_angle = deg_to_rad(kick_object_cone_angle / 2.0)
				var cone_threshold = cos(half_cone_angle)
				
				if dot_product > cone_threshold:
					nearby_kickable_objects.append(obj)


func _update_kick_object_indicator() -> void:
	"""Update visual indicator for kick object direction."""
	if not object_kick_indicator:
		return
	
	# Find closest kickable object in front
	closest_kickable_object = null
	var closest_distance = INF
	
	for obj in nearby_kickable_objects:
		if obj and is_instance_valid(obj):
			var distance = global_position.distance_to(obj.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_kickable_object = obj
	
	# Show indicator if object found
	if closest_kickable_object:
		object_kick_indicator.visible = true
		
		# Draw arrow from player to object
		var start_pos = Vector2.ZERO
		var end_pos = to_local(closest_kickable_object.global_position)
		
		object_kick_indicator.points = PackedVector2Array([start_pos, end_pos])
	else:
		object_kick_indicator.visible = false


func _kick_object(obj: Node2D) -> void:
	"""Kick a kickable object in the facing direction."""
	if not obj or not is_instance_valid(obj):
		return
	
	if not obj.has_method("kick"):
		return
	
	# Calculate kick direction (horizontal, in facing direction)
	var kick_direction = Vector2(facing_direction, 0)
	
	# Kick the object
	obj.kick(kick_direction, kick_object_speed)
	
	# Set cooldown
	attack_cooldown_timer = attack_cooldown
	
	print("[KICK OBJECT] Kicked object: ", obj.name, " direction: ", kick_direction, " speed: ", kick_object_speed)


# ====================================
# AFTERIMAGE EFFECT
# ====================================

func _spawn_afterimage() -> void:
	"""Spawn an afterimage at the player's current position."""
	# Create a new afterimage instance
	var afterimage = AfterimageScene.instantiate()
	
	# Set the afterimage's position to match the player
	afterimage.global_position = global_position
	
	# Set the afterimage to start green (it will fade to red over its lifetime)
	if afterimage.has_node("Polygon2D"):
		var afterimage_polygon = afterimage.get_node("Polygon2D")
		# Start with bright green color
		afterimage_polygon.color = Color(0.2, 1.0, 0.2, 0.6)  # Green with 60% opacity
	
	# Add the afterimage to the scene (as a sibling of the player, not a child)
	# This prevents the afterimage from moving with the player
	get_parent().add_child(afterimage)


# ====================================
# BULLET PARRY MECHANICS
# ====================================

func _create_bullet_parry_indicator() -> void:
	"""Create the visual indicator for parryable bullets."""
	bullet_parry_indicator = Line2D.new()
	bullet_parry_indicator.name = "BulletParryIndicator"
	bullet_parry_indicator.width = 4.0
	bullet_parry_indicator.default_color = Color(0.2, 1.0, 1.0, 0.9)  # Bright cyan
	bullet_parry_indicator.visible = false
	add_child(bullet_parry_indicator)

func _update_bullet_detection() -> void:
	"""Detect bullets near the player that can be parried."""
	nearby_bullets.clear()
	closest_bullet = null
	
	# Get all enemy projectiles
	var bullets = get_tree().get_nodes_in_group("enemy_projectiles")
	
	# Calculate facing direction vector
	var facing_vec = Vector2(facing_direction, 0)
	
	for bullet in bullets:
		if bullet and is_instance_valid(bullet) and bullet.has_method("parry"):
			# Check if bullet can be parried
			if "can_be_parried" in bullet and not bullet.can_be_parried:
				continue
			
			# Check distance
			var distance = global_position.distance_to(bullet.global_position)
			if distance <= parry_detection_range:
				# Check if bullet is in front of player (within cone angle)
				var direction_to_bullet = (bullet.global_position - global_position).normalized()
				var dot_product = facing_vec.dot(direction_to_bullet)
				
				# Check cone angle - dot product > cos(angle/2) means within cone
				var half_cone_angle = deg_to_rad(parry_angle_cone / 2.0)
				var cone_threshold = cos(half_cone_angle)
				
				if dot_product > cone_threshold:
					nearby_bullets.append(bullet)

func _update_bullet_parry_indicator() -> void:
	"""Update visual indicator for parryable bullet."""
	if not bullet_parry_indicator:
		return
	
	# Find closest bullet in front
	closest_bullet = null
	var closest_distance = INF
	
	for bullet in nearby_bullets:
		if bullet and is_instance_valid(bullet):
			var distance = global_position.distance_to(bullet.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_bullet = bullet
	
	# Show indicator if bullet found
	if closest_bullet:
		bullet_parry_indicator.visible = true
		
		# Draw line from player to bullet with arrow-like appearance
		var start_pos = Vector2.ZERO
		var bullet_pos = to_local(closest_bullet.global_position)
		
		# Create arrow points
		var points = PackedVector2Array()
		points.append(start_pos)
		points.append(bullet_pos)
		
		bullet_parry_indicator.points = points
	else:
		bullet_parry_indicator.visible = false

func _parry_bullet(bullet: Node2D) -> void:
	"""Parry a bullet - redirect it back towards the enemy that shot it."""
	if not bullet or not is_instance_valid(bullet):
		return
	
	if not bullet.has_method("parry"):
		return
	
	# Calculate parry direction (towards enemy or reverse bullet direction)
	var parry_direction = (bullet.global_position - global_position).normalized()
	
	# Call bullet's parry method
	bullet.parry(parry_direction)
	
	# Set cooldown
	attack_cooldown_timer = attack_cooldown
	
	# Visual feedback - brief flash
	modulate = Color(0.3, 1.5, 1.5)  # Cyan flash
	await get_tree().create_timer(0.1).timeout
	if not is_stunned:  # Only reset if not in another state
		modulate = Color.WHITE
	
	print("[BULLET PARRY] Parried bullet! Redirecting towards enemy")
