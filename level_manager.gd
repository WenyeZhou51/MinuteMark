extends Node2D

func _enter_tree() -> void:
	# Reset tutorials immediately when level starts loading
	# This ensures they are reset before any tutorial blocks initialize or check status
	if TutorialBlockManager:
		TutorialBlockManager.reset_tutorials()
	
	if TutorialManager:
		TutorialManager.clear_message()
	
	# Configure level-specific audio BEFORE player's _ready calls restart_music()
	_configure_level_audio()

func _ready() -> void:
	# Set current level path for dialogue stats tracking
	var dialogue_stats = get_node_or_null("/root/DialogueStats")
	if dialogue_stats:
		var current_scene_path = get_tree().current_scene.scene_file_path
		dialogue_stats.set_current_level(current_scene_path)
	
	# Listen for when dialogue starts/finishes to pause/resume
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	
	# Initial state: Game is NOT paused.
	get_tree().paused = false
	
	# Apply any level-specific enemy behavior overrides.
	_configure_level_enemies()
	
	_fix_background_tilemap()

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

func _configure_level_audio() -> void:
	"""Configure audio based on which level is loaded."""
	var scene_path = scene_file_path
	
	# Stop heartbeat/noise by default; only specific levels re-enable them
	if AudioManager:
		AudioManager.stop_heartbeat()
		AudioManager.stop_occasional_noise()
	
	if scene_path in ["res://level1.tscn", "res://level1.1.tscn"]:
		# Level 1 & 1.1: Rush Hour
		if AudioManager:
			AudioManager.set_level_music("res://audio/Rush Hour.ogg")
	elif scene_path == "res://level2.tscn":
		if AudioManager:
			AudioManager.set_level_music("res://audio/City Central.wav")
	else:
		# All other levels: default music (Second Chance)
		if AudioManager:
			AudioManager.reset_to_default_music()


func _configure_level_enemies() -> void:
	"""Apply level-specific enemy runtime settings."""
	if scene_file_path != "res://level1.tscn":
		return
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		# Only apply to shooter enemies that use enemy.gd behavior.
		if enemy and enemy.has_method("_update_shooting"):
			enemy.shooting_enabled = true
			enemy.require_line_of_sight = true
			# Level 1 has long sightlines; 1000 can be too short for visible engagements.
			if "detection_range" in enemy:
				enemy.detection_range = max(enemy.detection_range, 2500.0)
			enemy.shooting_state = enemy.ShootingState.STARTUP_DELAY
			enemy.state_timer = 0.0
			enemy.aim_timer = 0.0
			if enemy.has_method("_find_player"):
				enemy._find_player()
