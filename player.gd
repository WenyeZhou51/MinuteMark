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

# REWIND SHADOW
const ShadowScene = preload("res://shadow.tscn")

# DUST PARTICLES
const DustParticlesScene = preload("res://dust_particles.tscn")

# MOVEMENT CONFIGURATION
@export_group("Horizontal Movement")
@export var max_speed: float = 300.0  ## Maximum horizontal movement speed
@export var ground_acceleration: float = 1500.0  ## Acceleration when on ground
@export var ground_deceleration: float = 2000.0  ## Deceleration when on ground (no input)
@export var air_acceleration: float = 800.0  ## Acceleration when airborne (reduced control)
@export var air_deceleration: float = 400.0  ## Deceleration when airborne (reduced control)
@export var sprint_speed_threshold: float = 1000.0  ## Speed required to enter sprint state
@export var run_speed_multiplier: float = 1.75  ## Speed multiplier when in sprint state
@export var run_acceleration_multiplier: float = 1.3  ## Acceleration multiplier when in sprint state
@export var run_activation_delay: float = 0.1  ## [UNUSED] Previously used for hold-to-sprint delay

@export_group("Afterimage Trail")
@export var trail_afterimage_interval: float = 0.05 ## Time between afterimage spawns in trail
@export var trail_max_speed_threshold: float = 1500.0 ## Speed at which 4 afterimages are shown

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
@export var stun_shake_intensity: float = 1.5  ## Intensity of shake effect during stun

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

@export_group("Animations")
@export_subgroup("Run")
@export var run_scale: float = 0.03
@export var run_fps: float = 24.0
@export var run_offset: Vector2 = Vector2.ZERO
@export_subgroup("Jump")
@export var jump_scale: float = 0.03
@export var jump_fps: float = 24.0
@export var jump_offset: Vector2 = Vector2.ZERO
@export_subgroup("Wall Run")
@export var wall_run_scale: float = 0.03
@export var wall_run_fps: float = 24.0
@export var wall_run_offset: Vector2 = Vector2.ZERO
@export var wall_run_base_flip: bool = true ## Flip the wall run animation 180 degrees by default

@export_subgroup("Ground Slide")
@export var ground_slide_scale: float = 0.03
@export var ground_slide_fps: float = 24.0
@export var ground_slide_offset: Vector2 = Vector2.ZERO
@export var ground_slide_speed: float = 1500.0  ## Speed during ground slide
@export var ground_slide_duration: float = 0.5  ## Duration of ground slide in seconds
@export var ground_slide_height_reduction: float = 0.5  ## Height reduction during slide (0.5 = 50% height)
@export var ground_slide_cooldown: float = 1.0  ## Cooldown between ground slides
@export var ground_slide_end_speed: float = 1000.0  ## Speed after slide ends
@export var ground_slide_empowered_jump_multiplier: float = 1.5  ## Jump height multiplier when jumping out of slide

@export_subgroup("Air Dash")
@export var air_dash_horizontal_impulse: float = 500.0  ## Horizontal impulse force applied at start of air dash
@export var air_dash_vertical_impulse: float = 100.0  ## Vertical impulse force applied at start of air dash
@export var air_dash_duration: float = 0.2  ## Duration of air dash in seconds
@export var air_dash_cooldown: float = 0.35  ## Cooldown between air dashes
@export var air_dash_end_horizontal_velocity: float = 1000.0  ## Horizontal velocity when air dash ends (in dash direction)
@export var air_dash_end_vertical_velocity: float = 0.0  ## Vertical velocity when air dash ends
@export var air_dash_afterimage_count: int = 7 ## Number of afterimages to spawn during dash
@export var air_dash_afterimage_lifetime: float = 0.4 ## How long each afterimage lasts
@export var air_dash_afterimage_alpha: float = 0.7 ## Initial transparency of afterimages

# KICK ATTACK CONFIGURATION
@export_group("Kick Attack")
@export var kick_scale: float = 0.03
@export var kick_fps: float = 24.0
@export var kick_offset: Vector2 = Vector2.ZERO
@export var attack_enabled: bool = true  ## Enable kick attack mechanics
@export var attack_detection_range: float = 80.0  ## Range to detect enemies for attack (smaller range)
@export var attack_knockback_speed: float = 700.0  ## Speed at which player is knocked back from enemy
@export var attack_duration: float = 0.2  ## Duration of the attack knockback (seconds)
@export var attack_momentum_retention: float = 0.6  ## How much momentum is kept after attack (0.0-1.0)
@export var attack_cooldown: float = 0.2  ## Cooldown between attacks
@export var attack_enemy_knockback_force: float = 2500.0  ## Force applied to enemy when kicked

# BULLET PARRY CONFIGURATION
@export_group("Bullet Parry")
@export var parry_enabled: bool = true  ## Enable bullet parry mechanics
@export var parry_detection_range: float = 100.0  ## Range to detect bullets for parrying
@export var parry_angle_cone: float = 120.0  ## Cone angle in front of player for bullet detection (degrees)
@export var bullet_hit_grace_period: float = 0.1  ## Time window to press kick after being hit by bullet to parry instead of taking hitstun (seconds)
@export var parry_early_grace_period: float = 0.15 ## Time window BEFORE getting hit or before bullet enters range to press kick (seconds)
@export var parry_time_scale: float = 0.2  ## Time scale during parry (0.2 = 80% slower, 1.0 = normal speed)
@export var parry_time_duration: float = 0.3  ## Duration of time slowdown effect during parry (seconds in real time)
@export var parry_vertical_boost: float = 300.0  ## Upward velocity boost given to player on successful parry

# KICK OBJECT CONFIGURATION
@export_group("Kick Object")
@export var kick_object_enabled: bool = true  ## Enable kicking objects
@export var kick_object_detection_range: float = 60.0  ## Range to detect kickable objects
@export var kick_object_speed: float = 2500.0  ## Speed at which kicked objects fly
@export var kick_object_cone_angle: float = 90.0  ## Cone angle in front of player for detection (degrees)
@export var kick_object_knockback_force: float = 100.0  ## Horizontal knockback force applied to player when kicking an object

# GROUND SLAM CONFIGURATION
@export_group("Ground Slam")
@export var slam_enabled: bool = true  ## Enable ground slam mechanics
@export var slam_speed: float = 3000.0  ## Vertical downward speed during slam (adjustable)
@export var slam_kill_radius: float = 500.0  ## Radius to kill enemies while slamming down (5m = ~500 pixels)
@export var slam_landing_aoe_width: float = 1000.0  ## Width of AOE damage on landing (10m = ~1000 pixels)
@export var slam_landing_aoe_height: float = 500.0  ## Height of AOE damage on landing (5m = ~500 pixels)
@export var slam_freeze_duration: float = 0.1  ## Duration player is frozen after slam landing (seconds)
@export var slam_landing_speed_boost: float = 1.15  ## Speed multiplier on landing (15% boost)
@export var slam_attack_knockback_speed: float = 2500.0  ## Speed at which enemies are knocked downward during slam
@export var slam_attack_bounce_impulse: float = 500.0  ## Upward velocity given to player when hitting enemy during slam

# REWIND CONFIGURATION
@export_group("Rewind")
@export var rewind_enabled: bool = true  ## Enable rewind mechanics
@export var rewind_time: float = 2.0  ## Seconds to rewind back in time
@export var rewind_cooldown: float = 3.0  ## Cooldown between rewinds (seconds)
@export var rewind_history_duration: float = 3.0  ## How long to keep state history (seconds)
@export var rewind_traceback_speed: float = 2.0  ## Speed of traceback while holding in slow-mo (2.0 = 2x relative to slow-mo time)
@export var rewind_slowmo_scale: float = 0.25  ## Time scale for slow-mo (0.25 = quarter speed)
@export var rewind_restore_velocity: bool = false  ## Whether to restore velocity when rewinding (false = zero velocity on rewind)

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

# Afterimage trail state
var trail_afterimage_timer: float = 0.0

# Wall jump state variables
var is_on_wall: bool = false  # Is player touching a wall
var wall_normal: Vector2 = Vector2.ZERO  # Direction pointing away from the wall
var is_wall_sliding: bool = false  # Is player currently sliding down a wall

# Wall run state variables
var is_wall_running: bool = false  # Is player currently wall running
var wall_run_timer: float = 0.0  # Time elapsed in current wall run
var wall_run_speed: float = 0.0  # Current upward speed during wall run
var wall_jump_cooldown: float = 0.0  # Cooldown after wall jump to prevent re-attachment
var wall_jump_forced_direction: float = 0.0  # Forced direction away from wall after jump
var wall_run_cooldown: float = 0.0  # Cooldown after wall run ends to prevent immediate restart
var wall_run_start_position: Vector2 = Vector2.ZERO  # Position when wall run started (for tracking total movement)
var wall_run_frame_count: int = 0  # Number of frames wall run has been active

# Ledge climb state variables
var is_ledge_climbing: bool = false  # Is player currently climbing a ledge
var ledge_climb_progress: float = 0.0  # Progress through climb animation (0.0 to 1.0)
var ledge_climb_start_pos: Vector2 = Vector2.ZERO  # Starting position of climb
var ledge_climb_target_pos: Vector2 = Vector2.ZERO  # Target position on top of ledge
var ledge_climb_stored_velocity: float = 0.0  # Stored horizontal velocity to preserve through climb
var ledge_climb_grace_timer: float = 0.0  # Timer for momentum protection after climb
var ledge_climb_cooldown_timer: float = 0.0  # Cooldown to prevent re-triggering same ledge

# Attack state variables
enum KickTargetType { NONE, ENEMY, OBJECT, BULLET }
var current_kick_target_type: KickTargetType = KickTargetType.NONE
var current_kick_target_node: Node2D = null
var kick_has_fired: bool = false
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
var early_parry_timer: float = 0.0  # Time remaining in early parry window (pressed kick before hit)
var bullet_that_hit: Node2D = null  # Bullet that triggered grace period
var parry_time_slowdown_active: bool = false  # Is time slowdown effect active from parry
var parry_time_slowdown_timer: float = 0.0  # Time remaining for time slowdown effect (real time)

# Dash state variables
var is_ground_sliding: bool = false  # Is player currently ground sliding
var is_air_dashing: bool = false  # Is player currently air dashing
var ground_slide_timer: float = 0.0  # Time elapsed in current ground slide
var air_dash_timer: float = 0.0  # Time elapsed in current air dash
var ground_slide_cooldown_timer: float = 0.0  # Cooldown timer for ground slide
var air_dash_cooldown_timer: float = 0.0  # Cooldown timer for air dash
var air_dash_afterimages_spawned: int = 0  # Counter for afterimages spawned during current dash
var dash_direction: float = 1.0  # Horizontal direction of dash (1 = right, -1 = left)
var pre_air_dash_horizontal_speed: float = 0.0  # Horizontal speed before air dash
var velocity_before_move_and_slide: Vector2 = Vector2.ZERO  # Velocity before move_and_slide() for collision detection
var original_collision_shape_height: float = 64.0  # Original height of collision shape
var is_slide_jump_available: bool = false  # Can player perform empowered jump from slide
var is_invulnerable: bool = false  # Is player currently invulnerable (during dashes)
var run_input_just_pressed: bool = false  # Track if run input was just pressed this frame
var air_dash_available: bool = true  # Is air dash available (resets on ground/wall/kick parry/slam)

# CAMERA SHAKE
var camera_shake_intensity: float = 0.0
var camera_shake_timer: float = 0.0
var camera_shake_type: String = "random" # "random" or "sine"

# Ground Slam state variables
var is_slamming: bool = false  # Is player currently ground slamming
var slam_velocity: Vector2 = Vector2.ZERO  # Velocity of the slam
var slam_pre_landing_horizontal_speed: float = 0.0  # Horizontal speed stored before landing
var slam_attack_visual: Node2D = null  # Visual indicator for slam attack range
var slam_range_circle: Polygon2D = null  # Circle showing slam kill radius
var is_slam_frozen: bool = false  # Is player frozen after slam landing
var slam_freeze_timer: float = 0.0  # Timer for slam freeze duration

# Stun state variables (internal - durations configured in Quality of Life section)
var is_stunned: bool = false  # Is player currently stunned
var stun_timer: float = 0.0  # Time remaining in stun
var stun_shake_offset: Vector2 = Vector2.ZERO  # Current shake offset applied to position
var stun_invulnerability_timer: float = 0.0  # Time remaining for post-stun invulnerability
var grace_period_timer: float = 0.0  # Time remaining in grace period
var grace_period_active: bool = false  # Is grace period currently active
var grace_period_colliding_enemy: Node2D = null  # Enemy that triggered grace period

# Rewind state variables
var rewind_cooldown_timer: float = 0.0  # Cooldown timer for rewind ability
var state_history: Array[Dictionary] = []  # Stores state snapshots with timestamps
var game_time: float = 0.0  # Total game time elapsed (for timestamping)
var is_rewind_tracing: bool = false  # Is player currently in rewind traceback animation
var is_rewind_holding: bool = false  # Is player currently holding R for rewind
var is_in_rewind_slowmo: bool = false  # Is game currently in rewind slow-mo
var original_time_scale: float = 1.0  # Store original time scale before slow-mo
var rewind_hold_start_time: float = 0.0  # When the hold started (game_time)
var rewind_current_progress: float = 0.0  # Current progress through rewind (0.0 = current, 1.0 = 2 seconds ago)
var rewind_traceback_frame_data: Array[Dictionary] = []  # Frames to animate through during traceback
var rewind_start_position: Vector2 = Vector2.ZERO  # Position when rewind started (for shadow path)
var rewind_start_time: float = 0.0  # Game time when rewind started
var rewind_target_time: float = 0.0  # Target time (2 seconds ago) for rewind
var rewind_path_visualization: Node2D = null  # Container for ghost path visuals
var ghost_markers: Array[Node2D] = []  # Array of ghost marker nodes
var grayscale_overlay: ColorRect = null  # Grayscale overlay for rewind effect

# Dust effect state
var dust_spawn_timer: float = 0.0

# Component references
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_visual: Node2D = $AttackVisual
@onready var attack_indicator: Line2D = $AttackVisual/AttackIndicator
@onready var attack_target_marker: Marker2D = $AttackVisual/AttackTarget


func _ready() -> void:
	# Ensure time scale is normal on start
	Engine.time_scale = 1.0
	
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
	
	# Create ground slam attack visual indicator
	_create_slam_attack_visual()
	
	# Create kick object visual indicator
	_create_kick_object_indicator()
	
	# Create bullet parry visual indicator
	_create_bullet_parry_indicator()
	
	# Setup animations
	_setup_animations()
	
	# Connect to enemy signals
	_connect_to_enemies()


func _exit_tree() -> void:
	"""Ensure time scale is reset when player is removed from scene."""
	Engine.time_scale = 1.0


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


func _create_slam_attack_visual() -> void:
	"""Create the visual indicator for ground slam attack range."""
	# Create a container node for the slam attack visual
	slam_attack_visual = Node2D.new()
	slam_attack_visual.name = "SlamAttackVisual"
	add_child(slam_attack_visual)
	
	# Create a circle polygon to show the kill radius while falling
	slam_range_circle = Polygon2D.new()
	slam_range_circle.name = "SlamRangeCircle"
	slam_attack_visual.add_child(slam_range_circle)
	
	# Update the visual with current range
	_update_slam_attack_visual()
	
	# Hide by default
	slam_attack_visual.visible = false


