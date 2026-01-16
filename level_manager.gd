extends Node2D

func _ready() -> void:
	# Listen for when dialogue starts/finishes to pause/resume
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	
	# Initial state: Game is NOT paused.
	get_tree().paused = false
	
	# Debug: Verify BackgroundTileMap configuration
	_verify_background_tilemap()

func _on_dialogue_started(_id: String) -> void:
	get_tree().paused = true

func _on_dialogue_finished() -> void:
	get_tree().paused = false

func _verify_background_tilemap() -> void:
	print("=== BACKGROUND TILEMAP VERIFICATION ===")
	
	var bg_tilemap = get_node_or_null("BackgroundTileMap")
	
	if bg_tilemap == null:
		print("ERROR: BackgroundTileMap node not found!")
		return
	
	print("✓ BackgroundTileMap node exists")
	
	# Check if it's a TileMap
	if not bg_tilemap is TileMap:
		print("ERROR: BackgroundTileMap is not a TileMap node!")
		return
	
	print("✓ BackgroundTileMap is a TileMap node")
	
	# Check z_index
	var z_index = bg_tilemap.z_index
	print("  - z_index: ", z_index)
	
	if z_index != -1:
		print("WARNING: BackgroundTileMap z_index is not -1. Expected -1 for proper layering.")
	else:
		print("✓ BackgroundTileMap z_index is -1 (correct)")
	
	# Check scale
	var scale = bg_tilemap.scale
	print("  - scale: ", scale)
	
	if scale != Vector2(0.5, 0.5):
		print("WARNING: BackgroundTileMap scale doesn't match main tilemap scale (0.5, 0.5)")
	else:
		print("✓ BackgroundTileMap scale matches main tilemap (0.5, 0.5)")
	
	# CRITICAL FIX: Remove all physics layers from the background tileset to prevent collision
	var tileset = bg_tilemap.tile_set
	if tileset:
		var physics_layers_count = tileset.get_physics_layers_count()
		print("  - Original TileSet physics layers: ", physics_layers_count)
		
		if physics_layers_count > 0:
			print("  ⚠ REMOVING ALL PHYSICS LAYERS TO PREVENT COLLISION...")
			
			# Create a duplicate tileset so we don't affect the main tilemap
			var collision_free_tileset = tileset.duplicate(true)
			
			# Remove all physics layers
			for i in range(physics_layers_count - 1, -1, -1):
				collision_free_tileset.remove_physics_layer(i)
			
			print("  ✓ Created collision-free tileset duplicate")
			print("  ✓ Removed ", physics_layers_count, " physics layers")
			
			# Assign the collision-free tileset to the background tilemap
			bg_tilemap.tile_set = collision_free_tileset
			
			print("  ✓ Applied collision-free tileset to BackgroundTileMap")
			print("  ✓ Physics layers now: ", bg_tilemap.tile_set.get_physics_layers_count())
	
	print("\n✓✓✓ BackgroundTileMap NOW HAS ZERO COLLISION ✓✓✓")
	print("=== VERIFICATION COMPLETE ===")
	print("")
