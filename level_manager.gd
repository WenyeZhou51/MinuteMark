extends Node2D

func _ready() -> void:
	# Listen for when dialogue starts/finishes to pause/resume
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	DialogueManager.interrupt_triggered.connect(_on_interrupt_triggered)
	DialogueManager.action_triggered.connect(_on_action_triggered)
	
	# Initial state: Game is NOT paused.
	get_tree().paused = false
	
	_fix_background_tilemap()

func _on_interrupt_triggered() -> void:
	# The "KICK" interrupt logic
	var guard = get_node_or_null("Elevator Guard")
	if guard and guard.has_method("kick"):
		# Check if it was the guard speaking
		# (We can check the speaker of the current line)
		var line = DialogueManager.dialogue_data.get(DialogueManager.current_id)
		if line and line.get("speaker") == "Elevator Guard":
			# Kick him! Direction depends on player position relative to guard
			var player = get_tree().get_first_node_in_group("player")
			var dir = Vector2.RIGHT
			if player:
				dir = (guard.global_position - player.global_position).normalized()
				if dir.length() < 0.1: dir = Vector2.RIGHT
			
			guard.kick(dir, 1500.0)

func _on_action_triggered(action_name: String) -> void:
	if action_name == "disable_guard":
		var guard = get_node_or_null("Elevator Guard")
		if guard and guard.has_method("disable"):
			guard.disable(true) # Pass true for smiley face

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
	get_tree().paused = false
