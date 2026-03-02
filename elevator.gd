extends Node2D

@onready var main_body: RigidBody2D = $RigidBody2D
@onready var door: CollisionShape2D = $RigidBody2D/Door
@onready var detection_area: Area2D = $RigidBody2D/DetectionArea
@onready var rewind_trigger: Area2D = $RigidBody2D/ElevatorRewindTrigger
@onready var timer: Timer = $Timer
@onready var smoke_particles: CPUParticles2D = $SmokeParticles

var player_inside: bool = false
var has_dropped: bool = false
var impact_triggered: bool = false

# Audio
var sfx_player: AudioStreamPlayer
var fall_sfx: AudioStream
var ride_sfx: AudioStream

# Reference to the elevator guard
var guard_ref: Node2D = null

# Door vertical positions (relative to RigidBody2D)
# Slide down to open so it doesn't protrude above
const DOOR_CLOSED_Y = 0
const DOOR_OPEN_Y = 760 

func _ready() -> void:
	# Door starts off open (shifted down)
	door.position.y = DOOR_OPEN_Y
	door.disabled = true
	door.visible = false
	
	# Disable rewind trigger initially
	if rewind_trigger:
		rewind_trigger.monitoring = false
	
	# Start as static/frozen
	main_body.freeze = true
	main_body.contact_monitor = true
	main_body.max_contacts_reported = 4
	
	# Connect signals
	detection_area.body_entered.connect(_on_player_entered)
	timer.timeout.connect(_on_timer_timeout)
	# We use _integrate_forces for better collision normal detection
	
	# Find guard reference (assuming it's a sibling in the scene tree)
	# We use call_deferred to ensure the parent and siblings are ready
	call_deferred("_find_and_connect_guard")
	
	# Setup audio
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	# Use Master bus for elevator fall as it's a big event, or Game if preferred
	if AudioServer.get_bus_index("Game") != -1:
		sfx_player.bus = "Game"
	else:
		sfx_player.bus = "Master"
	add_child(sfx_player)
	
	# Load elevator fall sound
	if ResourceLoader.exists("res://audio/elevatorFall.ogg"):
		fall_sfx = load("res://audio/elevatorFall.ogg")
	elif ResourceLoader.exists("res://audio/elevatorFall.mp3"):
		fall_sfx = load("res://audio/elevatorFall.mp3")

	# Load riding sound
	if ResourceLoader.exists("res://audio/elevatorRiding.ogg"):
		ride_sfx = load("res://audio/elevatorRiding.ogg")
	elif ResourceLoader.exists("res://audio/elevatorRiding.mp3"):
		ride_sfx = load("res://audio/elevatorRiding.mp3")

func _find_and_connect_guard() -> void:
	var parent = get_parent()
	if parent:
		guard_ref = parent.get_node_or_null("Elevator Guard")
		if guard_ref and guard_ref.has_signal("enemy_destroyed"):
			if not guard_ref.enemy_destroyed.is_connected(_on_guard_destroyed):
				guard_ref.enemy_destroyed.connect(_on_guard_destroyed)

func _on_guard_destroyed() -> void:
	# Guard died - check if player is waiting in the elevator
	if player_inside:
		return
		
	var overlapping_bodies = detection_area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group("player") or body.name == "Player":
			_start_elevator_sequence()
			break

func _on_player_entered(body: Node2D) -> void:
	if (body.is_in_group("player") or body.name == "Player") and not player_inside:
		# Check if guard is still active (not destroyed)
		if guard_ref and is_instance_valid(guard_ref):
			if "is_destroyed" in guard_ref and not guard_ref.is_destroyed:
				return # Guard is alive, elevator won't start
		
		_start_elevator_sequence()

