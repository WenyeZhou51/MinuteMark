extends Area2D

## Tutorial block that freezes time and locks player actions until the instructed action is performed

@export var block_id: String = "tutorial_1"
@export var prerequisite_block_id: String = ""  # Empty = no prerequisite
@export_multiline var instruction_message: String = "Press and hold R to rewind"
@export var allowed_action: String = "rewind"  # "rewind", "dash", "jump", "kick", "move", "slam"

var triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Set process mode so we can still detect when paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func _on_body_entered(body: Node2D) -> void:
	print("TutorialBlock: body_entered - ", body.name if body else "null")
	
	if not body.is_in_group("player"):
		print("TutorialBlock: Body is not player, ignoring")
		return
	
	print("TutorialBlock: Player entered block: ", block_id)
	
	# Check if this block was already completed
	if TutorialBlockManager.is_block_completed(block_id):
		# Already completed, don't trigger again
		print("TutorialBlock: Block already completed, ignoring")
		triggered = true
		return
	
	# Check if prerequisite is met
	if prerequisite_block_id != "":
		var prereq_completed = TutorialBlockManager.is_block_completed(prerequisite_block_id)
		print("TutorialBlock: Prerequisite ", prerequisite_block_id, " completed: ", prereq_completed)
		if not prereq_completed:
			# Prerequisite not met, ignore this trigger
			# Don't set triggered = true here, so we can check again later (e.g., after rewind)
			print("TutorialBlock: Prerequisite not met, ignoring trigger (will check again on rewind end)")
			return
	
	# If already triggered and tutorial is active, don't trigger again
	if triggered:
		print("TutorialBlock: Already triggered, ignoring")
		return
	
	# Trigger the tutorial
	print("TutorialBlock: Triggering tutorial for block: ", block_id)
	triggered = true
	TutorialBlockManager.start_tutorial(block_id, allowed_action, instruction_message)

func check_player_inside() -> void:
	"""Check if player is currently inside this block. Used when rewind ends or during rewind."""
	print("TutorialBlock: check_player_inside called for block: ", block_id)
	
	# Find the player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("TutorialBlock: No player found")
		return
	
	# Check if player is inside using manual position check
	# This works even when position is set directly during rewind
	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		print("TutorialBlock: No collision shape found")
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
				print("TutorialBlock: Player found inside block: ", block_id)
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
		print("TutorialBlock: Player found inside block (manual check): ", block_id)
		# Player is inside - trigger the tutorial check
		_on_body_entered(player)
	else:
		print("TutorialBlock: Player not inside block (position: ", player.global_position, ", rect: ", expanded_rect, ")")
