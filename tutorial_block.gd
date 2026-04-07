extends Area2D

## Tutorial block that freezes time and locks player actions until the instructed action is performed

@export var block_id: String = "tutorial_1"
@export var prerequisite_block_id: String = ""  # Empty = no prerequisite
@export_multiline var instruction_message: String = "Press and hold R to rewind"
@export var allowed_action: String = "rewind"  # "rewind", "dash", "jump", "kick", "move", "slam"
@export var require_minimum_rewind_hold: bool = false ## For rewind tutorials: require minimum 0.5s hold (prevents early release)
@export_group("Slow Motion Entry")
@export var pre_freeze_slow_mo_time: float = 0.0 ## Duration of slow motion before freezing (in real seconds)
@export var pre_freeze_slow_mo_scale: float = 0.1 ## Time scale during the slow motion phase
@export var forced_facing_direction: int = 0 ## If non-zero, forces the player to face this direction (1=Right, -1=Left)
@export var next_tutorial_block_id: String = "" ## ID of the next tutorial block to chain to immediately
@export var trigger_delay: float = 0.0 ## Delay in seconds before triggering after player enters (0 = immediate)

var triggered: bool = false
var player_inside: bool = false
var delay_timer: Timer = null

func _ready() -> void:
	# Register with manager
	TutorialBlockManager.register_block(block_id, self)
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Set process mode so we can still detect when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Connect to tutorial manager signal to handle cleanup
	if not TutorialBlockManager.tutorial_ended.is_connected(_on_tutorial_ended):
		TutorialBlockManager.tutorial_ended.connect(_on_tutorial_ended)

func _on_tutorial_ended(ended_block_id: String) -> void:
	# If our block ended and we modified time scale, restore it
	if ended_block_id == block_id and pre_freeze_slow_mo_time > 0:
		Engine.time_scale = 1.0

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	player_inside = true
	
	# Check if this block was already completed
	if TutorialBlockManager.is_block_completed(block_id):
		# Already completed, don't trigger again
		triggered = true
		return
	
	# Check if prerequisite is met
	if prerequisite_block_id != "":
		var prereq_completed = TutorialBlockManager.is_block_completed(prerequisite_block_id)
		if not prereq_completed:
			# Prerequisite not met, ignore this trigger
			# Don't set triggered = true here, so we can check again later (e.g., after rewind)
			return
	
	# If already triggered and tutorial is active, don't trigger again
	if triggered:
		return
	
	# If there's a delay, start a timer
	if trigger_delay > 0.0:
		# Cancel any existing timer
		if delay_timer:
			delay_timer.queue_free()
		
		delay_timer = Timer.new()
		delay_timer.wait_time = trigger_delay
		delay_timer.one_shot = true
		delay_timer.timeout.connect(_on_delay_timer_timeout)
		add_child(delay_timer)
		delay_timer.start()
	else:
		# No delay, trigger immediately
		_trigger_tutorial()

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	
	player_inside = false
	
	# Cancel the delay timer if player leaves before delay completes
	if delay_timer and delay_timer.time_left > 0:
		delay_timer.queue_free()
		delay_timer = null

func _on_delay_timer_timeout() -> void:
	# Only trigger if player is still inside
	if player_inside and not triggered:
		_trigger_tutorial()
	
	delay_timer = null

func _trigger_tutorial() -> void:
	# Don't trigger if player is currently rewinding - prevents softlock
	var _p = get_tree().get_first_node_in_group("player")
	if _p and (
		("is_rewind_holding" in _p and _p.is_rewind_holding) or
		("is_rewind_tracing" in _p and _p.is_rewind_tracing)
	):
		return

	triggered = true
	
	if pre_freeze_slow_mo_time > 0:
		Engine.time_scale = pre_freeze_slow_mo_scale
		
		# Lock player input and force state during the slow mo fall
		var player = get_tree().get_first_node_in_group("player")
		if player:
			# Lock input (block all actions but allow physics/gravity)
			if player.has_method("set_tutorial_lock"):
				player.set_tutorial_lock(true, "none")
			
			# Force vertical fall only (kill horizontal velocity)
			if "velocity" in player:
				player.velocity.x = 0
			
			# Force facing direction immediately if requested
			if forced_facing_direction != 0 and "facing_direction" in player:
				player.facing_direction = forced_facing_direction
				if player.has_method("_update_animations"):
					player._update_animations()

		get_tree().create_timer(pre_freeze_slow_mo_time, true, false, true).timeout.connect(func():
			# Restore time scale before freezing/pausing
			Engine.time_scale = 1.0
			
			TutorialBlockManager.start_tutorial(block_id, allowed_action, instruction_message, require_minimum_rewind_hold)
		)
	else:
		TutorialBlockManager.start_tutorial(block_id, allowed_action, instruction_message, require_minimum_rewind_hold)

func check_player_inside() -> void:
	"""Check if player is currently inside this block. Used when rewind ends or during rewind."""
	# Find the player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Check if player is inside using manual position check
	# This works even when position is set directly during rewind
	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return
	
	# Get the area's bounds in global space
	var shape_rect: Rect2
	if collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		var shape_size = rect_shape.size
		var shape_pos = collision_shape.global_position
		shape_rect = Rect2(shape_pos - shape_size / 2, shape_size)
	elif collision_shape.shape is CircleShape2D:
		var circle_shape = collision_shape.shape as CircleShape2D
		var radius = circle_shape.radius
		var center = collision_shape.global_position
		shape_rect = Rect2(center - Vector2(radius, radius), Vector2(radius * 2, radius * 2))
	else:
		# Fallback to overlapping bodies for other shapes
		var overlapping_bodies = get_overlapping_bodies()
		for body in overlapping_bodies:
			if body.is_in_group("player"):
				_on_body_entered(body)
				return
		return
	
	# Check if player's position is within the bounds
	# We need to account for player's collision shape size
	var player_collision = player.get_node_or_null("CollisionShape2D")
	var player_size = Vector2(32, 64)  # Default player size estimate
	if player_collision and player_collision.shape is RectangleShape2D:
		var player_rect_shape = player_collision.shape as RectangleShape2D
		player_size = player_rect_shape.size
	
	# Expand the area rect slightly to account for player size
	var expanded_rect = Rect2(
		shape_rect.position - player_size / 2,
		shape_rect.size + player_size
	)
	
	if expanded_rect.has_point(player.global_position):
		# Player is inside - trigger the tutorial check
		_on_body_entered(player)