func _start_elevator_sequence() -> void:
	if player_inside:
		return
		
	player_inside = true
	# Slide door closed
	door.visible = true
	door.set_deferred("disabled", false)
	var tween = create_tween()
	tween.tween_property(door, "position:y", DOOR_CLOSED_Y, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Start 3 second delay
	timer.start(3.0)
	
	# Play riding sound (while waiting for drop)
	if ride_sfx:
		sfx_player.stream = ride_sfx
		sfx_player.volume_db = -5.0
		sfx_player.play()

func _on_timer_timeout() -> void:
	# Become physics object and drop straight down
	main_body.freeze = false
	has_dropped = true
	# Lock rotation to keep it upright
	main_body.lock_rotation = true
	
	# Stop riding sound when drop starts
	if sfx_player.playing and sfx_player.stream == ride_sfx:
		sfx_player.stop()

# Physics callback to detect ground specifically
func _physics_process(_delta: float) -> void:
	if has_dropped and not impact_triggered:
		# Check all contacts using the direct state
		var state = PhysicsServer2D.body_get_direct_state(main_body.get_rid())
		if state:
			for i in range(state.get_contact_count()):
				# Ignore collisions with the player
				var collider_id = state.get_contact_collider_id(i)
				var collider = instance_from_id(collider_id)
				if collider and (collider.is_in_group("player") or collider.name == "Player"):
					continue
					
				var normal = state.get_contact_local_normal(i)
				# normal.y < -0.7 means we hit something BELOW us (the floor is pushing up)
				if normal.y < -0.7:
					_handle_landing()
					break

func _handle_landing() -> void:
	impact_triggered = true
	has_dropped = false
	
	# Capture the current global position before freezing
	var landing_pos = main_body.global_position
	
	# Play impact sound (elevator reached bottom)
	if fall_sfx:
		sfx_player.stream = fall_sfx
		sfx_player.volume_db = -5.0
		sfx_player.play()
	
	# Screenshake
	_trigger_screenshake()
	
	# Stop the elevator and freeze it in place
	main_body.linear_velocity = Vector2.ZERO
	main_body.freeze = true
	
	# Move the root node to the landing position and reset child local position.
	# This prevents the RigidBody2D from "snapping back" to the root's original origin,
	# which caused the player to teleport and left an "invisible floor" at the top.
	global_position = landing_pos
	main_body.position = Vector2.ZERO
	
	# Smoke effects at the point of impact
	if smoke_particles:
		# Reset smoke position to its intended local offset (bottom of elevator)
		smoke_particles.position = Vector2(0, 385)
		smoke_particles.restart()
		smoke_particles.emitting = true
	
	# Slide door open again
	# Disable collision immediately so it doesn't hit the ground as it slides down
	door.set_deferred("disabled", true)
	var tween = create_tween()
	tween.tween_property(door, "position:y", DOOR_OPEN_Y, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func(): door.visible = false)
	
	# Enable auto-rewind trigger when elevator lands
	if rewind_trigger:
		rewind_trigger.set_deferred("monitoring", true)
		# Check if player is already inside the trigger area
		call_deferred("_check_player_in_rewind_trigger")


func _check_player_in_rewind_trigger() -> void:
	"""Check if player is already inside the rewind trigger when it's enabled."""
	if not rewind_trigger or not rewind_trigger.monitoring:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().root.find_child("Player", true, false)
	
	if player:
		# Use position-based check because player's collision might be disabled during rewind
		var collision_shape = rewind_trigger.get_node_or_null("CollisionShape2D")
		if collision_shape and collision_shape.shape:
			var shape = collision_shape.shape
			var shape_global_pos = collision_shape.global_position
			var player_pos = player.global_position
			
			var is_inside = false
			if shape is RectangleShape2D:
				var rect_shape = shape as RectangleShape2D
				var half_size = rect_shape.size / 2.0
				var rect = Rect2(shape_global_pos - half_size, rect_shape.size)
				is_inside = rect.has_point(player_pos)
			elif shape is CircleShape2D:
				var circle_shape = shape as CircleShape2D
				var distance = player_pos.distance_to(shape_global_pos)
				is_inside = distance <= circle_shape.radius
			else:
				# Fallback
				is_inside = rewind_trigger.overlaps_body(player)
			
			if is_inside:
				# Player is already in the trigger, activate it immediately
				if player.has_method("set_elevator_auto_rewind_zone"):
					player.set_elevator_auto_rewind_zone(true)

func _trigger_screenshake() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().root.find_child("Player", true, false)
	
	if player and player.has_method("apply_camera_shake"):
		# Intense shake for the heavy elevator impact
		player.apply_camera_shake(35.0, 1.0)
