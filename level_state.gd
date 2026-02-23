# level_state.gd
extends Node

# Store initial state for quick reset
var initial_player_position: Vector2
var initial_player_rotation: float
var initial_player_scale: Vector2

# References to live objects
var player: CharacterBody2D
var enemies: Array[Node] = []
var kickables: Array[Node] = []
var triggers: Array[Node] = []
var timer_ui: Node
var level_node: Node2D

# Initial state data
var initial_enemies: Array[Dictionary] = []
var initial_kickables: Array[Dictionary] = []

func capture_initial_state(level: Node2D) -> void:
	"""Call this once in level _ready() to snapshot the starting state"""
	level_node = level
	
	# Find player
	player = level.get_node_or_null("Player")
	if not player:
		player = level.get_tree().get_first_node_in_group("player")
	
	if player:
		initial_player_position = player.global_position
		initial_player_rotation = player.rotation
		initial_player_scale = player.scale
	
	# Find and capture all enemies
	enemies.clear()
	initial_enemies.clear()
	for node in level.get_tree().get_nodes_in_group("enemies"):
		enemies.append(node)
		initial_enemies.append({
			"node": node,
			"position": node.global_position,
			"rotation": node.rotation
		})
	
	# Also check for "enemy" group (singular)
	for node in level.get_tree().get_nodes_in_group("enemy"):
		if node not in enemies:
			enemies.append(node)
			initial_enemies.append({
				"node": node,
				"position": node.global_position,
				"rotation": node.rotation
			})
	
	# Find and capture all kickable objects
	kickables.clear()
	initial_kickables.clear()
	for node in level.get_tree().get_nodes_in_group("kickable_objects"):
		kickables.append(node)
		initial_kickables.append({
			"node": node,
			"position": node.global_position,
			"rotation": node.rotation
		})
	
	# Find and capture all triggers
	triggers.clear()
	for node in level.get_tree().get_nodes_in_group("triggers"):
		triggers.append(node)
	
	# Get timer UI reference
	timer_ui = level.get_tree().get_first_node_in_group("timer_ui")
	

func reset_level() -> void:
	"""Fast reset - no reload, just reset state"""
	var start_time = Time.get_ticks_msec()
	
	# 1. Reset player
	if player and is_instance_valid(player) and player.has_method("reset_state"):
		player.reset_state(initial_player_position, initial_player_rotation, initial_player_scale)
	
	# 2. Reset enemies
	for i in enemies.size():
		var enemy = enemies[i]
		if enemy and is_instance_valid(enemy):
			var data = initial_enemies[i]
			if enemy.has_method("reset_state"):
				enemy.reset_state()
			# Restore position and rotation
			enemy.global_position = data["position"]
			enemy.rotation = data["rotation"]
	
	# 3. Reset kickable objects
	for i in kickables.size():
		var obj = kickables[i]
		if obj and is_instance_valid(obj):
			var data = initial_kickables[i]
			if obj.has_method("reset_state"):
				obj.reset_state()
			# Restore position and rotation
			obj.global_position = data["position"]
			obj.rotation = data["rotation"]
	
	# 4. Reset all triggers
	for trigger in triggers:
		if trigger and is_instance_valid(trigger) and trigger.has_method("reset_state"):
			trigger.reset_state()
	
	# 5. Reset timer
	if timer_ui and is_instance_valid(timer_ui) and timer_ui.has_method("reset_timer"):
		timer_ui.reset_timer()
	
	# 6. Reset autoload managers
	if TutorialBlockManager and TutorialBlockManager.has_method("reset_tutorials"):
		TutorialBlockManager.reset_tutorials()
	if TutorialManager and TutorialManager.has_method("clear_message"):
		TutorialManager.clear_message()
	if DialogueManager and DialogueManager.has_method("reset_state"):
		DialogueManager.reset_state()
	
	# 7. Clear any spawned particles/effects
	_clear_transient_nodes()
	
	# 8. Reset physics (clear velocities)
	PhysicsServer2D.flush_queries()
	
	# 9. Ensure game is unpaused and time scale is normal
	if level_node and level_node.get_tree():
		level_node.get_tree().paused = false
	Engine.time_scale = 1.0
	
	var _elapsed = Time.get_ticks_msec() - start_time

func _clear_transient_nodes() -> void:
	"""Remove all temporary effects spawned during gameplay"""
	if not level_node or not level_node.get_tree():
		return
		
	var groups_to_clear = ["particles", "effects", "afterimages", "shadows", "projectiles", "death_ui", "victory_ui"]
	for group_name in groups_to_clear:
		for node in level_node.get_tree().get_nodes_in_group(group_name):
			if node and is_instance_valid(node):
				node.queue_free()