func _update_slam_attack_visual() -> void:
	"""Update the ground slam attack visual indicator size based on current range."""
	if not slam_range_circle:
		return
	
	# Generate full circle points for kill radius
	var points: PackedVector2Array = []
	var num_segments = 64  # Number of segments for smooth circle
	
	# Add center point
	points.append(Vector2.ZERO)
	
	# Add full circle points
	for i in range(num_segments + 1):
		var t = float(i) / num_segments
		var angle_rad = t * TAU  # Full circle (2*PI)
		var point = Vector2(cos(angle_rad), sin(angle_rad)) * slam_kill_radius
		points.append(point)
	
	slam_range_circle.polygon = points
	slam_range_circle.color = Color(1.0, 0.2, 0.2, 0.4)  # Red with transparency (ground slam)


func _create_kick_object_indicator() -> void:
	"""Create the visual indicator for kick object direction."""
	object_kick_indicator = Line2D.new()
	object_kick_indicator.name = "ObjectKickIndicator"
	object_kick_indicator.width = 3.0
	object_kick_indicator.default_color = Color(0.2, 1.0, 0.2, 0.8)  # Green
	object_kick_indicator.visible = false
	add_child(object_kick_indicator)


func _physics_process(delta: float) -> void:
	# Track position at start of frame
	var frame_start_position = global_position
	var frame_start_velocity = velocity
	
	# Update game time for rewind system (only when not paused)
	# When paused, _physics_process doesn't run, so time doesn't advance
	if not get_tree().paused:
		game_time += delta
		
		# Record state snapshot for rewind system
		if rewind_enabled:
			_record_state_snapshot()
			_cleanup_old_history()
	
	# Update rewind cooldown timer
	if rewind_cooldown_timer > 0:
		rewind_cooldown_timer -= delta
	
	# Cache world space state once per frame for performance
	var space_state = get_world_2d().direct_space_state
	
	# Update performance timers
	ledge_check_timer += delta
	
	# Update slam freeze timer
	if is_slam_frozen:
		slam_freeze_timer -= delta
		if slam_freeze_timer <= 0:
			_end_slam_freeze()
	
	# 1. Process Input
	var input_vector := _get_input_vector()
	
	# Wall Jump Override: Force movement away from wall during wall jump cooldown
	# regardless of actual player input
	if wall_jump_cooldown > 0:
		input_vector.x = wall_jump_forced_direction
	
	# Skip all input processing if slam frozen
	if is_slam_frozen:
		velocity = Vector2.ZERO  # No movement during freeze
		move_and_slide()
		_post_movement_updates()
		return
	
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
		elif not is_on_floor() and air_dash_cooldown_timer <= 0 and air_dash_available:
			# Air dash (only if available)
			_start_air_dash(input_vector.x)
	
	# Handle rewind input (hold-to-rewind)
	if rewind_enabled and rewind_cooldown_timer <= 0:
		# Check if rewind button was just pressed (start rewind)
		if Input.is_action_just_pressed("rewind"):
			if not is_stunned and not is_slam_frozen and not is_rewind_tracing:
				print("[REWIND] Rewind hold started")
				_start_rewind_hold()
		
		# Check if rewind button was just released (stop and spawn shadow)
		# This must be checked AFTER the press check to avoid same-frame conflicts
		if Input.is_action_just_released("rewind") and is_rewind_holding:
			print("[REWIND] Rewind hold released")
			_stop_rewind_hold()
	
	# Update run state based on speed (sprint state when speed exceeds threshold)
	var current_speed = velocity.length()
	is_running = current_speed > sprint_speed_threshold
	
	# Handle speed-based afterimage trail
	if current_speed > sprint_speed_threshold:
		trail_afterimage_timer += delta
		if trail_afterimage_timer >= trail_afterimage_interval:
			trail_afterimage_timer = 0.0
			
			# Determine how many afterimages should be in the trail
			# Above sprint speed (1000) = 2 afterimages
			# At max speed (1500) = 4 afterimages
			var count = 2
			if current_speed >= trail_max_speed_threshold:
				count = 4
			
			# Spawn a single afterimage with a lifetime that results in 'count' afterimages being visible
			# (since they are spawned every trail_afterimage_interval seconds)
			_spawn_trail_afterimage(count * trail_afterimage_interval)
	else:
		trail_afterimage_timer = 0.0
	
	# Visual feedback: Turn player red when in sprint state, dark red when slamming, cyan when wall running, yellow when dashing
	# Stun visual feedback is handled in _process_stun()
	if not is_stunned:
		# Flash in 0.1 second intervals during any invulnerability/grace period
		if stun_invulnerability_timer > 0 or grace_period_active or bullet_grace_period_active:
			animated_sprite.visible = fmod(game_time, 0.2) < 0.1
		else:
			animated_sprite.visible = true
			
		# Remove all state-based coloring
		modulate = Color.WHITE
	
	# Update animations
	_update_animations()
	
	# Handle continuous dust effects (run, slide)
	_handle_dust_effects(delta)
	
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
	
	# Update wall run cooldown timer
	if wall_run_cooldown > 0:
		wall_run_cooldown -= delta
	
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
	
	# Update early parry grace period timer
	if early_parry_timer > 0:
		early_parry_timer -= delta
		# If timer just expired and we didn't hit anything, that's fine - kick animation continues as normal
	
	# Update parry time slowdown timer (uses unscaled delta for real-time countdown)
	if parry_time_slowdown_active:
		var real_delta = delta / Engine.time_scale  # Get real time delta
		parry_time_slowdown_timer -= real_delta
		if parry_time_slowdown_timer <= 0:
			# Restore normal time
			_restore_normal_time()
	
	# 2. Handle Ground State Changes
	_update_ground_state()
	
	# 3. Update Wall State
	if wall_jump_enabled:
		_update_wall_state(input_vector.x, space_state)
	
	# QOL: Check for Ledge Climb Opportunity
	# This is checked early so it's not skipped by early returns in dash/slide states
	if ledge_climb_enabled and is_on_wall and not is_ledge_climbing:
		_check_ledge_climb(space_state)
	
	# 4. Process Ground Slide (if active, skip most normal movement)
	if is_ground_sliding:
		# Check for jump input to cancel slide with empowered jump
		if Input.is_action_just_pressed("jump") and not is_stunned:
			_perform_jump()  # Will automatically use slide jump bonus
			velocity_before_move_and_slide = velocity
			move_and_slide()
			_post_movement_updates()
			return
		
		# Wall run activation moved to _check_wall_run_activation() which runs AFTER move_and_slide()
		# to ensure actual collision detection instead of raycast-based detection
		# print("[DASH DEBUG] Ground slide frame - wall run check deferred to post-movement")
		
		# Only process slide if not wall running (wall run takes priority)
		if is_ground_sliding and not is_wall_running:
			_process_ground_slide(delta)
			# Skip normal physics when sliding
			velocity_before_move_and_slide = velocity  # Store for wall collision detection
			move_and_slide()
			_post_movement_updates()
			return
	
	# 5. Process Air Dash (if active, skip most normal movement)
	if is_air_dashing:
		# Check for down input to perform ground slam out of air dash
		if Input.is_action_just_pressed("move_down") and not is_stunned:
			# End air dash
			_end_air_dash()
			# Perform ground slam
			if slam_enabled:
				_start_slam(input_vector)
			move_and_slide()
			_post_movement_updates()
			return
		
		# Wall run activation moved to _check_wall_run_activation() which runs AFTER move_and_slide()
		# to ensure actual collision detection instead of raycast-based detection
		# print("[DASH DEBUG] Air dash frame - wall run check deferred to post-movement")
		
		# Only process air dash if not wall running (wall run takes priority)
		if is_air_dashing and not is_wall_running:
			_process_air_dash(delta)
			# Skip normal physics when air dashing
			velocity_before_move_and_slide = velocity  # Store for wall collision detection
			move_and_slide()
			_post_movement_updates()
			return
	
	# 6. Process Ground Slam (if active, skip most normal movement)
	if is_slamming:
		_process_slam(delta)
		# Skip normal physics when slamming
		move_and_slide()
		_post_movement_updates()
		return
	
	# 7. Process Wall Run (if active, skip most normal movement)
	if is_wall_running:
		# print("╔═══════════════════════════════════════╗")
		# print("║   WALL RUN ACTIVE THIS FRAME          ║")
		# print("╚═══════════════════════════════════════╝")
		# print("[WALL RUN STATE] Timer: ", "%.2f" % wall_run_timer, "s | Speed: ", "%.1f" % wall_run_speed, " | Decay: ", "%.1f" % wall_run_speed_decay)
		
		# Check for jump input BEFORE processing wall run
		# This allows player to jump out of wall run
		if Input.is_action_just_pressed("jump") and not is_stunned:
			# print("[WALL RUN DEBUG] ⚠ Jump pressed during wall run, performing empowered wall jump")
			_perform_wall_jump()
			# After jump, is_wall_running is false, so continue with normal physics below
		
		# Check if player is pressing away from the wall (end wall run)
		if is_wall_running:
			# wall_normal points AWAY from the wall
			# If player is pressing in the direction of wall_normal, they're pushing away from wall
			if (wall_normal.x > 0 and input_vector.x > 0.1) or (wall_normal.x < 0 and input_vector.x < -0.1):
				# print("[WALL RUN DEBUG] ⚠ Player pushing away from wall (input: ", "%.2f" % input_vector.x, ", wall_normal.x: ", "%.2f" % wall_normal.x, ") - ending wall run")
				_end_wall_run()
		
		# Only process wall run if still wall running (jump or input might have cancelled it)
		if is_wall_running:
			var pos_before_frame = global_position
			_process_wall_run(delta)
			# Skip normal physics when wall running
			move_and_slide()
			var pos_after_frame = global_position
			var movement_this_frame = pos_after_frame - pos_before_frame
			# print("[WALL RUN DEBUG] Position AFTER move_and_slide(): ", pos_after_frame)
			# print("[WALL RUN DEBUG] Movement this frame: ", movement_this_frame, " (distance: ", "%.2f" % movement_this_frame.length(), ")")
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
	
	# 9.6. Check for Early Parry Triggers
	if early_parry_timer > 0 and not kick_has_fired and not is_stunned:
		# Priority: Bullet > Object > Enemy
		if parry_enabled and closest_bullet:
			_trigger_early_parry(KickTargetType.BULLET, closest_bullet)
		elif kick_object_enabled and closest_kickable_object:
			_trigger_early_parry(KickTargetType.OBJECT, closest_kickable_object)
		elif attack_enabled and not nearby_enemies.is_empty():
			# Find closest enemy
			var closest_enemy = null
			var closest_distance = INF
			for enemy in nearby_enemies:
				if not enemy or not is_instance_valid(enemy) or enemy.is_destroyed:
					continue
				var distance = global_position.distance_to(enemy.global_position)
				if distance < closest_distance:
					closest_distance = distance
					closest_enemy = enemy
			
			if closest_enemy:
				_trigger_early_parry(KickTargetType.ENEMY, closest_enemy)
	
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
	
	# 11.5. Process Rewind Traceback (if active, skip normal movement)
	if is_rewind_tracing:
		_process_rewind_traceback(delta)
		# Skip normal physics when tracing
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
		# NOTE: We don't call move_and_slide() here because _process_ledge_climb 
		# sets global_position directly for a guaranteed result.
		_post_movement_updates()
		return
	
	# 15. Apply Gravity
	_apply_gravity(delta)
	
	# 16. Handle Jump Input
	_handle_jump_input()
	
	# 17. Handle Ground Slam Input
	_handle_ground_slam_input()
	
	# 18. Apply Horizontal Movement
	_apply_horizontal_movement(input_vector.x, delta)
	
	# 19. Execute Jump (if buffered or triggered)
	_execute_buffered_jump()
	
	# 20. Move Character
	velocity_before_move_and_slide = velocity
	move_and_slide()
	
	# 21. QOL: Corner Correction (only when moving up fast)
	# Use velocity_before_move_and_slide because move_and_slide might zero out velocity.y on ceiling hit
	if corner_correction_enabled and (velocity.y < 0 or velocity_before_move_and_slide.y < 0) and abs(velocity_before_move_and_slide.y) > 50:
		_apply_corner_correction(space_state)
	
	# 22. Post-Movement Updates
	_post_movement_updates()
	
	# 23. Track position changes when near walls (for debugging)
	if is_on_wall:
		var frame_end_position = global_position
		var frame_end_velocity = velocity
		var position_delta = frame_end_position - frame_start_position
		var velocity_delta = frame_end_velocity - frame_start_velocity
		
		if position_delta.length() > 0.1 or velocity_delta.length() > 0.1:
			var vertical_direction = "UP" if position_delta.y < 0 else "DOWN"
			# print("╔═══════════ FRAME MOVEMENT (NEAR WALL) ═══════════╗")
			# print("║ Start pos: ", frame_start_position)
			# print("║ End pos:   ", frame_end_position)
			# print("║ Delta:     ", position_delta, " (", "%.2f" % position_delta.length(), " pixels)")
			# print("║ Vertical:  ", vertical_direction, " ", "%.2f" % abs(position_delta.y), " pixels")
			# print("║ Start vel: ", frame_start_velocity)
			# print("║ End vel:   ", frame_end_velocity)
			# print("║ is_wall_running: ", is_wall_running)
			# print("║ is_on_wall: ", is_on_wall)
			# print("╚═══════════════════════════════════════════════════╝")

	# Update camera shake
	_process_camera_shake(delta)


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
	wall_jump_cooldown = 0.0
	wall_jump_forced_direction = 0.0
	# Reset ledge climb cooldown on landing (allows fresh ledge climb attempts)
	ledge_climb_cooldown_timer = 0.0
	
	# Reset air dash availability on landing
	air_dash_available = true
	
	# End wall run if landing
	if is_wall_running:
		_end_wall_run()
	
	# Handle ground slam landing with AOE damage
	if is_slamming:
		# Perform AOE damage on landing
		_perform_slam_landing_aoe()
		
		# Preserve horizontal momentum and apply landing speed boost multiplier
		velocity.x = slam_pre_landing_horizontal_speed * slam_landing_speed_boost
		velocity.y = 0  # Cancel vertical velocity
		is_slamming = false
		# Hide slam attack visual
		if slam_attack_visual:
			slam_attack_visual.visible = false
		
		# Start slam freeze period
		_start_slam_freeze()
	
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
	
	# DEBUG: Track dash state at start of wall detection
	var is_dashing = is_ground_sliding or is_air_dashing
	if is_dashing:
		pass
		# print("[WALL DETECT DEBUG] ═══════════════════════════════════════")
		# print("[WALL DETECT DEBUG] Starting wall detection DURING DASH")
		# print("[WALL DETECT DEBUG] Ground sliding: ", is_ground_sliding, " | Air dashing: ", is_air_dashing)
		# print("[WALL DETECT DEBUG] Current position: ", global_position)
		# print("[WALL DETECT DEBUG] Current velocity: ", velocity)
		# print("[WALL DETECT DEBUG] was_on_wall: ", was_on_wall)
	
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
	
	# CRITICAL FIX: Extend raycast distance during dashes to prevent skipping walls
	# During high-speed movement, player can move 20-30 pixels per frame,
	# but default wall_check_distance is only 8 pixels!
	var effective_wall_check_distance = wall_check_distance
	if is_dashing:
		# Calculate how far player will move this frame
		var movement_per_frame = abs(velocity.x) / 60.0  # Assume 60fps
		# Extend raycast to at least cover this distance, plus buffer
		effective_wall_check_distance = max(wall_check_distance, movement_per_frame * 1.5)
		# print("[WALL DETECT DEBUG] Extended raycast distance: ", effective_wall_check_distance, " (was ", wall_check_distance, ")")
		# print("[WALL DETECT DEBUG] velocity.x: ", velocity.x, " | movement_per_frame: ", movement_per_frame)
	
	# During wall run, check at multiple heights for more accurate wall detection
	var check_heights = [-half_height + 4, 0.0, half_height - 4]
	
	var left_hit_any = false
	var right_hit_any = false
	
	# Check for walls at each height
	for height_offset in check_heights:
		# Check for wall on the left
		var left_ray_origin = global_position + Vector2(-half_width, height_offset)
		var left_ray_end = left_ray_origin + Vector2(-effective_wall_check_distance, 0)
		var query_left = PhysicsRayQueryParameters2D.create(left_ray_origin, left_ray_end)
		query_left.exclude = [self]
		var left_hit = space_state.intersect_ray(query_left)
		if left_hit:
			left_hit_any = true
		
		# DEBUG: Log raycast results during dash
		if is_dashing and (left_hit or velocity.x < -100):
			pass
			# print("[WALL DETECT DEBUG] LEFT raycast: origin=", left_ray_origin, " end=", left_ray_end)
			# print("[WALL DETECT DEBUG] LEFT raycast distance: ", effective_wall_check_distance)
			# print("[WALL DETECT DEBUG] LEFT hit: ", left_hit.size() > 0, " | hit_any: ", left_hit_any)
		
		# Check for wall on the right
		var right_ray_origin = global_position + Vector2(half_width, height_offset)
		var right_ray_end = right_ray_origin + Vector2(effective_wall_check_distance, 0)
		var query_right = PhysicsRayQueryParameters2D.create(right_ray_origin, right_ray_end)
		query_right.exclude = [self]
		var right_hit = space_state.intersect_ray(query_right)
		if right_hit:
			right_hit_any = true
		
		# DEBUG: Log raycast results during dash
		if is_dashing and (right_hit or velocity.x > 100):
			pass
			# print("[WALL DETECT DEBUG] RIGHT raycast: origin=", right_ray_origin, " end=", right_ray_end)
			# print("[WALL DETECT DEBUG] RIGHT raycast distance: ", effective_wall_check_distance)
			# print("[WALL DETECT DEBUG] RIGHT hit: ", right_hit.size() > 0, " | hit_any: ", right_hit_any)
	
	# Determine if player is on a wall
	if left_hit_any:
		is_on_wall = true
		wall_normal = Vector2.RIGHT  # Wall is on left, so push right
		# DEBUG: Log wall detection during dash
		if is_dashing:
			pass
			# print("[WALL DETECT DEBUG] ✓ LEFT WALL DETECTED! Setting is_on_wall = true")
			# print("[WALL DETECT DEBUG] wall_normal: ", wall_normal)
		# Reset air dash cooldown and availability when touching wall
		air_dash_cooldown_timer = 0.0
		air_dash_available = true
		# Player is wall sliding if moving down and pressing toward wall
		# BUT: Don't activate wall sliding during dashes (they should trigger wall run instead)
		if velocity.y > 0 and input_direction < 0 and not is_ground_sliding and not is_air_dashing:
			is_wall_sliding = true
	elif right_hit_any:
		is_on_wall = true
		wall_normal = Vector2.LEFT  # Wall is on right, so push left
		# DEBUG: Log wall detection during dash
		if is_dashing:
			pass
			# print("[WALL DETECT DEBUG] ✓ RIGHT WALL DETECTED! Setting is_on_wall = true")
			# print("[WALL DETECT DEBUG] wall_normal: ", wall_normal)
		# Reset air dash cooldown and availability when touching wall
		air_dash_cooldown_timer = 0.0
		air_dash_available = true
		# Player is wall sliding if moving down and pressing toward wall
		# BUT: Don't activate wall sliding during dashes (they should trigger wall run instead)
		if velocity.y > 0 and input_direction > 0 and not is_ground_sliding and not is_air_dashing:
			is_wall_sliding = true
	else:
		# DEBUG: Log when no wall detected during dash
		if is_dashing and (abs(velocity.x) > 500):
			pass
			# print("[WALL DETECT DEBUG] ✗ NO WALL DETECTED (moving fast: ", velocity.x, ")")
			# print("[WALL DETECT DEBUG] left_hit_any: ", left_hit_any, " | right_hit_any: ", right_hit_any)
	
	# DEBUG: Summary of wall detection during dash
	if is_dashing:
		pass
		# print("[WALL DETECT DEBUG] ═══════════════════════════════════════")
		# print("[WALL DETECT DEBUG] FINAL RESULT: is_on_wall = ", is_on_wall)
		# print("[WALL DETECT DEBUG] wall_normal: ", wall_normal)
		# print("[WALL DETECT DEBUG] is_wall_sliding: ", is_wall_sliding)
		# print("[WALL DETECT DEBUG] Dash will now proceed with is_on_wall = ", is_on_wall)
		# print("[WALL DETECT DEBUG] ═══════════════════════════════════════")
	
	# Debug wall detection changes
	if is_on_wall != was_on_wall:
		pass
		# print("[WALL DETECT] Wall state changed - is_on_wall: ", is_on_wall, " wall_normal: ", wall_normal, " cooldown: ", "%.3f" % wall_jump_cooldown)
		# print("[WALL DETECT] was_on_wall: ", was_on_wall, " -> is_on_wall: ", is_on_wall)
		# print("[WALL DETECT] is_wall_running: ", is_wall_running)
	
	# NOTE: Wall run activation moved to _check_wall_run_activation() 
	# which runs AFTER move_and_slide() to ensure actual collision
	
	# End wall run if wall ends (check using raycast detection)
	if is_wall_running and not is_on_wall:
		# print("[WALL RUN DEBUG] ⚠ Wall contact lost (raycast) - stopping wall run")
		# print("[WALL RUN DEBUG] Position: ", global_position)
		# print("[WALL RUN DEBUG] Velocity: ", velocity)
		_end_wall_run()


