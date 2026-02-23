extends "res://enemy_bullet.gd"

# Parry Tutorial Bullet - Special bullet that STOPS near the player and waits for parry
# Used by the parry tutorial enemy to teach players the parry mechanic
# Hovers at a fixed distance from player until parried

signal tutorial_triggered  ## Emitted when this bullet triggers the tutorial

@export var stop_distance: float = 70.0  ## Distance from player where bullet stops and hovers
@export var tutorial_message: String = "KICK to deflect the bullet!"  ## Tutorial message to display

var has_triggered_tutorial: bool = false
var player_ref: Node2D = null
var is_stopped: bool = false
var hover_offset: Vector2 = Vector2.ZERO  ## Store the offset position where we stopped

func _ready() -> void:
	super._ready()
	
	# Find player reference
	await get_tree().process_frame
	_find_player()

func _find_player() -> void:
	"""Find and store reference to player."""
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_ref = players[0]

func _physics_process(delta: float) -> void:
	# Check if we should stop the bullet before normal physics
	if not is_stopped and player_ref and is_instance_valid(player_ref):
		var distance_to_player = global_position.distance_to(player_ref.global_position)
		
		# Stop when we get close enough
		if distance_to_player <= stop_distance:
			_stop_and_trigger_tutorial()
	
	# If bullet is stopped, freeze it in place
	if is_stopped:
		# Set velocity to zero BEFORE calling parent to prevent movement
		velocity = Vector2.ZERO
		
		# Update lifetime (from parent) but don't move
		lifetime_timer += delta
		if lifetime_timer >= lifetime:
			queue_free()
			return
		
		# Update rotation to face player
		if player_ref and is_instance_valid(player_ref):
			var direction_to_player = (player_ref.global_position - global_position).normalized()
			rotation = direction_to_player.angle()
		
		# Hover at fixed position relative to player
		if player_ref and is_instance_valid(player_ref):
			var target_pos = player_ref.global_position + hover_offset
			global_position = target_pos
	else:
		# Normal bullet behavior - call parent which handles movement
		super._physics_process(delta)

func _stop_and_trigger_tutorial() -> void:
	"""Stop the bullet and trigger the parry tutorial."""
	if has_triggered_tutorial:
		return
	
	has_triggered_tutorial = true
	is_stopped = true
	
	# Immediately stop all movement
	velocity = Vector2.ZERO
	
	# Calculate and store the offset from player where we stopped
	hover_offset = global_position - player_ref.global_position
	
	# Make sure we're at exactly the stop distance
	hover_offset = hover_offset.normalized() * stop_distance
	global_position = player_ref.global_position + hover_offset
	
	# CRITICAL: Disable collision with player while hovering to prevent accidental hits
	# Keep collision layer the same, but remove player from collision mask
	set_collision_mask_value(1, false)  # Layer 1 = player and walls - disable player collision
	
	# Emit signal to notify the shooter enemy (enemy will continue shooting)
	tutorial_triggered.emit()
	
	# Use TutorialBlockManager to start tutorial with kick action allowed
	if TutorialBlockManager:
		# Create a unique block ID for this bullet
		var block_id = "parry_tutorial_bullet_" + str(get_instance_id())
		TutorialBlockManager.start_tutorial(block_id, "kick", tutorial_message)
		
		# Connect to tutorial ended signal
		if not TutorialBlockManager.tutorial_ended.is_connected(_on_tutorial_ended):
			TutorialBlockManager.tutorial_ended.connect(_on_tutorial_ended)
	else:
		push_error("[ParryTutorialBullet] TutorialBlockManager not found!")

func _on_tutorial_ended(_block_id: String) -> void:
	"""Called when tutorial ends (player performed the parry)."""
	# Resume normal bullet behavior - the parry system has already set the new velocity
	is_stopped = false
	
	# Re-enable collision detection for parried bullet (will collide with enemies now)
	# The parry() function in parent already changed collision mask to detect enemies
	
	# Note: Don't set velocity here - the parry() function from parent already handled it
	
	# Disconnect from signal
	if TutorialBlockManager and TutorialBlockManager.tutorial_ended.is_connected(_on_tutorial_ended):
		TutorialBlockManager.tutorial_ended.disconnect(_on_tutorial_ended)

