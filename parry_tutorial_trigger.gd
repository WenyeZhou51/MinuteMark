extends Area2D

## Parry Tutorial Trigger - monitors parry tutorial enemy bullets and
## triggers tutorial lock when bullet is about to hit the player

@export var parry_tutorial_enemy: Node2D  ## The parry tutorial enemy to monitor
@export var trigger_distance: float = 150.0  ## Distance from player to trigger tutorial (pixels)
@export var tutorial_message: String = "Kick to deflect bullet"  ## Message to show

var has_triggered: bool = false
var is_monitoring: bool = false
var player_ref: Node2D = null
var active_bullet: Node2D = null

func _ready() -> void:
	# Find player reference
	await get_tree().process_frame
	_find_player()
	
	# Check if enemy is assigned
	if not parry_tutorial_enemy:
		push_error("[ParryTutorialTrigger] ERROR: No parry tutorial enemy assigned!")
		return
	
	# Wait for player to enter the trigger area to start monitoring
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _find_player() -> void:
	"""Find and store reference to player."""
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_ref = players[0]

func _on_body_entered(body: Node2D) -> void:
	"""Start monitoring when player enters the trigger area."""
	if body.is_in_group("player"):
		is_monitoring = true

func _on_body_exited(body: Node2D) -> void:
	"""Stop monitoring when player exits the trigger area."""
	if body.is_in_group("player"):
		is_monitoring = false

func _physics_process(_delta: float) -> void:
	# Only monitor when active and not yet triggered
	if not is_monitoring or has_triggered:
		return
	
	# Make sure we have player reference
	if not player_ref or not is_instance_valid(player_ref):
		_find_player()
		return
	
	# Find bullets from the parry tutorial enemy
	var bullets = get_tree().get_nodes_in_group("enemy_projectiles")
	for bullet in bullets:
		# Check if this bullet is from our parry tutorial enemy
		if not bullet or not is_instance_valid(bullet):
			continue
		
		# Check if bullet has shooter_enemy property and it matches our enemy
		if "shooter_enemy" in bullet:
			if bullet.shooter_enemy == parry_tutorial_enemy:
				# Check distance to player
				var distance_to_player = bullet.global_position.distance_to(player_ref.global_position)
				
				# Trigger when bullet is at the right distance (close but not too close)
				if distance_to_player <= trigger_distance and distance_to_player > 50.0:
					# Make sure bullet is moving towards player
					if "velocity" in bullet:
						var bullet_to_player = (player_ref.global_position - bullet.global_position).normalized()
						var bullet_direction = bullet.velocity.normalized()
						var dot_product = bullet_to_player.dot(bullet_direction)
						
						# Only trigger if bullet is heading towards player (dot > 0.5 = within ~60 degrees)
						if dot_product > 0.5:
							_trigger_tutorial(bullet)
							return

func _trigger_tutorial(bullet: Node2D) -> void:
	"""Trigger the tutorial lock."""
	if has_triggered:
		return
	
	has_triggered = true
	active_bullet = bullet
	
	# Use TutorialBlockManager to start tutorial with kick action allowed
	if TutorialBlockManager:
		# Create a unique block ID for this trigger
		var block_id = "parry_tutorial_" + str(get_instance_id())
		TutorialBlockManager.start_tutorial(block_id, "kick", tutorial_message)
		
		# Connect to tutorial ended signal to detect when player completes it
		if not TutorialBlockManager.tutorial_ended.is_connected(_on_tutorial_ended):
			TutorialBlockManager.tutorial_ended.connect(_on_tutorial_ended)
	else:
		push_error("[ParryTutorialTrigger] TutorialBlockManager not found!")

func _on_tutorial_ended(_block_id: String) -> void:
	"""Called when tutorial ends (player performed the parry)."""
	# Disconnect from signal
	if TutorialBlockManager and TutorialBlockManager.tutorial_ended.is_connected(_on_tutorial_ended):
		TutorialBlockManager.tutorial_ended.disconnect(_on_tutorial_ended)