# ====================================
# WALL RUN
# ====================================

func _start_wall_run(horizontal_speed: float, force: bool = false) -> void:
	"""Initiate a wall run up the wall. If force is true, bypasses speed checks."""
	# Calculate wall run speed proportional to horizontal velocity
	# Clamp between min and max wall run speed
	wall_run_speed = clamp(horizontal_speed, wall_run_min_speed, wall_run_max_speed)
	
	# If not forced, perform speed validation checks
	if not force:
		# Check if wall run speed is above minimum (prevents immediate termination)
		if wall_run_speed <= wall_run_min_speed:
			# print("[WALL RUN DEBUG] ✗ Cannot start - speed at minimum threshold (", wall_run_speed, " <= ", wall_run_min_speed, ")")
			return
		
		# CRITICAL CHECK: Prevent wall run if decay is so high it would end in first frame
		# Calculate how much decay would occur in a typical frame (assuming 60fps = 0.0167s)
		var estimated_first_frame_decay = wall_run_speed_decay * 0.017
		var speed_after_first_frame = wall_run_speed - estimated_first_frame_decay
		
		# print("=== WALL RUN START CHECK ===")
		# print("[WALL RUN DEBUG] Initial speed: ", "%.1f" % wall_run_speed)
		# print("[WALL RUN DEBUG] Decay rate: ", "%.1f" % wall_run_speed_decay, " per second")
		# print("[WALL RUN DEBUG] Estimated first frame decay (0.017s): ", "%.1f" % estimated_first_frame_decay)
		# print("[WALL RUN DEBUG] Speed after first frame: ", "%.1f" % speed_after_first_frame)
		# print("[WALL RUN DEBUG] Min speed threshold: ", "%.1f" % wall_run_min_speed)
		
		if speed_after_first_frame < wall_run_min_speed:
			# print("[WALL RUN DEBUG] ⚠ BLOCKED: Decay too high! Wall run would end in first frame")
			# print("[WALL RUN DEBUG] This would cause infinite micro-wall-runs")
			# print("[WALL RUN DEBUG] To wall run with this decay rate, you need initial speed > ", "%.1f" % (wall_run_min_speed + estimated_first_frame_decay))
			return
	else:
		pass
		# print("=== WALL RUN FORCED START (FROM DASH) ===")
		# print("[WALL RUN DEBUG] FORCED activation from dash - bypassing all speed checks")
		# print("[WALL RUN DEBUG] Initial speed: ", "%.1f" % wall_run_speed)
	
	is_wall_running = true
	wall_run_timer = 0.0
	wall_run_start_position = global_position
	wall_run_frame_count = 0
	
	# print("=== WALL RUN STARTING ===")
	# print("[WALL RUN DEBUG] Initial wall_run_speed: ", "%.2f" % wall_run_speed)
	# print("[WALL RUN DEBUG] Expected duration: ", "%.2f" % ((wall_run_speed - wall_run_min_speed) / wall_run_speed_decay), " seconds")
	# print("[WALL RUN DEBUG] Expected frames (at 60fps): ", int((wall_run_speed - wall_run_min_speed) / wall_run_speed_decay * 60))
	# print("[WALL RUN DEBUG] Max allowed duration: ", "%.2f" % wall_run_max_duration, " seconds")
	# print("[WALL RUN DEBUG] Wall normal: ", wall_normal)
	# print("[WALL RUN DEBUG] Starting position: ", wall_run_start_position)
	# print("[WALL RUN DEBUG] Is sprinting: ", is_running)
	# print("[WALL RUN DEBUG] Is dashing: ", is_ground_sliding or is_air_dashing)
	# print("[WALL RUN DEBUG] Is in air: ", not is_on_floor())
	# print("=============================")
	
	# Set upward velocity
	velocity.y = -wall_run_speed
	
	# Maintain some horizontal velocity towards the wall to stay attached
	velocity.x = velocity.x * 0.3  # Reduce horizontal speed but keep direction
	
	# Cancel other states
	is_jumping = false
	is_wall_sliding = false
	is_slamming = false
	# Hide slam attack visual
	if slam_attack_visual:
		slam_attack_visual.visible = false
	
	# End ground slide or air dash if wall running
	if is_ground_sliding:
		# print("[WALL RUN DEBUG] Ended ground slide to start wall run")
		_end_ground_slide()
	if is_air_dashing:
		# print("[WALL RUN DEBUG] Ended air dash to start wall run")
		_end_air_dash()
	
	# Could trigger wall run effects here (particles, sound, animation, etc.)


func _process_wall_run(delta: float) -> void:
	"""Update wall run state - move upward with decaying speed."""
	# Increment frame counter
	wall_run_frame_count += 1
	
	# Store position before any changes
	var position_before = global_position
	
	# Increment timer
	wall_run_timer += delta
	
	# EXTENSIVE DEBUG - Print every frame for detailed tracking
	# print("╔══════════════════════════════════════════════════════════════════╗")
	# print("║ WALL RUN FRAME #", wall_run_frame_count, "                                           ║")
	# print("╚══════════════════════════════════════════════════════════════════╝")
	# print("[WALL RUN DEBUG] Position BEFORE frame: ", position_before)
	# print("[WALL RUN DEBUG] Timer: ", "%.3f" % wall_run_timer, "s / ", "%.2f" % wall_run_max_duration, "s max")
	# print("[WALL RUN DEBUG] Delta time: ", "%.4f" % delta, "s")
	# print("[WALL RUN DEBUG] wall_run_speed BEFORE decay: ", "%.2f" % wall_run_speed)
	# print("[WALL RUN DEBUG] ⚠️ wall_run_speed_decay VALUE: ", "%.2f" % wall_run_speed_decay, " per second ⚠️")
	# print("[WALL RUN DEBUG] Decay amount this frame: ", "%.4f" % (wall_run_speed_decay * delta))
	# print("[WALL RUN DEBUG] VERIFY: wall_run_speed (", "%.2f" % wall_run_speed, ") - (decay ", "%.2f" % wall_run_speed_decay, " * delta ", "%.4f" % delta, ") = ", "%.2f" % (wall_run_speed - wall_run_speed_decay * delta))
	# print("[WALL RUN DEBUG] Is sprinting: ", is_running)
	# print("[WALL RUN DEBUG] Is dashing: ", is_ground_sliding or is_air_dashing)
	# print("[WALL RUN DEBUG] Is in air: ", not is_on_floor())
	# print("[WALL RUN DEBUG] On wall: ", is_on_wall)
	# print("[WALL RUN DEBUG] Wall normal: ", wall_normal)
	
	# Check if max duration reached
	if wall_run_timer >= wall_run_max_duration:
		# print("[WALL RUN DEBUG] ⚠ Max duration reached (", wall_run_max_duration, "s) - STOPPING")
		_end_wall_run()
		return
	
	# Apply speed decay and check if it drops below minimum BEFORE clamping
	var new_speed = wall_run_speed - wall_run_speed_decay * delta
	
	# print("[WALL RUN DEBUG] Speed AFTER decay calculation: ", "%.2f" % new_speed)
	# print("[WALL RUN DEBUG] Min speed threshold: ", "%.2f" % wall_run_min_speed)
	# print("[WALL RUN DEBUG] Speed check: new_speed (", "%.2f" % new_speed, ") < min (", "%.2f" % wall_run_min_speed, ") = ", new_speed < wall_run_min_speed)
	
	# Check if speed dropped below minimum
	if new_speed < wall_run_min_speed:
		# print("[WALL RUN DEBUG] ⚠⚠⚠ Speed dropped below minimum - CALLING _end_wall_run() ⚠⚠⚠")
		# print("[WALL RUN DEBUG] new_speed: ", "%.2f" % new_speed, " < wall_run_min_speed: ", "%.2f" % wall_run_min_speed)
		# print("[WALL RUN DEBUG] About to call _end_wall_run() and return...")
		_end_wall_run()
		# print("[WALL RUN DEBUG] ⚠⚠⚠ THIS SHOULD NEVER PRINT - _process_wall_run should have returned! ⚠⚠⚠")
		return
	
	# Speed is still above minimum, update it
	wall_run_speed = new_speed
	
	# print("[WALL RUN DEBUG] ✓ Speed updated to: ", "%.2f" % wall_run_speed)
	
	# Set upward velocity based on current wall run speed
	velocity.y = -wall_run_speed
	
	# print("[WALL RUN DEBUG] Set velocity.y to: ", "%.2f" % velocity.y)
	
	# Maintain slight horizontal velocity to stay on wall
	# Push slightly into the wall
	velocity.x = -wall_normal.x * 50.0
	
	# print("[WALL RUN DEBUG] Set velocity.x to: ", "%.2f" % velocity.x)
	# print("[WALL RUN DEBUG] Final velocity: ", velocity)
	
	# Position will change after move_and_slide() is called in _physics_process
	# Log it there for accurate tracking
	# print("----------------------")


