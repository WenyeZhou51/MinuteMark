extends Node2D

func _ready() -> void:
	# Listen for when dialogue starts/finishes to pause/resume
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	
	# Initial state: Game is NOT paused.
	get_tree().paused = false
	
	# Reset tutorials on level load
	TutorialBlockManager.reset_tutorials()
	
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
