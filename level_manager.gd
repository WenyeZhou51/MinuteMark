extends Node2D

func _enter_tree() -> void:
	# Reset tutorials immediately when level starts loading
	# This ensures they are reset before any tutorial blocks initialize or check status
	if TutorialBlockManager:
		TutorialBlockManager.reset_tutorials()
	
	if TutorialManager:
		TutorialManager.clear_message()

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