func _end_wall_run() -> void:
	"""End the wall run."""
	if not is_wall_running:
		# print("[WALL RUN DEBUG] ⚠ _end_wall_run() called but not wall running - ignoring")
		return
	
	var velocity_before = velocity
	var timer_final = wall_run_timer
	var speed_final = wall_run_speed
	var final_position = global_position
	var total_movement = final_position - wall_run_start_position
	var vertical_movement = total_movement.y  # Negative = moved up, positive = moved down
	var frames_ran = wall_run_frame_count
	
	# print("╔═══════════════════════════════════════╗")
	# print("║       WALL RUN ENDED                  ║")
	# print("╚═══════════════════════════════════════╝")
	# print("[WALL RUN DEBUG] ⚠️ TOTAL FRAMES: ", frames_ran, " ⚠️")
	# print("[WALL RUN DEBUG] Duration: ", "%.3f" % timer_final, " seconds")
	# print("[WALL RUN DEBUG] Final wall_run_speed: ", "%.2f" % speed_final)
	# print("[WALL RUN DEBUG] Velocity before: ", velocity_before)
	# print("[WALL RUN DEBUG] Start position: ", wall_run_start_position)
	# print("[WALL RUN DEBUG] Final position: ", final_position)
	# print("[WALL RUN DEBUG] Total movement: ", total_movement)
	# print("[WALL RUN DEBUG] ⚠️ Vertical distance: ", "%.2f" % abs(vertical_movement), " pixels ", "UP" if vertical_movement < 0 else "DOWN", " ⚠️")
	# print("[WALL RUN DEBUG] Sprint state: ", is_running)
	# print("[WALL RUN DEBUG] Dashing: ", is_ground_sliding or is_air_dashing)
	# print("[WALL RUN DEBUG] In air: ", not is_on_floor())
		
	is_wall_running = false
	wall_run_timer = 0.0
	wall_run_speed = 0.0
	wall_run_frame_count = 0
	
	# Set cooldown to prevent immediate restart
	# This is the FIX for the bug where wall run restarts infinitely!
	wall_run_cooldown = 0.3  # 0.3 second cooldown
	
	# Prevent wall slide from activating immediately after wall run ends
	# This ensures player falls off the wall instead of transitioning to slide
	is_on_wall = false
	wall_normal = Vector2.ZERO
	
	# Allow gravity to take over
	# Velocity is maintained but wall run state is cleared
	
	# print("[WALL RUN DEBUG] Velocity after: ", velocity)
	# print("[WALL RUN DEBUG] Set wall run cooldown to prevent immediate restart: ", "%.3f" % wall_run_cooldown, "s")
	# print("[WALL RUN DEBUG] Cleared wall state to prevent slide")
	# print("====================")
	
	# Could trigger wall run end effects here (particles fade, etc.)


func _check_wall_run_activation() -> void:
	"""Check for wall run activation/continuation AFTER move_and_slide() using actual collision detection."""
	
	# Don't activate if in states that should block wall running
	if is_stunned or is_attacking or is_slamming or is_ledge_climbing:
		if is_wall_running:
			_end_wall_run()
		return
	
	# Check if wall run should END (lost wall contact during wall run)
	if is_wall_running:
		# During wall run, use raycast detection to check if still on wall
		if not is_on_wall:
			# print("[WALL RUN COLLISION] ⚠ Lost wall contact (raycast) - ending wall run")
			# print("[WALL RUN COLLISION] Position: ", global_position)
			# print("[WALL RUN COLLISION] Velocity: ", velocity)
			_end_wall_run()
		return  # Don't check for activation if already running
	
	# Check if wall run should START (hit wall during dash or fast run)
	# Can activate during dashes, fast running, or while in the air
	if not is_ground_sliding and not is_air_dashing and not is_running and is_on_floor():
		# If on floor and not dashing/running, check if we have enough speed anyway
		# (This handles cases where is_running might be false but speed is still above threshold)
		var horizontal_speed = abs(velocity_before_move_and_slide.x)
		if horizontal_speed < wall_run_min_velocity:
			return
	
	if not wall_run_enabled:
		return
	
	# Check cooldowns
	if wall_jump_cooldown > 0 or wall_run_cooldown > 0:
		return
	
	# Get the speed we were moving at before move_and_slide()
	var speed_before_collision = abs(velocity_before_move_and_slide.x)
	
	# Must have been moving fast enough before collision
	if speed_before_collision < wall_run_min_velocity:
		return
	
	# CRITICAL: Detect wall collision by checking if:
	# 1. Raycast detects wall (is_on_wall = true from _update_wall_state)
	# 2. Horizontal velocity was significantly reduced by collision
	var velocity_reduced = abs(velocity.x) < speed_before_collision * 0.5  # Velocity reduced by 50%+
	var has_slide_collision = get_slide_collision_count() > 0
	var raycast_detects_wall = is_on_wall  # From _update_wall_state raycast detection
	
	# Wall collision is confirmed if raycast detects wall AND either:
	# - Velocity was significantly reduced (head-on or angled collision), OR
	# - We have slide collisions (glancing collision)
	var has_wall_collision = raycast_detects_wall and (velocity_reduced or has_slide_collision)
	
	if not has_wall_collision:
		# print("[WALL RUN COLLISION] No wall collision detected")
		# print("[WALL RUN COLLISION] - raycast:", raycast_detects_wall, " | velocity_reduced:", velocity_reduced, " | slides:", has_slide_collision)
		# print("[WALL RUN COLLISION] - speed_before:", "%.1f" % speed_before_collision, " | speed_after:", "%.1f" % abs(velocity.x))
		return
	
	# print("[WALL RUN CHECK] ═══════════════════════════════════════")
	# print("[WALL RUN CHECK] ✓ WALL COLLISION DETECTED!")
	# print("[WALL RUN CHECK] Detection: raycast=", raycast_detects_wall, " velocity_reduced=", velocity_reduced, " slides=", has_slide_collision)
	# print("[WALL RUN CHECK] POSITION: ", global_position)
	# print("[WALL RUN CHECK] Velocity before collision: ", velocity_before_move_and_slide)
	# print("[WALL RUN CHECK] Velocity after collision: ", velocity)
	# print("[WALL RUN CHECK] Speed reduction: ", "%.1f" % speed_before_collision, " -> ", "%.1f" % abs(velocity.x))
	# print("[WALL RUN CHECK] Wall normal: ", wall_normal)
	# print("[WALL RUN CHECK] Attempting to start wall run:")
	# print("[WALL RUN CHECK] - Speed before collision: ", "%.2f" % speed_before_collision)
	# print("[WALL RUN CHECK] - Wall run speed (fixed): 1000.00")
	# print("[WALL RUN CHECK] - Required speed: ", "%.2f" % wall_run_min_velocity)
	# print("[WALL RUN CHECK] - Sprint state: ", is_running)
	# print("[WALL RUN CHECK] - Dashing: ", is_ground_sliding or is_air_dashing)
	# print("[WALL RUN CHECK] - In air: ", not is_on_floor())
	# print("[WALL RUN CHECK] - Wall jump cooldown: ", "%.3f" % wall_jump_cooldown, "s")
	# print("[WALL RUN CHECK] - Wall run cooldown: ", "%.3f" % wall_run_cooldown, "s")
	# print("[WALL RUN CHECK] ✓ Conditions met - calling _start_wall_run() with speed=1000")
	
	# Start wall run with fixed speed of 1000 for consistent wall run behavior
	_start_wall_run(1000.0, true)
	
	# print("[WALL RUN CHECK] AFTER _start_wall_run() - is_wall_running: ", is_wall_running)
	# print("[WALL RUN CHECK] VELOCITY AFTER: ", velocity)
	# print("[WALL RUN CHECK] POSITION AFTER: ", global_position)
	# print("[WALL RUN CHECK] ═══════════════════════════════════════")


# ====================================
# GRAVITY & PHYSICS
# ====================================

func _apply_gravity(delta: float) -> void:
	"""Apply gravity with variable strength based on jump state."""
	if not is_on_floor():
		# WALL RUNNING: No gravity during wall run (handled in _process_wall_run)
		if is_wall_running:
			# print("[GRAVITY DEBUG] Skipping gravity - wall running active")
			return
		# WALL SLIDING: Apply gravity but cap at wall slide speed
		elif is_wall_sliding:
			var vel_before_slide = velocity.y
			velocity.y += gravity * delta
			velocity.y = min(velocity.y, wall_slide_speed)
			# print("[WALL SLIDE] Applied - vel before: ", "%.2f" % vel_before_slide, " | after: ", "%.2f" % velocity.y, " | gravity added: ", "%.2f" % (gravity * delta), " | capped at: ", "%.2f" % wall_slide_speed)
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
		# print("[JUMP DEBUG] Jump pressed - is_on_wall: ", is_on_wall, " is_wall_running: ", is_wall_running, " is_on_floor: ", is_on_floor())
		
		# Check if infinite jumps is enabled (assist mode)
		var infinite_jumps: bool = get_meta("infinite_jumps_enabled", false)
		
		# Check for wall jump first (highest priority)
		# Note: Wall run jump is handled earlier in _physics_process
		if wall_jump_enabled and is_on_wall and not is_wall_running and wall_jump_cooldown <= 0:
			_perform_wall_jump()
		else:
			# Check if we can jump immediately
			var can_jump: bool = is_on_floor() or not coyote_timer.is_stopped() or infinite_jumps
			
			if can_jump:
				_perform_jump()
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


func _handle_ground_slam_input() -> void:
	"""Process ground slam input - trigger slam when pressing down while in air."""
	# Can't ground slam when stunned or already slamming
	if is_stunned or is_slamming:
		return
	
	# Check for down input press this frame
	if Input.is_action_just_pressed("move_down"):
		# Only allow ground slam when in air and slam is enabled
		if slam_enabled and not is_on_floor():
			var input_vector = _get_input_vector()
			_start_slam(input_vector)


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
		
		# Big dust cloud for slide jump
		_spawn_dust("slide_jump", Vector2(0, 32))
	# Apply empowered jump when in sprint state
	elif is_running:
		# Vertical boost - jump higher
		velocity.y = jump_velocity * empowered_jump_velocity_multiplier
		
		# Horizontal boost - add momentum in current direction
		var jump_direction = sign(velocity.x) if abs(velocity.x) > 10.0 else last_input_direction
		if jump_direction != 0:
			velocity.x += jump_direction * empowered_jump_horizontal_boost
			
		# Normal jump dust
		_spawn_dust("jump", Vector2(0, 32))
	else:
		# Normal jump
		velocity.y = jump_velocity
		
		# Normal jump dust
		_spawn_dust("jump", Vector2(0, 32))
	
	is_jumping = true
	coyote_timer.stop()  # Consume coyote time


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
		# print("[WALL JUMP DEBUG] Wall normal was zero, inferred: ", jump_wall_normal, " from velocity.x: ", velocity.x)
	
	# print("[WALL JUMP DEBUG] Starting wall jump - is_wall_running: ", is_wall_running, " wall_normal: ", jump_wall_normal)
	
	# Check if jumping from a wall run (empowered wall jump)
	if is_wall_running:
		# Empowered wall jump with higher velocities
		velocity.y = wall_run_empowered_jump_vertical
		velocity.x = jump_wall_normal.x * wall_run_empowered_jump_horizontal
		
		# print("[WALL JUMP DEBUG] ⚡ EMPOWERED from wall run ⚡")
		
		# End wall run
		_end_wall_run()
	else:
		# Normal wall jump
		velocity.y = wall_jump_vertical_velocity
		velocity.x = jump_wall_normal.x * wall_jump_horizontal_velocity
		
		# print("[WALL JUMP DEBUG] Normal wall jump")
	
	# Set jump state
	is_jumping = true
	
	# Set cooldown to prevent immediate re-attachment to wall
	wall_jump_cooldown = 0.3  # 0.3 second cooldown
	wall_jump_forced_direction = jump_wall_normal.x  # Store direction away from wall
	
	# Clear wall state to prevent immediate re-attachment
	is_on_wall = false
	is_wall_sliding = false
	
	# Trigger wall jump dust effect
	# Spawn at side of player touching wall, pointing away from wall
	var dust_offset = Vector2(-jump_wall_normal.x * 16, 0)
	_spawn_dust("wall_jump", dust_offset, jump_wall_normal)


func _on_jump_buffer_timeout() -> void:
	"""Clear buffered jump when timer expires."""
	jump_buffered = false


# ====================================
# CORNER CORRECTION (EDGE DETECTION)
# ====================================

func _apply_corner_correction(space_state: PhysicsDirectSpaceState2D) -> void:
	"""QOL FEATURE: Nudge player past corners to avoid head bonking on edges."""
	# Only apply when moving upward (before/during collision, not after stopped)
	# NOTE: If called after move_and_slide, velocity.y might be 0 if we hit a ceiling
	var check_velocity = velocity if velocity.y != 0 else velocity_before_move_and_slide
	
	if check_velocity.y >= 0:
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
	var left_corner_pos = global_position + Vector2(-half_width + 1, -half_height)
	var left_cast_end = left_corner_pos + Vector2(0, -corner_correction_distance)
	var query_left = PhysicsRayQueryParameters2D.create(left_corner_pos, left_cast_end)
	query_left.exclude = [self]
	var left_hit = space_state.intersect_ray(query_left)
	
	# Cast upward from right corner of player's head
	var right_corner_pos = global_position + Vector2(half_width - 1, -half_height)
	var right_cast_end = right_corner_pos + Vector2(0, -corner_correction_distance)
	var query_right = PhysicsRayQueryParameters2D.create(right_corner_pos, right_cast_end)
	query_right.exclude = [self]
	var right_hit = space_state.intersect_ray(query_right)
	
	# Corner correction logic: if one side hits a corner but the other doesn't, nudge toward the clear side
	var nudged = false
	if left_hit and not right_hit:
		# Left corner is blocked, right is clear -> nudge right to slip past
		print("[CORNER] Nudging RIGHT")
		position.x += corner_correction_distance * 0.5
		nudged = true
	elif right_hit and not left_hit:
		# Right corner is blocked, left is clear -> nudge left to slip past
		print("[CORNER] Nudging LEFT")
		position.x -= corner_correction_distance * 0.5
		nudged = true
		
	if nudged:
		# If we were stopped by the ceiling, restore the vertical velocity so we continue upward
		if velocity.y == 0 and velocity_before_move_and_slide.y < 0:
			velocity.y = velocity_before_move_and_slide.y
			# Move up slightly to ensure we aren't still stuck in the ceiling next frame
			position.y -= 1.0


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
	
	var is_dashing = is_ground_sliding or is_air_dashing or is_wall_running
	# Require sprint state, dash, or wall run to perform ledge climb
	if not is_running and not is_dashing:
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
	if wall_normal == Vector2.ZERO:
		# Fallback if wall_normal is zero
		wall_side = 1.0 if velocity.x > 0 else -1.0
	
	# Only check when near a wall
	if not is_on_wall:
		# print("[LEDGE] Not on wall (is_on_wall=false)")
		return

	# Only climb if moving towards the wall or pressing towards it
	var input_dir = Input.get_axis("move_left", "move_right")
	if input_dir != 0 and sign(input_dir) != wall_side:
		return
	
	var check_x_offset = half_width * wall_side
	
	# Check if there's a ledge above (wall ends within detection range)
	var ledge_found := false
	
	# Increase detection range slightly if dashing/wall running for better feel
	var detection_height = ledge_climb_detection_height
	if is_dashing:
		detection_height *= 1.5

	# Cast multiple rays upward to find where the wall ends
	# We check from negative offsets (below head) to detection_height (above head)
	var start_offset = -half_height + 4 # Start just above the center
	for height_offset in range(int(start_offset), int(detection_height), 2):
		var ray_origin = global_position + Vector2(check_x_offset + (1.0 * wall_side), -half_height - height_offset)
		var ray_end = ray_origin + Vector2((wall_check_distance + 4) * wall_side, 0)
		
		var query = PhysicsRayQueryParameters2D.create(ray_origin, ray_end)
		query.exclude = [self]
		var hit = space_state.intersect_ray(query)
		
		# If no wall detected at this height, we found a potential ledge top
		if not hit:
			# Now check if there's solid ground on top of the ledge
			var forward_check = ledge_climb_forward_offset + 4
			var ground_check_origin = global_position + Vector2(check_x_offset + forward_check * wall_side, -half_height - height_offset - 10)
			var ground_check_end = ground_check_origin + Vector2(0, half_height * 3.0) # Long ray down to find the floor
			
			var ground_query = PhysicsRayQueryParameters2D.create(ground_check_origin, ground_check_end)
			ground_query.exclude = [self]
			var ground_hit = space_state.intersect_ray(ground_query)
			
			# If we found ground on top, this is a valid ledge
			if ground_hit:
				# One last check: make sure the ground we found is actually roughly at the ledge height
				# and not way below us (which would just be the floor we are already on)
				var ground_relative_y = ground_hit.position.y - global_position.y
				if ground_relative_y > half_height - 2:
					# This ground is at or below our feet, not a ledge top
					continue
					
				print("[LEDGE] VALID LEDGE FOUND! Triggering climb at height: ", height_offset, " Ground at relative Y: ", ground_relative_y)
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
	"""Smoothly animate the player climbing up the ledge using a two-phase movement."""
	# Advance climb progress
	ledge_climb_progress += delta / ledge_climb_duration
	
	# Clamp progress to 0-1 range
	ledge_climb_progress = min(ledge_climb_progress, 1.0)
	
	# Use ease-out curve for smooth deceleration at the end
	var ease_progress = _ease_out_cubic(ledge_climb_progress)
	
	# TWO-PHASE MOVEMENT: 
	# 1. Move UP to clear the ledge height (first 60% of the ease_progress)
	# 2. Move FORWARD onto the ledge (last 40% of the ease_progress)
	var vertical_cutoff = 0.6
	var current_target_pos = Vector2.ZERO
	
	if ease_progress < vertical_cutoff:
		# PHASE 1: Vertical clearing
		var p = ease_progress / vertical_cutoff
		current_target_pos.y = lerp(ledge_climb_start_pos.y, ledge_climb_target_pos.y, p)
		current_target_pos.x = ledge_climb_start_pos.x
	else:
		# PHASE 2: Horizontal landing
		var p = (ease_progress - vertical_cutoff) / (1.0 - vertical_cutoff)
		current_target_pos.y = ledge_climb_target_pos.y
		current_target_pos.x = lerp(ledge_climb_start_pos.x, ledge_climb_target_pos.x, p)
	
	# CRITICAL: For QOL ledge climb, we set global_position directly to ensure 
	# the player doesn't get stuck on the corner due to move_and_slide's collision logic.
	# The _check_ledge_climb raycasts already verified this path is clear.
	var new_pos = current_target_pos
	if delta > 0:
		velocity = (new_pos - global_position) / delta
	global_position = new_pos
	
	# Finish climb when progress reaches 1.0
	if ledge_climb_progress >= 1.0:
		print("[LEDGE] Climb finished at: ", global_position)
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
	"""Process kick input - always start kick animation, trigger effect at frame 5."""
	# Can't kick when stunned
	if is_stunned:
		return
	
	# Can only kick if not on cooldown and not already attacking
	if is_attacking or attack_cooldown_timer > 0:
		return
	
	# Check for kick input (mapped to 'j' key)
	if Input.is_action_just_pressed("melee_attack"):
		_start_kick_sequence()


