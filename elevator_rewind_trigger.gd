extends Area2D

var player_in_zone: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta):
	# Continuously check if player is in zone (handles cases where player was already inside when trigger activated)
	# Use position-based check because player's collision is disabled during rewind
	if monitoring:
		var player = get_tree().get_first_node_in_group("player")
		if not player:
			player = get_tree().root.find_child("Player", true, false)
		
		if player:
			var is_overlapping = _check_player_position(player)
			if is_overlapping and not player_in_zone:
				# Player just entered (or was already here when trigger activated)
				player_in_zone = true
				if player.has_method("set_elevator_auto_rewind_zone"):
					player.set_elevator_auto_rewind_zone(true)
			elif not is_overlapping and player_in_zone:
				# Player just exited
				player_in_zone = false
				if player.has_method("set_elevator_auto_rewind_zone"):
					player.set_elevator_auto_rewind_zone(false)

func _check_player_position(player: Node2D) -> bool:
	"""Check if player's position is inside this trigger's collision shape."""
	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		# Fallback to overlaps_body if no shape
		return overlaps_body(player)
	
	var shape = collision_shape.shape
	var shape_global_pos = collision_shape.global_position
	var player_pos = player.global_position
	
	if shape is RectangleShape2D:
		var rect_shape = shape as RectangleShape2D
		var half_size = rect_shape.size / 2.0
		var rect = Rect2(shape_global_pos - half_size, rect_shape.size)
		return rect.has_point(player_pos)
	elif shape is CircleShape2D:
		var circle_shape = shape as CircleShape2D
		var distance = player_pos.distance_to(shape_global_pos)
		return distance <= circle_shape.radius
	
	# Fallback for other shapes
	return overlaps_body(player)

func _on_body_entered(body):
	if body.is_in_group("player") or body.name == "Player":
		player_in_zone = true
		if body.has_method("set_elevator_auto_rewind_zone"):
			body.set_elevator_auto_rewind_zone(true)

func _on_body_exited(body):
	if body.is_in_group("player") or body.name == "Player":
		player_in_zone = false
		if body.has_method("set_elevator_auto_rewind_zone"):
			body.set_elevator_auto_rewind_zone(false)

