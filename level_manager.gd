extends Node2D

# Store initial state for soft reset
var initial_player_position: Vector2
var initial_player_state: Dictionary = {}
var initial_enemy_states: Array = []

func _ready() -> void:
	# Listen for when dialogue starts/finishes to pause/resume
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	
	# Initial state: Game is NOT paused.
	get_tree().paused = false
	
	# Reset tutorials on level load
	TutorialBlockManager.reset_tutorials()
	
	_fix_background_tilemap()
	
	# Store initial state for soft reset (wait a frame for everything to be ready)
	call_deferred("_store_initial_state")

func _store_initial_state() -> void:
	"""Store initial positions and states for soft reset."""
	# Store player position
	var player = get_tree().get_first_node_in_group("player")
	if player:
		initial_player_position = player.global_position
	
	# Store enemy states
	initial_enemy_states.clear()
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			initial_enemy_states.append({
				"node": enemy,
				"position": enemy.global_position,
				"visible": enemy.visible
			})

func _fix_background_tilemap() -> void:
	var bg_tilemap = get_node_or_null("BackgroundTileMap")
	if bg_tilemap and bg_tilemap is TileMap:
		var tileset = bg_tilemap.tile_set
		if tileset:
			var physics_layers_count = tileset.get_physics_layers_count()
			if physics_layers_count > 0:
				var collision_free_tileset = tileset.duplicate(true)
				for i in range(physics_layers_count - 1, -1, -1):
					collision_free_tileset.remove_physics_layer(i)
				bg_tilemap.tile_set = collision_free_tileset

func _on_dialogue_started(_id: String) -> void:
	get_tree().paused = true

func _on_dialogue_finished() -> void:
	# Pause is now handled by DialogueUI to wait for fade out
	pass

func soft_reset_level() -> void:
	"""Fast reset without reloading the scene - significantly faster than reload_current_scene()."""
	print("LevelManager: Starting soft reset")
	
	# 1. Reset time scale and pause state
	Engine.time_scale = 1.0
	get_tree().paused = false
	
	# 2. Get player reference
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("LevelManager: No player found for soft reset!")
		return
	
	# 3. Reset player to initial position and state
	player.global_position = initial_player_position
	player.velocity = Vector2.ZERO
	player.is_dying = false
	player.is_stunned = false
	player.is_in_rewind_slowmo = false
	player.is_rewind_holding = false
	player.is_rewind_tracing = false
	player.is_ground_sliding = false
	player.is_air_dashing = false
	player.is_slamming = false
	player.is_speed_capped = false
	
	# Reset kick-related states
	if "kick_has_fired" in player:
		player.kick_has_fired = false
	if "kick_boost_available" in player:
		player.kick_boost_available = false
	if "auto_kick_active" in player:
		player.auto_kick_active = false
	
	# Reset player timers
	if "current_game_time" in player:
		player.current_game_time = player.game_timer_duration
	
	# Re-enable player processing
	player.set_physics_process(true)
	player.set_process(true)
	
	# Show player visuals
	if player.has_node("AnimatedSprite2D"):
		player.get_node("AnimatedSprite2D").visible = true
		player.get_node("AnimatedSprite2D").modulate = Color.WHITE  # Reset any color tint
	if player.has_node("Visual"):
		player.get_node("Visual").visible = false  # Keep debug visual hidden
	if player.has_node("AttackVisual"):
		player.get_node("AttackVisual").visible = false
	
	# Hide slam attack visual indicator
	if "slam_attack_visual" in player and player.slam_attack_visual:
		player.slam_attack_visual.visible = false
	
	# Hide rewind warning sprite
	if "rewind_warning_sprite" in player and player.rewind_warning_sprite:
		player.rewind_warning_sprite.visible = false
	
	# Clear any visual indicators
	if "object_kick_indicator" in player and player.object_kick_indicator:
		player.object_kick_indicator.visible = false
	if "bullet_parry_indicator" in player and player.bullet_parry_indicator:
		player.bullet_parry_indicator.visible = false
	
	# Enable player camera
	if player.has_node("Camera2D"):
		var cam = player.get_node("Camera2D")
		cam.enabled = true
		cam.make_current()
	
	# 4. Reset enemies to initial state
	for enemy_data in initial_enemy_states:
		var enemy = enemy_data["node"]
		if enemy and is_instance_valid(enemy):
			enemy.global_position = enemy_data["position"]
			enemy.visible = enemy_data["visible"]
			if "is_destroyed" in enemy:
				enemy.is_destroyed = false
			if "monitoring" in enemy:
				enemy.monitoring = true
			if "monitorable" in enemy:
				enemy.monitorable = true
	
	# 5. Remove any temporary cameras (created during death sequence)
	# Check all Camera2D nodes that are not the player's camera
	for node in get_children():
		if node is Camera2D:
			print("LevelManager: Removing temporary camera")
			node.queue_free()
	
	# 6. Clean up any lingering death visual effects
	# Look for any Node2D with "DeathEffect" in the name or check for the specific script
	for node in get_children():
		if node.name == "DeathEffect" or "death" in node.name.to_lower():
			print("LevelManager: Removing death effect: ", node.name)
			node.queue_free()
	
	# 7. Reset tutorials
	if TutorialBlockManager:
		TutorialBlockManager.reset_tutorials()
	
	# 8. Restart music
	if AudioManager:
		AudioManager.restart_music()
	
	# 9. Clean up any persistent UI overlays
	var grayscale_overlay = get_tree().root.get_node_or_null("GrayscaleOverlay")
	if grayscale_overlay:
		grayscale_overlay.queue_free()
	
	print("LevelManager: Soft reset complete")