func _start_kick_sequence() -> void:
	"""Initialize the kick animation and determine target (if any)."""
	is_attacking = true
	attack_timer = 0.0
	kick_has_fired = false
	early_parry_timer = parry_early_grace_period
	current_kick_target_type = KickTargetType.NONE
	current_kick_target_node = null
	attack_velocity = Vector2.ZERO
	
	# Determine target based on priority: Bullet > Object > Enemy
	if parry_enabled and closest_bullet:
		current_kick_target_type = KickTargetType.BULLET
		current_kick_target_node = closest_bullet
	elif kick_object_enabled and closest_kickable_object:
		current_kick_target_type = KickTargetType.OBJECT
		current_kick_target_node = closest_kickable_object
	elif attack_enabled and not nearby_enemies.is_empty():
		# Find closest enemy
		var closest_enemy = null
		var closest_distance = INF
		for enemy in nearby_enemies:
			if not enemy or not is_instance_valid(enemy) or enemy.is_destroyed:
				continue
			var distance = global_position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
		
		if closest_enemy:
			current_kick_target_type = KickTargetType.ENEMY
			current_kick_target_node = closest_enemy
	
	# If we have a target, ensure we're facing it
	if current_kick_target_node:
		var dir_to_target = (current_kick_target_node.global_position - global_position).normalized()
		if dir_to_target.x != 0:
			facing_direction = sign(dir_to_target.x)
	
	# Reset air dash availability (kick animation counts as a reset)
	air_dash_available = true
	
	# Start the animation
	if animated_sprite.animation != "kick":
		animated_sprite.play("kick")
	else:
		animated_sprite.frame = 0
		animated_sprite.play("kick")
	
	# Cancel other states
	is_jumping = false
	is_slamming = false
	if slam_attack_visual:
		slam_attack_visual.visible = false
	if is_ground_sliding:
		_end_ground_slide()
	if is_air_dashing:
		_end_air_dash()


func _execute_enemy_kick(enemy: Node2D) -> void:
	"""Execute the kick against an enemy."""
	if not enemy or not is_instance_valid(enemy) or enemy.is_destroyed:
		return
		
	attack_target_enemy = enemy
	
	# Calculate direction to enemy and knockback direction (AWAY from enemy)
	var direction_to_enemy = (enemy.global_position - global_position).normalized()
	attack_direction = -direction_to_enemy  # Player flies AWAY from enemy
	
	# Set knockback velocity (send player away from enemy)
	attack_velocity = attack_direction * attack_knockback_speed
	velocity = attack_velocity
	
	# Kick the enemy and send them flying
	if enemy.has_method("kick"):
		# Kick enemy in direction away from player
		var enemy_knockback_direction = direction_to_enemy  # Enemy flies away from player
		enemy.kick(enemy_knockback_direction, attack_enemy_knockback_force)
	
	# Hide attack indicator
	attack_visual.visible = false


func _process_attack(delta: float) -> void:
	"""Update attack state - trigger effect at frame 5 and wait for animation to complete."""
	attack_timer += delta
	
	# Check for kick execution at frame 5 (index 4)
	if not kick_has_fired and animated_sprite.animation == "kick" and animated_sprite.frame >= 4:
		_execute_kick_effect()
		kick_has_fired = true
	
	# Movement logic - only apply knockback velocity AFTER the kick has fired
	if kick_has_fired:
		# Maintain knockback velocity (allow slight gravity to make it feel more natural)
		if not is_on_floor():
			velocity.y += gravity * 0.3 * delta
			velocity.y = min(velocity.y, max_fall_speed)
		
		# Only override horizontal velocity if we actually hit a target
		if current_kick_target_type != KickTargetType.NONE:
			velocity.x = attack_velocity.x
	else:
		# Before kick - only slow down if we HAVE a target (anticipation)
		# If no target, just maintain current momentum
		if current_kick_target_type != KickTargetType.NONE:
			velocity.x = move_toward(velocity.x, 0, 500.0 * delta)
		
		if not is_on_floor():
			_apply_gravity(delta)
	
	# End attack ONLY when animation finishes (non-looping kick animation)
	# This ensures the kick plays to completion as requested
	if animated_sprite.animation == "kick":
		if not animated_sprite.is_playing() and animated_sprite.frame >= animated_sprite.sprite_frames.get_frame_count("kick") - 1:
			_end_attack()
	else:
		# Safety fallback if animation somehow changed
		_end_attack()
	
	# Absolute safety timeout (2 seconds) to prevent getting stuck
	if attack_timer > 2.0:
		_end_attack()


func _execute_kick_effect() -> void:
	"""Execute the actual physical effect of the kick based on target type."""
	match current_kick_target_type:
		KickTargetType.ENEMY:
			if current_kick_target_node and is_instance_valid(current_kick_target_node):
				_execute_enemy_kick(current_kick_target_node)
		KickTargetType.OBJECT:
			if current_kick_target_node and is_instance_valid(current_kick_target_node):
				_execute_object_kick(current_kick_target_node)
		KickTargetType.BULLET:
			if current_kick_target_node and is_instance_valid(current_kick_target_node):
				_execute_bullet_parry(current_kick_target_node)
		KickTargetType.NONE:
			pass


func _trigger_early_parry(type: KickTargetType, node: Node2D) -> void:
	"""Force an immediate parry when target enters range during early grace period."""
	if not node or not is_instance_valid(node):
		return
		
	# Consume the early parry window
	early_parry_timer = 0.0
	
	# Set the target
	current_kick_target_type = type
	current_kick_target_node = node
	
	# If we are already in an attack animation, jump to the active frame
	if is_attacking:
		if not kick_has_fired:
			# Jump to just before the active frame so it feels like it hit
			animated_sprite.frame = 4
			_execute_kick_effect()
			kick_has_fired = true
	else:
		# Start a new kick and immediately trigger the effect
		_start_kick_sequence()
		animated_sprite.frame = 4
		_execute_kick_effect()
		kick_has_fired = true


func _end_attack() -> void:
	"""Complete the attack and preserve momentum."""
	is_attacking = false
	attack_timer = 0.0
	attack_cooldown_timer = attack_cooldown
	attack_target_enemy = null
	
	# PRESERVE MOMENTUM: Keep knockback velocity with retention multiplier
	# This makes the attack feel like it flows into your movement
	if current_kick_target_type != KickTargetType.NONE:
		velocity.x = attack_velocity.x * attack_momentum_retention
	
	# If on ground, maintain more horizontal velocity
	# If in air, gravity will naturally take over for vertical
	if is_on_floor():
		# Ground attack - keep most of horizontal momentum
		velocity.y = 0.0
	
	# Could trigger attack end effects here (animation, sound, trail fade, etc.)


# ====================================
# STUN SYSTEM
# ====================================

func _process_stun(delta: float) -> void:
	"""Update stun state - player falls to ground and can't move, shakes and flashes."""
	# Remove previous shake offset before physics
	global_position -= stun_shake_offset
	
	# Apply gravity to make player fall
	_apply_gravity(delta)
	
	# Stop horizontal movement
	velocity.x = 0.0
	
	# Keep player upright
	rotation = 0.0
	
	# Visual feedback: flash in 0.1 second intervals
	var flash_period = 0.2 # 0.1s on, 0.1s off
	animated_sprite.visible = fmod(stun_timer, flash_period) < 0.1
	modulate = Color.WHITE


func _start_stun(colliding_enemy: Node2D = null) -> void:
	"""Start the stun effect when player touches enemy without attacking - but with grace period first."""
	# Start grace period instead of immediate stun
	grace_period_active = true
	grace_period_timer = grace_period_duration
	grace_period_colliding_enemy = colliding_enemy


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
	is_slamming = false
	is_ledge_climbing = false
	# Hide slam attack visual
	if slam_attack_visual:
		slam_attack_visual.visible = false
	if is_ground_sliding:
		_end_ground_slide()
	if is_air_dashing:
		_end_air_dash()


func _cancel_grace_period_with_kick() -> void:
	"""Cancel grace period and perform kick attack instead."""
	# Clear grace period state
	grace_period_active = false
	grace_period_timer = 0.0
	
	# Reset air dash availability (kick parry counts as a reset)
	air_dash_available = true
	
	# Temporarily add the enemy to nearby_enemies if it's not already there
	var enemy = grace_period_colliding_enemy
	grace_period_colliding_enemy = null
	
	if enemy and is_instance_valid(enemy) and not enemy.is_destroyed:
		# Make sure the enemy is in the nearby_enemies array
		if not nearby_enemies.has(enemy):
			nearby_enemies.append(enemy)
		
		# Perform the attack
		_start_kick_sequence()


func _end_stun() -> void:
	"""End the stun effect and start invulnerability period."""
	# Remove any remaining shake offset
	global_position -= stun_shake_offset
	stun_shake_offset = Vector2.ZERO
	
	is_stunned = false
	stun_timer = 0.0
	
	# Reset rotation and visibility
	rotation = 0.0
	animated_sprite.visible = true
	
	# Reset visual feedback
	modulate = Color.WHITE
	
	# Start invulnerability period
	stun_invulnerability_timer = stun_invulnerability_duration


func _on_enemy_touched(enemy: Node2D = null) -> void:
	"""Called when player touches an enemy without attacking."""
	# If we are already trying to parry (too early press), trigger it immediately!
	if early_parry_timer > 0 and not kick_has_fired:
		_trigger_early_parry(KickTargetType.ENEMY, enemy)
		return
		
	# Check for invulnerability from dashes, already stunned, grace period active, or post-stun invulnerability
	if not is_attacking and not is_stunned and not is_invulnerable and not grace_period_active and stun_invulnerability_timer <= 0:
		_start_stun(enemy)


func _on_enemy_destroyed() -> void:
	"""Called when an enemy is destroyed by attack."""
	pass


func _on_bullet_hit(bullet: Node2D, shooter: Node2D = null) -> void:
	"""Called when player is hit by a bullet - starts grace period for parry."""
	# If we are already trying to parry (too early press), trigger it immediately!
	if early_parry_timer > 0 and not kick_has_fired:
		_trigger_early_parry(KickTargetType.BULLET, bullet)
		return
		
	# Check for invulnerability from dashes, already stunned, grace periods active, or post-stun invulnerability
	if not is_attacking and not is_stunned and not is_invulnerable and not grace_period_active and not bullet_grace_period_active and stun_invulnerability_timer <= 0:
		# Start bullet grace period
		bullet_grace_period_active = true
		bullet_grace_period_timer = bullet_hit_grace_period
		bullet_that_hit = bullet


func _apply_bullet_hitstun() -> void:
	"""Apply hitstun after bullet grace period expires without parry."""
	bullet_grace_period_active = false
	bullet_grace_period_timer = 0.0
	bullet_that_hit = null
	
	# Apply stun effect (same as enemy touch)
	_on_enemy_touched(null)


func _cancel_bullet_grace_period_with_parry() -> void:
	"""Cancel bullet grace period by parrying nearby bullets."""
	# Clear bullet grace period state
	bullet_grace_period_active = false
	bullet_grace_period_timer = 0.0
	bullet_that_hit = null
	
	# Detect and parry nearby bullets
	_update_bullet_detection()
	
	if closest_bullet and is_instance_valid(closest_bullet):
		# Perform the kick sequence
		_start_kick_sequence()
	else:
		# No bullets to parry - just give brief invulnerability as reward
		stun_invulnerability_timer = 0.3


# ====================================
# GROUND SLIDE & AIR DASH
# ====================================

func _start_ground_slide(input_x: float) -> void:
	"""Initiate a ground slide with reduced height."""
	print("[DEBUG-SLIDE] Starting Slide")
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
	is_slamming = false
	# Hide slam attack visual
	if slam_attack_visual:
		slam_attack_visual.visible = false
	
	# End wall run if sliding
	if is_wall_running:
		_end_wall_run()
	
	# Start slide animation
	if animated_sprite:
		animated_sprite.play("slide")
		animated_sprite.frame = 0
	
	# Could trigger slide effects here (particles, sound, animation, etc.)


