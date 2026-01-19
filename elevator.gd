extends Node2D

@onready var main_body: RigidBody2D = $RigidBody2D
@onready var door: CollisionShape2D = $RigidBody2D/Door
@onready var detection_area: Area2D = $RigidBody2D/DetectionArea
@onready var timer: Timer = $Timer
@onready var smoke_particles: CPUParticles2D = $SmokeParticles

var player_inside: bool = false
var has_dropped: bool = false
var impact_triggered: bool = false

# Door vertical positions (relative to RigidBody2D)
# Slide down to open so it doesn't protrude above
const DOOR_CLOSED_Y = 0
const DOOR_OPEN_Y = 760 

func _ready() -> void:
	# Door starts off open (shifted down)
	door.position.y = DOOR_OPEN_Y
	door.disabled = true
	door.visible = false
	
	# Start as static/frozen
	main_body.freeze = true
	main_body.contact_monitor = true
	main_body.max_contacts_reported = 4
	
	# Connect signals
	detection_area.body_entered.connect(_on_player_entered)
	timer.timeout.connect(_on_timer_timeout)
	# We use _integrate_forces for better collision normal detection

func _on_player_entered(body: Node2D) -> void:
	if (body.is_in_group("player") or body.name == "Player") and not player_inside:
		player_inside = true
		# Slide door closed
		door.visible = true
		door.set_deferred("disabled", false)
		var tween = create_tween()
		tween.tween_property(door, "position:y", DOOR_CLOSED_Y, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# Start 3 second delay
		timer.start(3.0)

func _on_timer_timeout() -> void:
	# Become physics object and drop straight down
	main_body.freeze = false
	has_dropped = true
	# Lock rotation to keep it upright
	main_body.lock_rotation = true

# Physics callback to detect ground specifically
func _physics_process(_delta: float) -> void:
	if has_dropped and not impact_triggered:
		# Check all contacts using the direct state
		var state = PhysicsServer2D.body_get_direct_state(main_body.get_rid())
		if state:
			for i in range(state.get_contact_count()):
				var normal = state.get_contact_local_normal(i)
				# normal.y < -0.7 means we hit something BELOW us (the floor is pushing up)
				if normal.y < -0.7:
					_handle_landing()
					break

func _handle_landing() -> void:
	impact_triggered = true
	has_dropped = false
	
	# Screenshake
	_trigger_screenshake()
	
	# Smoke effects at the point of impact
	if smoke_particles:
		smoke_particles.global_position = main_body.global_position + Vector2(0, 385)
		smoke_particles.restart()
		smoke_particles.emitting = true
	
	# Slide door open again
	# Disable collision immediately so it doesn't hit the ground as it slides down
	door.set_deferred("disabled", true)
	var tween = create_tween()
	tween.tween_property(door, "position:y", DOOR_OPEN_Y, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func(): door.visible = false)
	
	# Stop the elevator and freeze it in place
	# Small delay to let it settle
	await get_tree().create_timer(0.1).timeout
	main_body.linear_velocity = Vector2.ZERO
	main_body.freeze = true

func _trigger_screenshake() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().root.find_child("Player", true, false)
	
	if player and player.has_method("apply_camera_shake"):
		# Intense shake for the heavy elevator impact
		player.apply_camera_shake(35.0, 1.0)