func _process_ground_slide(delta: float) -> void:
	"""Update ground slide state - maintain velocity and check for end."""
	# Increment timer
	ground_slide_timer += delta
	
	# Detailed debug for slide duration
	if Engine.get_frames_drawn() % 10 == 0: # Every 10 frames to avoid spam
		print("[DEBUG-SLIDE] Sliding: Time=%.2f/%.2f, Animation=%s, Frame=%d" % [ground_slide_timer, ground_slide_duration, animated_sprite.animation, animated_sprite.frame])
	
	# Check if slide duration has elapsed
	if ground_slide_timer >= ground_slide_duration:
		print("[DEBUG-SLIDE] Duration finished, ending slide")
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
	
	# Could trigger slide end effects here (particles fade, etc.)


func _start_air_dash(input_x: float) -> void:
	"""Initiate an air dash with force-based impulse."""
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
	air_dash_afterimages_spawned = 0
	air_dash_cooldown_timer = air_dash_cooldown
	air_dash_available = false  # Consume air dash (will reset on ground/wall/kick parry/slam)
	is_invulnerable = true  # Player is invulnerable during air dash
	
	# Reset velocity before applying impulse forces for consistent behavior
	velocity.x = 0.0
	velocity.y = 0.0
	
	# Apply impulse forces
	velocity.x += dash_direction * air_dash_horizontal_impulse
	velocity.y += air_dash_vertical_impulse
	
	# Update facing direction
	facing_direction = dash_direction
	
	# Cancel other states
	is_jumping = false
	is_wall_sliding = false
	is_slamming = false
	# Hide slam attack visual
	if slam_attack_visual:
		slam_attack_visual.visible = false
	
	# End wall run if air dashing
	if is_wall_running:
		_end_wall_run()
	
	# Could trigger air dash effects here (particles, sound, animation, etc.)


func _process_air_dash(delta: float) -> void:
	"""Update air dash state - force-based, allows physics to take over after initial impulse."""
	# Increment timer
	air_dash_timer += delta
	
	# Spawn afterimages throughout the dash
	var interval = air_dash_duration / float(air_dash_afterimage_count)
	if air_dash_timer >= (air_dash_afterimages_spawned + 0.5) * interval and air_dash_afterimages_spawned < air_dash_afterimage_count:
		_spawn_air_dash_afterimage()
		air_dash_afterimages_spawned += 1
	
	# Check if air dash duration has elapsed
	if air_dash_timer >= air_dash_duration:
		_end_air_dash()
		return
	
	# Force-based air dash - let physics handle velocity naturally after initial impulse
	# No need to override velocity here


func _end_air_dash() -> void:
	"""End the air dash and set velocity to configured end values."""
	if not is_air_dashing:
		return
	
	is_air_dashing = false
	air_dash_timer = 0.0
	is_invulnerable = false  # End invulnerability
	
	# Set velocity to configured end values
	velocity.x = dash_direction * air_dash_end_horizontal_velocity
	velocity.y = air_dash_end_vertical_velocity
	
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
# GROUND SLAM
# ====================================

func _start_slam(input_vector: Vector2) -> void:
	"""Initiate a ground slam - straight downward at high speed."""
	# Store current horizontal velocity for landing boost
	slam_pre_landing_horizontal_speed = velocity.x
	
	# Set slam velocity - STRAIGHT DOWN at slam speed
	slam_velocity = Vector2(0, slam_speed)  # No horizontal component, only downward
	velocity = slam_velocity
	
	# Set slam state
	is_slamming = true
	
	# Show slam attack visual indicator
	if slam_attack_visual:
		_update_slam_attack_visual()  # Update visual to match current range
		slam_attack_visual.visible = true
	
	# Cancel other states
	is_jumping = false
	is_wall_sliding = false
	if is_ground_sliding:
		_end_ground_slide()
	if is_air_dashing:
		_end_air_dash()
	
	# Could trigger slam effects here (particles, sound, animation, etc.)


func _process_slam(delta: float) -> void:
	"""Update ground slam state - maintain straight downward velocity and kill enemies in radius."""
	# Check for enemies within kill radius (5m = ~500 pixels)
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy) and not enemy.is_destroyed:
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= slam_kill_radius:
				# Enemy is in kill zone! Destroy them
				_perform_slam_kill(enemy)
	
	# Maintain slam velocity - STRAIGHT DOWN (no gravity, no air control)
	velocity = slam_velocity
	
	# Check if we hit the ground
	if is_on_floor():
		# Landing is handled in _on_landed()
		return
	
	# Check if we hit a wall (cancel slam)
	if is_on_wall:
		is_slamming = false
		slam_pre_landing_horizontal_speed = 0.0
		# Hide slam attack visual
		if slam_attack_visual:
			slam_attack_visual.visible = false
		# Allow normal physics to take over
		# Slam cancelled by wall collision


func _perform_slam_kill(enemy: Node2D) -> void:
	"""Kill an enemy during ground slam - enemy is in kill radius."""
	# Kick the enemy downwards (destroy it)
	if enemy.has_method("kick"):
		# Kick enemy downwards with slam attack knockback speed
		var downward_direction = Vector2.DOWN
		enemy.kick(downward_direction, slam_attack_knockback_speed)
	
	# Note: We don't bounce or interrupt the slam when killing enemies
	# Player continues slamming down through all enemies
	
	# Could trigger slam kill effects here (particles, sound, etc.)


func _perform_slam_landing_aoe() -> void:
	"""Perform AOE damage on slam landing - damage all enemies in landing AOE."""
	# AOE is centered on player landing position
	# 10m length (width) x 5m height = 1000 pixels x 500 pixels
	var aoe_half_width = slam_landing_aoe_width / 2.0
	var aoe_half_height = slam_landing_aoe_height / 2.0
	
	# Get all enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy) and not enemy.is_destroyed:
			# Check if enemy is within rectangular AOE
			var offset = enemy.global_position - global_position
			
			# Check if within horizontal range
			if abs(offset.x) <= aoe_half_width:
				# Check if within vertical range (only below and slightly above player)
				if offset.y >= -aoe_half_height and offset.y <= aoe_half_height:
					# Enemy is in landing AOE! Destroy them
					if enemy.has_method("kick"):
						# Kick enemy away from player horizontally
						var knock_direction = Vector2(sign(offset.x) if offset.x != 0 else 1.0, 0.5).normalized()
						enemy.kick(knock_direction, slam_attack_knockback_speed)
	
	# Reset air dash availability (slam landing counts as a reset)
	air_dash_available = true
	
	# Could trigger slam landing AOE effects here (particles, screen shake, shockwave, etc.)


func _start_slam_freeze() -> void:
	"""Start the slam freeze period - player can't be controlled, moved, or damaged."""
	is_slam_frozen = true
	slam_freeze_timer = slam_freeze_duration
	
	# Player is invulnerable during freeze
	is_invulnerable = true
	
	# Could trigger freeze effects here (animation, sound, etc.)


func _end_slam_freeze() -> void:
	"""End the slam freeze period - restore player control."""
	is_slam_frozen = false
	slam_freeze_timer = 0.0
	
	# End invulnerability
	is_invulnerable = false
	
	# Could trigger unfreeze effects here (animation, sound, etc.)


# ====================================
# POST-MOVEMENT
# ====================================

func _post_movement_updates() -> void:
	"""Handle any post-movement state updates."""
	# Check for wall run activation AFTER move_and_slide() to ensure actual collision
	_check_wall_run_activation()
	
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


func _execute_object_kick(obj: Node2D) -> void:
	"""Execute the kick against an object."""
	if not obj or not is_instance_valid(obj):
		return
	
	if not obj.has_method("kick"):
		return
	
	# Calculate kick direction (horizontal, in facing direction)
	var kick_direction = Vector2(facing_direction, 0)
	
	# Kick the object
	obj.kick(kick_direction, kick_object_speed)
	
	# Apply knockback to player in opposite direction
	attack_velocity = Vector2(-facing_direction * kick_object_knockback_force, -100.0)
	velocity = attack_velocity
	
	# Set cooldown
	attack_cooldown_timer = attack_cooldown


# ====================================
# AFTERIMAGE EFFECT
# ====================================

func _spawn_afterimage() -> void:
	"""Spawn an afterimage at the player's current position."""
	# Create a new afterimage instance
	var afterimage = AfterimageScene.instantiate()
	
	# Set the afterimage's position and rotation to match the player
	afterimage.global_position = global_position
	afterimage.rotation = rotation
	
	# Initialize from current sprite
	if afterimage.has_method("setup_from_sprite"):
		afterimage.setup_from_sprite(animated_sprite)
	elif afterimage.has_node("Polygon2D"):
		# Fallback for old afterimage logic
		var afterimage_polygon = afterimage.get_node("Polygon2D")
		afterimage_polygon.color = Color(0.2, 1.0, 0.2, 0.6)
		afterimage_polygon.visible = true
	
	# Add the afterimage to the scene
	get_parent().add_child(afterimage)
	
	# Ensure it's rendered behind the player
	afterimage.z_index = z_index - 1


func _spawn_air_dash_afterimage() -> void:
	"""Spawn a specialized brighter/desaturated afterimage for air dashing."""
	var afterimage = AfterimageScene.instantiate()
	
	# Set the afterimage's position and rotation to match the player
	afterimage.global_position = global_position
	afterimage.rotation = rotation
	
	# Brighter and more desaturated modulation
	var dash_modulate = Color(2.5, 2.5, 2.5, 1.0) # Much brighter white
	
	if afterimage.has_method("setup_from_sprite"):
		afterimage.setup_from_sprite(animated_sprite, dash_modulate)
		# Set properties from inspector
		afterimage.lifetime = air_dash_afterimage_lifetime
		afterimage.initial_alpha = air_dash_afterimage_alpha
	
	# Add to tree
	get_parent().add_child(afterimage)
	
	# Ensure it's rendered at a consistent Z index relative to player
	afterimage.z_index = z_index - 1


func _spawn_trail_afterimage(lifetime: float) -> void:
	"""Spawn an afterimage for the speed trail with a specific lifetime."""
	var afterimage = AfterimageScene.instantiate()
	
	# Set the afterimage's position and rotation to match the player
	afterimage.global_position = global_position
	afterimage.rotation = rotation
	
	if afterimage.has_method("setup_from_sprite"):
		# Use a slightly more transparent and standard modulate for the trail
		var trail_modulate = Color(1.0, 1.0, 1.0, 0.6)
		afterimage.setup_from_sprite(animated_sprite, trail_modulate)
		
		# Override lifetime based on trail count
		afterimage.lifetime = lifetime
		# Ensure initial alpha matches our trail modulate
		afterimage.initial_alpha = 0.6
	
	# Add the afterimage to the scene
	get_parent().add_child(afterimage)
	
	# Ensure it's rendered behind the player
	afterimage.z_index = z_index - 1


# ====================================
# REWIND MECHANICS
# ====================================

func _record_state_snapshot() -> void:
	"""Record current player state to history."""
	if not rewind_enabled:
		return
	
	var snapshot = {
		"timestamp": game_time,
		"position": global_position,
		"velocity": velocity,
		"is_on_floor": is_on_floor(),
		"facing_direction": facing_direction,
		"is_jumping": is_jumping,
		"is_wall_sliding": is_wall_sliding,
		"is_ground_sliding": is_ground_sliding,
		"is_air_dashing": is_air_dashing,
		"is_wall_running": is_wall_running,
		"is_attacking": is_attacking,
		"is_stunned": is_stunned,
		"is_slamming": is_slamming,
		"is_slam_frozen": is_slam_frozen
	}
	
	state_history.append(snapshot)


func _cleanup_old_history() -> void:
	"""Remove state history entries older than rewind_history_duration."""
	if not rewind_enabled:
		return
	
	var cutoff_time = game_time - rewind_history_duration
	state_history = state_history.filter(func(snapshot: Dictionary) -> bool:
		return snapshot["timestamp"] >= cutoff_time
	)


func _find_state_at_time(target_time: float) -> Dictionary:
	"""Find the state snapshot closest to the target time."""
	if state_history.is_empty():
		return {}
	
	# Find the closest snapshot to target_time
	var closest_snapshot: Dictionary = {}
	var closest_diff: float = INF
	
	for snapshot in state_history:
		var diff = abs(snapshot["timestamp"] - target_time)
		if diff < closest_diff:
			closest_diff = diff
			closest_snapshot = snapshot
	
	return closest_snapshot


func _start_rewind_hold() -> void:
	"""Start the hold-to-rewind - extract path and begin continuous traceback."""
	if not rewind_enabled:
		print("[REWIND] Rewind is disabled")
		return
	
	# Check if we have enough history
	rewind_target_time = game_time - rewind_time
	if rewind_target_time < 0:
		# Not enough history available - use whatever we have
		print("[REWIND] Not enough history (game_time: ", game_time, ", target_time: ", rewind_target_time, ")")
		# Try to use available history instead
		if state_history.is_empty():
			print("[REWIND] No state history available")
			return
		# Use the oldest state we have
		var oldest_state = state_history[0]
		rewind_target_time = oldest_state["timestamp"]
		print("[REWIND] Using oldest available state at time: ", rewind_target_time)
	
	# Store rewind start information
	rewind_start_time = game_time
	rewind_start_position = global_position
	rewind_current_progress = 0.0
	
	# Extract path from state history (from target_time to current game_time)
	# This will be used for both traceback and shadow animation
	rewind_traceback_frame_data = _extract_path_from_history(rewind_target_time, game_time, rewind_start_position)
	
	if rewind_traceback_frame_data.is_empty():
		print("[REWIND] Could not extract path, aborting rewind")
		return
	
	# Sort path by timestamp in descending order (most recent first) for easier traceback
	# This way progress 0.0 = first element, progress 1.0 = last element
	rewind_traceback_frame_data.sort_custom(func(a, b): return a["timestamp"] > b["timestamp"])
	
	print("[REWIND] Extracted path with ", rewind_traceback_frame_data.size(), " points")
	print("[REWIND] Path time range: ", rewind_traceback_frame_data[rewind_traceback_frame_data.size() - 1]["timestamp"], " to ", rewind_traceback_frame_data[0]["timestamp"])
	print("[REWIND] Target time range: ", rewind_target_time, " to ", game_time)
	
	# Cancel conflicting states before starting traceback
	if is_attacking:
		is_attacking = false
		attack_timer = 0.0
	if is_ground_sliding:
		is_ground_sliding = false
		ground_slide_timer = 0.0
	if is_air_dashing:
		is_air_dashing = false
		air_dash_timer = 0.0
	if is_wall_running:
		is_wall_running = false
		wall_run_timer = 0.0
	if is_slamming:
		is_slamming = false
	if is_slam_frozen:
		is_slam_frozen = false
		slam_freeze_timer = 0.0
	
	# Enter slow-mo and create ghost path visualization
	_enter_rewind_slowmo()
	_create_ghost_path_visualization()
	
	# Start hold-to-rewind
	is_rewind_holding = true
	is_rewind_tracing = true
	rewind_hold_start_time = game_time
	velocity = Vector2.ZERO  # Stop movement during traceback
	print("[REWIND] Hold-to-rewind started with ", rewind_traceback_frame_data.size(), " path points")


func _stop_rewind_hold() -> void:
	"""Stop the hold-to-rewind and spawn shadow at current position."""
	if not is_rewind_holding:
		return
	
	print("[REWIND] Stopping hold-to-rewind at progress: ", rewind_current_progress)
	
	# Get the current state at the release position
	var release_state = _get_state_at_progress(rewind_current_progress)
	
	if not release_state.is_empty():
		# Restore player to release position
		global_position = release_state["position"]
		if rewind_restore_velocity:
			velocity = release_state["velocity"]
		else:
			velocity = Vector2.ZERO
		facing_direction = release_state["facing_direction"]
	
	# Shadow spawning removed - no shadow on rewind
	
	# Exit slow-mo and clear ghost path visualization
	_exit_rewind_slowmo()
	_clear_ghost_path_visualization()
	
	# End rewind
	is_rewind_holding = false
	is_rewind_tracing = false
	rewind_current_progress = 0.0
	rewind_traceback_frame_data = []
	
	# Set cooldown
	rewind_cooldown_timer = rewind_cooldown


func _extract_traceback_frames(start_time: float, end_time: float, num_frames: int) -> Array[Dictionary]:
	"""Extract evenly-spaced frames from state history for traceback animation.
	Frames go from current (end_time) backwards to past (start_time)."""
	var frames: Array[Dictionary] = []
	
	if state_history.is_empty():
		return frames
	
	# Calculate time step between frames (going backwards)
	var time_range = end_time - start_time
	if time_range <= 0:
		return frames
	
	var time_step = time_range / (num_frames - 1) if num_frames > 1 else 0.0
	
	# Extract frames at evenly-spaced timestamps (from current to past)
	for i in range(num_frames):
		# Go backwards: frame 0 is current (end_time), frame 4 is past (start_time)
		var target_timestamp = end_time - (time_step * i)
		var frame_state = _find_state_at_time(target_timestamp)
		
		if not frame_state.is_empty():
			frames.append({
				"position": frame_state["position"],
				"velocity": frame_state["velocity"],
				"facing_direction": frame_state["facing_direction"],
				"timestamp": target_timestamp
			})
	
	# Always ensure we have the current position as the first frame
	var current_state = _find_state_at_time(end_time)
	if not current_state.is_empty():
		# Check if we already have current frame
		var has_current = false
		for frame in frames:
			if abs(frame["timestamp"] - end_time) < 0.01:
				has_current = true
				break
		
		if not has_current:
			frames.insert(0, {
				"position": current_state["position"],
				"velocity": current_state["velocity"],
				"facing_direction": current_state["facing_direction"],
				"timestamp": end_time
			})
	
	# Always ensure we have the target position (2 seconds ago) as the last frame
	var target_state = _find_state_at_time(start_time)
	if not target_state.is_empty():
		# Check if we already have target frame
		var has_target = false
		for frame in frames:
			if abs(frame["timestamp"] - start_time) < 0.01:
				has_target = true
				break
		
		if not has_target:
			frames.append({
				"position": target_state["position"],
				"velocity": target_state["velocity"],
				"facing_direction": target_state["facing_direction"],
				"timestamp": start_time
			})
	
	# Sort by timestamp in descending order (most recent first, oldest last)
	# This way we animate from current to past
	frames.sort_custom(func(a, b): return a["timestamp"] > b["timestamp"])
	
	return frames


func _process_rewind_traceback(delta: float) -> void:
	"""Process the hold-to-rewind traceback - continuously advance backwards while R is held."""
	if not is_rewind_holding:
		# If not holding anymore, stop (should have been handled by release)
		return
	
	# Check if button is still being held
	if not Input.is_action_pressed("rewind"):
		# Button was released - stop rewind
		print("[REWIND TRACEBACK] Button no longer pressed, stopping")
		_stop_rewind_hold()
		return
	
	# Advance progress backwards (0.0 = current, 1.0 = 2 seconds ago)
	# Progress increases as we go back in time
	# In slow-mo, delta is already affected by time_scale (0.25x)
	# To make rewind 2.0x relative to slow-mo time: progress_delta = (2.0 * delta) / rewind_time
	# Since delta is already 0.25x, this gives us 2.0x speed relative to slow-mo time
	var progress_delta = (rewind_traceback_speed * delta) / rewind_time
	var old_progress = rewind_current_progress
	rewind_current_progress += progress_delta
	
	# Clamp progress to 0.0 - 1.0
	rewind_current_progress = clamp(rewind_current_progress, 0.0, 1.0)
	
	# Debug output (only every 10 frames to avoid spam)
	if Engine.get_physics_frames() % 10 == 0:
		print("[REWIND TRACEBACK] Progress: ", old_progress, " -> ", rewind_current_progress, " (delta: ", progress_delta, ", speed: ", rewind_traceback_speed, ")")
	
	# Check if we've reached the end (2 seconds ago)
	if rewind_current_progress >= 1.0:
		print("[REWIND] Reached 2 seconds ago, completing rewind")
		_complete_rewind_hold()
		return
	
	# Get state at current progress and update player position
	var current_state = _get_state_at_progress(rewind_current_progress)
	if not current_state.is_empty():
		global_position = current_state["position"]
		velocity = current_state["velocity"]
		facing_direction = current_state["facing_direction"]
		
		# Update ghost visualization (fade out completed segments)
		_update_ghost_path_visualization(rewind_current_progress)
	else:
		print("[REWIND TRACEBACK] WARNING: Could not get state at progress ", rewind_current_progress)
	
	# Zero out velocity to prevent physics from interfering
	velocity = Vector2.ZERO


func _get_state_at_progress(progress: float) -> Dictionary:
	"""Get the player state at the given progress (0.0 = current, 1.0 = 2 seconds ago).
	Path is sorted descending (most recent first, oldest last)."""
	if rewind_traceback_frame_data.is_empty():
		return {}
	
	# Calculate target time based on progress
	# progress 0.0 = rewind_start_time (current, most recent)
	# progress 1.0 = rewind_target_time (2 seconds ago, oldest)
	var target_time = rewind_start_time - (progress * (rewind_start_time - rewind_target_time))
	
	# Path is sorted descending (most recent first), so:
	# frame_data[0] = most recent (rewind_start_time)
	# frame_data[-1] = oldest (rewind_target_time)
	
	# Find the two path points to interpolate between
	var prev_point: Dictionary = rewind_traceback_frame_data[0]
	var next_point: Dictionary = rewind_traceback_frame_data[rewind_traceback_frame_data.size() - 1]
	
	# Find the segment containing target_time
	# Since path is descending, we go from high timestamp to low timestamp
	for i in range(rewind_traceback_frame_data.size() - 1):
		var point1 = rewind_traceback_frame_data[i]
		var point2 = rewind_traceback_frame_data[i + 1]
		var timestamp1 = point1["timestamp"]
		var timestamp2 = point2["timestamp"]
		
		# Since descending: timestamp1 > timestamp2
		# Check if target_time is between these two points
		if timestamp1 >= target_time and timestamp2 <= target_time:
			prev_point = point1  # More recent
			next_point = point2  # More past
			break
	
	# If target_time is after most recent point, return most recent
	if target_time > prev_point["timestamp"]:
		return {
			"position": prev_point["position"],
			"velocity": prev_point["velocity"],
			"facing_direction": prev_point.get("facing_direction", facing_direction)
		}
	
	# If target_time is before oldest point, return oldest
	if target_time < next_point["timestamp"]:
		return {
			"position": next_point["position"],
			"velocity": next_point["velocity"],
			"facing_direction": next_point.get("facing_direction", facing_direction)
		}
	
	# Interpolate between the two points
	var time_range = prev_point["timestamp"] - next_point["timestamp"]  # Always positive (descending)
	if time_range <= 0.0:
		return {
			"position": prev_point["position"],
			"velocity": prev_point["velocity"],
			"facing_direction": prev_point.get("facing_direction", facing_direction)
		}
	
	var t = (prev_point["timestamp"] - target_time) / time_range
	t = clamp(t, 0.0, 1.0)
	
	# Smooth interpolation using smoothstep
	t = t * t * (3.0 - 2.0 * t)
	
	return {
		"position": prev_point["position"].lerp(next_point["position"], t),
		"velocity": prev_point["velocity"].lerp(next_point["velocity"], t),
		"facing_direction": prev_point.get("facing_direction", facing_direction)
	}


func _complete_rewind_hold() -> void:
	"""Complete the rewind when reaching 2 seconds ago (R still held)."""
	if not is_rewind_holding:
		return
	
	print("[REWIND] Completing rewind at 2 seconds ago")
	
	# Get state at 2 seconds ago
	var target_state = _find_state_at_time(rewind_target_time)
	if not target_state.is_empty():
		global_position = target_state["position"]
		if rewind_restore_velocity:
			velocity = target_state["velocity"]
		else:
			velocity = Vector2.ZERO
		facing_direction = target_state["facing_direction"]
	
	# Shadow spawning removed - no shadow on rewind
	
	# Exit slow-mo and clear ghost path visualization
	_exit_rewind_slowmo()
	_clear_ghost_path_visualization()
	
	# End rewind
	is_rewind_holding = false
	is_rewind_tracing = false
	rewind_current_progress = 0.0
	rewind_traceback_frame_data = []
	
	# Set cooldown
	rewind_cooldown_timer = rewind_cooldown


# Old _end_rewind_traceback function removed - replaced by _stop_rewind_hold and _complete_rewind_hold


func _enter_rewind_slowmo() -> void:
	"""Enter slow-motion state for rewind."""
	if is_in_rewind_slowmo:
		return  # Already in slow-mo
	
	# Store current time scale (in case something else modified it)
	original_time_scale = Engine.time_scale
	is_in_rewind_slowmo = true
	Engine.time_scale = rewind_slowmo_scale
	
	# Enable grayscale overlay
	_enable_grayscale_overlay()
	
	print("[REWIND] Entered slow-mo (time_scale: ", rewind_slowmo_scale, ")")


func _exit_rewind_slowmo() -> void:
	"""Exit slow-motion state for rewind."""
	if not is_in_rewind_slowmo:
		return  # Not in slow-mo
	
	is_in_rewind_slowmo = false
	Engine.time_scale = original_time_scale
	
	# Disable grayscale overlay
	_disable_grayscale_overlay()
	
	print("[REWIND] Exited slow-mo (restored time_scale: ", original_time_scale, ")")


func _create_ghost_path_visualization() -> void:
	"""Create visual representation of rewind path using ghost markers."""
	# Clear any existing visualization first
	_clear_ghost_path_visualization()
	
	if rewind_traceback_frame_data.is_empty():
		return
	
	# Create container node for ghost markers
	rewind_path_visualization = Node2D.new()
	rewind_path_visualization.name = "RewindPathVisualization"
	# Add to scene root so it's not affected by player movement
	get_tree().root.add_child(rewind_path_visualization)
	
	# Create ghost markers at evenly-spaced intervals along the path
	# Use every 0.2 seconds of path time, or at least 10 markers
	var path_duration = rewind_start_time - rewind_target_time
	var marker_interval = 0.2  # seconds
	var num_markers = max(10, int(path_duration / marker_interval))
	
	# Limit markers for performance (max 50)
	num_markers = min(num_markers, 50)
	
	# Calculate which path points to use for markers
	var marker_indices: Array[int] = []
	if num_markers > 0:
		for i in range(num_markers):
			var progress = float(i) / float(num_markers - 1) if num_markers > 1 else 0.0
			var target_index = int(progress * (rewind_traceback_frame_data.size() - 1))
			target_index = clamp(target_index, 0, rewind_traceback_frame_data.size() - 1)
			marker_indices.append(target_index)
	
	# Create ghost markers
	for i in range(marker_indices.size()):
		var path_index = marker_indices[i]
		var path_point = rewind_traceback_frame_data[path_index]
		
		# Calculate transparency based on progress (more transparent = further in past)
		var marker_progress = float(i) / float(marker_indices.size() - 1) if marker_indices.size() > 1 else 0.0
		var alpha = 0.3 + (0.7 * (1.0 - marker_progress))  # Fade from 1.0 (current) to 0.3 (past)
		
		# Create ghost marker (simple colored rectangle)
		var ghost_marker = Polygon2D.new()
		ghost_marker.polygon = PackedVector2Array([
			Vector2(-16, -32),
			Vector2(16, -32),
			Vector2(16, 32),
			Vector2(-16, 32)
		])
		ghost_marker.color = Color(0.5, 0.2, 0.8, alpha)  # Purple with transparency
		ghost_marker.global_position = path_point["position"]
		
		rewind_path_visualization.add_child(ghost_marker)
		ghost_markers.append(ghost_marker)
	
	print("[REWIND] Created ", ghost_markers.size(), " ghost markers for path visualization")


func _update_ghost_path_visualization(progress: float) -> void:
	"""Update ghost visualization as player rewinds - fade out completed segments."""
	if ghost_markers.is_empty():
		return
	
	# Fade out markers that are behind the current progress
	# Progress 0.0 = current position, progress 1.0 = 2 seconds ago
	# Markers are ordered from current (index 0) to past (last index)
	for i in range(ghost_markers.size()):
		var marker = ghost_markers[i]
		if not is_instance_valid(marker):
			continue
		
		# Calculate marker progress (0.0 = current, 1.0 = past)
		var marker_progress = float(i) / float(ghost_markers.size() - 1) if ghost_markers.size() > 1 else 0.0
		
		# If marker is behind current progress, fade it out
		if marker_progress < progress:
			# Fade out based on how far behind
			var fade_amount = 1.0 - ((progress - marker_progress) / progress) if progress > 0.0 else 1.0
			fade_amount = clamp(fade_amount, 0.0, 1.0)
			var base_alpha = 0.3 + (0.7 * (1.0 - marker_progress))
			marker.modulate.a = base_alpha * fade_amount
		else:
			# Marker is ahead, keep normal transparency
			var base_alpha = 0.3 + (0.7 * (1.0 - marker_progress))
			marker.modulate.a = base_alpha


func _clear_ghost_path_visualization() -> void:
	"""Remove all ghost markers and clear visualization."""
	# Clear markers array
	for marker in ghost_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	ghost_markers.clear()
	
	# Remove container node
	if rewind_path_visualization and is_instance_valid(rewind_path_visualization):
		rewind_path_visualization.queue_free()
		rewind_path_visualization = null
	
	print("[REWIND] Cleared ghost path visualization")


func _enable_grayscale_overlay() -> void:
	"""Enable grayscale overlay effect on the screen."""
	# Find or create the grayscale overlay
	var canvas_layer = get_tree().root.get_node_or_null("GrayscaleOverlay")
	if not canvas_layer:
		# Create a canvas layer for grayscale overlay
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "GrayscaleOverlay"
		canvas_layer.layer = 200  # Very high layer to affect everything
		get_tree().root.call_deferred("add_child", canvas_layer)
		
		# Wait for canvas_layer to be added before adding children
		await get_tree().process_frame
		
		# Create ColorRect for grayscale overlay
		# SCREEN_TEXTURE should work directly without BackBufferCopy in Godot 4
		var color_rect = ColorRect.new()
		color_rect.name = "GrayscaleRect"
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_rect.set_offsets_preset(Control.PRESET_FULL_RECT)  # Ensure it covers full screen
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_rect.color = Color.WHITE
		color_rect.modulate = Color.WHITE
		color_rect.visible = true
		
		# Get viewport to ensure proper sizing
		var viewport = get_viewport()
		if viewport:
			var viewport_size = viewport.get_visible_rect().size
			color_rect.size = viewport_size
			color_rect.position = Vector2.ZERO
			print("[REWIND] Viewport size: ", viewport_size, ", ColorRect size: ", color_rect.size)
		
		# Load and apply grayscale shader
		var shader = load("res://shaders/grayscale_overlay.gdshader")
		if shader:
			var shader_material = ShaderMaterial.new()
			shader_material.shader = shader
			shader_material.set_shader_parameter("intensity", 1.0)
			color_rect.material = shader_material
			print("[REWIND] Grayscale shader loaded and applied successfully")
			print("[REWIND] ColorRect visible: ", color_rect.visible, ", has material: ", color_rect.material != null)
		else:
			print("[REWIND] ERROR: Could not load grayscale shader at res://shaders/grayscale_overlay.gdshader")
		
		# Add ColorRect to canvas layer
		canvas_layer.add_child(color_rect)
		grayscale_overlay = color_rect
	else:
		grayscale_overlay = canvas_layer.get_node_or_null("GrayscaleRect")
		if grayscale_overlay:
			if grayscale_overlay.material:
				grayscale_overlay.material.set_shader_parameter("intensity", 1.0)
				print("[REWIND] Grayscale overlay material found and intensity set to 1.0")
			else:
				print("[REWIND] WARNING: Grayscale overlay has no material")
			grayscale_overlay.visible = true
			print("[REWIND] Grayscale overlay made visible")
		else:
			print("[REWIND] WARNING: Could not find GrayscaleRect in canvas layer")
	
	print("[REWIND] Enabled grayscale overlay")


func _disable_grayscale_overlay() -> void:
	"""Disable grayscale overlay effect on the screen."""
	if grayscale_overlay and is_instance_valid(grayscale_overlay):
		# Fade out the effect by setting intensity to 0
		if grayscale_overlay.material:
			grayscale_overlay.material.set_shader_parameter("intensity", 0.0)
		grayscale_overlay.visible = false
		grayscale_overlay = null
	
	# Optionally remove the canvas layer (or keep it for reuse)
	var canvas_layer = get_tree().root.get_node_or_null("GrayscaleOverlay")
	if canvas_layer:
		# Keep the layer but hide it for reuse
		var color_rect = canvas_layer.get_node_or_null("GrayscaleRect")
		if color_rect:
			color_rect.visible = false
	
	print("[REWIND] Disabled grayscale overlay")


func _perform_rewind() -> void:
	"""Perform the rewind action - restore player state and spawn animated shadow."""
	# This function is kept for fallback cases, but normally _start_rewind_traceback() is used
	if not rewind_enabled:
		return
	
	# Check if we have enough history
	var target_time = game_time - rewind_time
	if target_time < 0:
		# Not enough history available
		return
	
	var target_state = _find_state_at_time(target_time)
	if target_state.is_empty():
		# No valid state found
		return
	
	# Store current position BEFORE restoring (needed for path end point)
	var current_position_before_rewind = global_position
	
	# Extract path from state history (from target_time to current game_time)
	var path_points = _extract_path_from_history(target_time, game_time, current_position_before_rewind)
	
	# Restore player state
	global_position = target_state["position"]
	velocity = target_state["velocity"]
	facing_direction = target_state["facing_direction"]
	
	# Note: We don't restore all state flags (is_jumping, is_wall_sliding, etc.)
	# as they will be recalculated naturally by the physics system
	# However, we should cancel any active abilities that might conflict
	
	# Cancel conflicting states
	if is_attacking:
		is_attacking = false
		attack_timer = 0.0
	if is_ground_sliding:
		is_ground_sliding = false
		ground_slide_timer = 0.0
	if is_air_dashing:
		is_air_dashing = false
		air_dash_timer = 0.0
	if is_wall_running:
		is_wall_running = false
		wall_run_timer = 0.0
	if is_slamming:
		is_slamming = false
	if is_slam_frozen:
		is_slam_frozen = false
		slam_freeze_timer = 0.0
	
	# Spawn shadow with path animation
	_spawn_shadow_with_path(path_points)
	
	# Set cooldown
	rewind_cooldown_timer = rewind_cooldown


func _extract_path_from_history(start_time: float, end_time: float, end_position: Vector2) -> Array[Dictionary]:
	"""Extract all state snapshots from the given time range and return as path points."""
	var path_points: Array[Dictionary] = []
	
	# Filter and sort snapshots in the time range
	for snapshot in state_history:
		var timestamp = snapshot["timestamp"]
		if timestamp >= start_time and timestamp <= end_time:
			path_points.append({
				"position": snapshot["position"],
				"velocity": snapshot.get("velocity", Vector2.ZERO),
				"facing_direction": snapshot.get("facing_direction", facing_direction),
				"timestamp": timestamp
			})
	
	# Sort by timestamp to ensure correct order
	path_points.sort_custom(func(a, b): return a["timestamp"] < b["timestamp"])
	
	# If we have no points, create at least one from the start_time state
	if path_points.is_empty():
		var start_state = _find_state_at_time(start_time)
		if not start_state.is_empty():
			path_points.append({
				"position": start_state["position"],
				"velocity": start_state.get("velocity", Vector2.ZERO),
				"facing_direction": start_state.get("facing_direction", facing_direction),
				"timestamp": start_time
			})
	
	# Always ensure we have the end position (current position before rewind)
	# This might not be in history yet, so add it explicitly
	var end_point_exists = false
	for point in path_points:
		if abs(point["timestamp"] - end_time) < 0.001:
			end_point_exists = true
			break
	
	if not end_point_exists:
		# Add current position as final point
		# Use current state for velocity and facing_direction
		var current_state = _find_state_at_time(end_time)
		path_points.append({
			"position": end_position,  # Position before rewind
			"velocity": current_state.get("velocity", velocity) if not current_state.is_empty() else velocity,
			"facing_direction": current_state.get("facing_direction", facing_direction) if not current_state.is_empty() else facing_direction,
			"timestamp": end_time
		})
	
	return path_points


func _spawn_shadow_with_path(path_points: Array[Dictionary]) -> void:
	"""Spawn a shadow entity that will animate through the given path."""
	var shadow = ShadowScene.instantiate()
	
	# Set the path for the shadow to animate through
	shadow.set_path(path_points, rewind_time)
	
	# Add shadow to the scene (as a sibling of the player, not a child)
	get_parent().add_child(shadow)


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
	
	for bullet in bullets:
		if bullet and is_instance_valid(bullet) and bullet.has_method("parry"):
			# Check if bullet can be parried
			if "can_be_parried" in bullet and not bullet.can_be_parried:
				continue
			
			# Check distance (omnidirectional - no angle restriction)
			var distance = global_position.distance_to(bullet.global_position)
			if distance <= parry_detection_range:
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

func _execute_bullet_parry(bullet: Node2D) -> void:
	"""Execute the parry against a bullet."""
	if not bullet or not is_instance_valid(bullet):
		return
	
	if not bullet.has_method("parry"):
		return
	
	# Calculate parry direction (towards enemy or reverse bullet direction)
	var parry_direction = (bullet.global_position - global_position).normalized()
	
	# Call bullet's parry method
	bullet.parry(parry_direction)
	
	# Apply vertical boost to player
	attack_velocity = Vector2(velocity.x, -parry_vertical_boost)
	velocity = attack_velocity
	is_jumping = true  # Set jumping state so player has air control
	
	# Activate time slowdown effect
	_start_parry_time_slowdown()
	
	# Set cooldown
	attack_cooldown_timer = attack_cooldown
	
	# Visual feedback - brief flash
	animated_sprite.visible = false
	get_tree().create_timer(0.05, true, false, true).timeout.connect(func(): 
		if is_instance_valid(self) and not is_stunned: 
			animated_sprite.visible = true
	)


func _start_parry_time_slowdown() -> void:
	"""Start the time slowdown effect after a successful parry."""
	parry_time_slowdown_active = true
	parry_time_slowdown_timer = parry_time_duration
	Engine.time_scale = parry_time_scale


func _restore_normal_time() -> void:
	"""Restore normal time scale after parry slowdown ends."""
	parry_time_slowdown_active = false
	parry_time_slowdown_timer = 0.0
	Engine.time_scale = 1.0


# ====================================
# ANIMATION SYSTEM
# ====================================

func _setup_animations() -> void:
	var sf := SpriteFrames.new()
	
	# Load animation sequences with their specific FPS
	_load_animation_sequence(sf, "run", "res://Animation/Run/", "Run 复制_", 23, run_fps)
	_load_animation_sequence(sf, "jump", "res://Animation/jump/", "jump_", 28, jump_fps)
	_load_animation_sequence(sf, "wall_run", "res://Animation/Wall run 复制/", "Wall run 复制_", 18, wall_run_fps)
	_load_animation_sequence(sf, "slide", "res://Animation/Slide/", "Slide_", 10, ground_slide_fps, false)
	_load_animation_sequence(sf, "kick", "res://Animation/Kick/", "Kick_", 14, kick_fps, false)
	
	animated_sprite.sprite_frames = sf
	animated_sprite.play("run") # Default animation

func _load_animation_sequence(sf: SpriteFrames, anim_name: String, folder: String, prefix: String, count: int, fps: float, loop: bool = true) -> void:
	if not sf.has_animation(anim_name):
		sf.add_animation(anim_name)
	
	var frames_added = 0
	for i in range(1, count + 1):
		var frame_num = str(i).pad_zeros(3)
		var path = folder + prefix + frame_num + ".png"
		if ResourceLoader.exists(path):
			var tex = load(path)
			sf.add_frame(anim_name, tex)
			frames_added += 1
	
	if frames_added > 0:
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, loop)
	else:
		print("Warning: No frames found for animation: ", anim_name, " at path: ", folder + prefix)

# ====================================
# VISUAL EFFECTS & CAMERA
# ====================================

func apply_camera_shake(intensity: float, duration: float) -> void:
	"""Apply a screen shake effect."""
	camera_shake_intensity = intensity
	camera_shake_timer = duration

func _process_camera_shake(delta: float) -> void:
	"""Update the camera shake offset."""
	var camera = $Camera2D
	if not camera:
		return
		
	if camera_shake_timer > 0:
		camera_shake_timer -= delta
		camera.offset = Vector2(
			randf_range(-camera_shake_intensity, camera_shake_intensity),
			randf_range(-camera_shake_intensity, camera_shake_intensity)
		)
	else:
		camera.offset = Vector2.ZERO


func _update_animations() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
		
	var is_moving_horizontally = abs(velocity.x) > 10.0
	
	# Determine which animation to play and its scale/offset
	var current_scale = run_scale
	var current_offset = run_offset
	
	if is_attacking or (animated_sprite.animation == "kick" and animated_sprite.is_playing()):
		current_scale = kick_scale
		current_offset = kick_offset
		if animated_sprite.animation != "kick":
			animated_sprite.play("kick")
			print("[DEBUG-ANIM] Started Kick")
		animated_sprite.speed_scale = 1.0
	elif is_ground_sliding:
		current_scale = ground_slide_scale
		current_offset = ground_slide_offset
		if animated_sprite.animation != "slide":
			animated_sprite.play("slide")
			print("[DEBUG-ANIM] Started Slide Animation")
		
		# Ensure it stays at the last frame if it reached it
		var frame_count = animated_sprite.sprite_frames.get_frame_count("slide")
		if animated_sprite.frame == frame_count - 1:
			if animated_sprite.is_playing():
				animated_sprite.stop()
				print("[DEBUG-ANIM] Slide animation finished, locking to last frame (%d)" % (frame_count - 1))
			# Force it to stay at the last frame to prevent any possible wrap-around
			animated_sprite.frame = frame_count - 1
		
		# Detailed debug for sliding frame
		# print("[DEBUG-FRAME] Sliding: Animation=%s, Frame=%d/%d, Playing=%s" % [animated_sprite.animation, animated_sprite.frame, frame_count-1, animated_sprite.is_playing()])
		
		animated_sprite.speed_scale = 1.0
	elif is_on_floor():
		current_scale = run_scale
		current_offset = run_offset
		if is_moving_horizontally:
			# FIX: Ensure animation plays if it was previously stopped (e.g. from idle)
			if animated_sprite.animation != "run" or not animated_sprite.is_playing():
				animated_sprite.play("run")
				print("[DEBUG-ANIM] Playing Run (moving horizontally)")
			animated_sprite.speed_scale = max(0.5, abs(velocity.x) / max_speed)
		else:
			# If stopped on floor, stay on first frame of run as idle
			if animated_sprite.animation != "run" or animated_sprite.is_playing() or animated_sprite.frame != 0:
				animated_sprite.play("run")
				animated_sprite.stop()
				animated_sprite.frame = 0
				print("[DEBUG-ANIM] Set Idle (run frame 0)")
			animated_sprite.speed_scale = 1.0
	elif is_wall_running:
		current_scale = wall_run_scale
		current_offset = wall_run_offset
		if animated_sprite.animation != "wall_run" or not animated_sprite.is_playing():
			animated_sprite.play("wall_run")
			print("[DEBUG-ANIM] Started Wall Run")
		animated_sprite.speed_scale = 1.0
	else:
		# In air
		current_scale = jump_scale
		current_offset = jump_offset
		if animated_sprite.animation != "jump" or not animated_sprite.is_playing():
			animated_sprite.play("jump")
			print("[DEBUG-ANIM] Started Jump/Air")
		
		# For jump animation, we can tie frame to vertical velocity for a more dynamic look
		# or just let it play. Since it has 28 frames, let's play it.
		animated_sprite.speed_scale = 1.0
	
	# Apply scale
	animated_sprite.scale = Vector2(current_scale, current_scale)
	
	# Handle flipping
	if is_attacking or (animated_sprite.animation == "kick" and animated_sprite.is_playing()):
		animated_sprite.flip_h = facing_direction < 0
	elif is_ground_sliding:
		animated_sprite.flip_h = facing_direction < 0
	elif is_moving_horizontally:
		animated_sprite.flip_h = velocity.x < 0
	elif is_on_wall:
		# When on wall, face away from wall normal (towards open space)
		# wall_normal points AWAY from the wall. 
		# If wall_normal.x > 0, wall is on left, we should face right (flip_h = false)
		# If wall_normal.x < 0, wall is on right, we should face left (flip_h = true)
		animated_sprite.flip_h = wall_normal.x < 0
		
	# Apply additional flip for wall run if requested (flips 180 degrees horizontally)
	if animated_sprite.animation == "wall_run" and wall_run_base_flip:
		animated_sprite.flip_h = !animated_sprite.flip_h
		
	# Apply offset (flip X based on flip_h so the offset is always relative to character facing)
	var final_offset = current_offset
	if animated_sprite.flip_h:
		final_offset.x = -current_offset.x
	animated_sprite.position = final_offset


func _spawn_dust(mode: String, pos_offset: Vector2 = Vector2.ZERO, dir: Vector2 = Vector2.ZERO) -> void:
	if not DustParticlesScene:
		return
	var dust = DustParticlesScene.instantiate()
	get_parent().add_child(dust) # Spawn in world space
	dust.global_position = global_position + pos_offset
	dust.setup(mode, dir)


func _handle_dust_effects(delta: float) -> void:
	if dust_spawn_timer > 0:
		dust_spawn_timer -= delta
		return
		
	if is_on_floor():
		if is_ground_sliding:
			_spawn_dust("slide", Vector2(0, 32))
			dust_spawn_timer = 0.05 # Fast puffs for sliding
		elif is_running and abs(velocity.x) > max_speed * 0.8:
			# Spawn slightly behind the feet
			var dust_offset = Vector2(-facing_direction * 10, 32)
			_spawn_dust("run", dust_offset, Vector2(-facing_direction, 0))
			dust_spawn_timer = 0.15 # Medium puffs for running
