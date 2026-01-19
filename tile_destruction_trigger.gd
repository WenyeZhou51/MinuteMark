extends Area2D

## The TileMaps to check for destructible tiles.
@export var target_tilemaps: Array[TileMap]
## The name of the custom data layer in the Tileset.
@export var custom_data_layer: String = "is_destructable"
## The scene to spawn for the destruction effect.
@export var destruction_effect: PackedScene

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	print("TileDestructionTrigger: Body entered: ", body.name)
	# Check if the player entered. Adjust group name if necessary.
	if body.is_in_group("player") or body.name == "Player" or body.name == "player":
		print("TileDestructionTrigger: Player detected, starting destruction...")
		destroy_tiles_in_area()

func destroy_tiles_in_area() -> void:
	if target_tilemaps.is_empty():
		push_warning("TileDestructionTrigger: No target tilemaps assigned!")
		return

	var shape_node = get_node_or_null("CollisionShape2D")
	if not shape_node or not shape_node.shape is RectangleShape2D:
		push_warning("TileDestructionTrigger: Requires a RectangleShape2D on a child named CollisionShape2D")
		return

	var rect_shape = shape_node.shape as RectangleShape2D
	# Get the global rect of the trigger area
	var area_rect = Rect2(global_position - (rect_shape.size / 2) * global_scale, rect_shape.size * global_scale)
	print("TileDestructionTrigger: Checking area: ", area_rect)

	var destroyed_count = 0
	for tilemap in target_tilemaps:
		if not tilemap: continue
		
		# Get the tilemap's cell size from its TileSet
		var tile_size = tilemap.tile_set.tile_size
		
		# Convert the area rect into tilemap local space, then into map coordinates
		var start_local = tilemap.to_local(area_rect.position)
		var end_local = tilemap.to_local(area_rect.end)
		
		var start_cell = tilemap.local_to_map(start_local)
		var end_cell = tilemap.local_to_map(end_local)
		
		# Ensure start is top-left and end is bottom-right for the loop
		var x_min = min(start_cell.x, end_cell.x)
		var x_max = max(start_cell.x, end_cell.x)
		var y_min = min(start_cell.y, end_cell.y)
		var y_max = max(start_cell.y, end_cell.y)
		
		print("TileDestructionTrigger: Checking cells from ", Vector2i(x_min, y_min), " to ", Vector2i(x_max, y_max))
		
		for x in range(x_min, x_max + 1):
			for y in range(y_min, y_max + 1):
				var cell_coords = Vector2i(x, y)
				var tile_data = tilemap.get_cell_tile_data(0, cell_coords)
				
				if tile_data:
					var is_destructable = tile_data.get_custom_data(custom_data_layer)
					if is_destructable:
						var world_pos = tilemap.to_global(tilemap.map_to_local(cell_coords))
						spawn_explosion(world_pos)
						tilemap.set_cell(0, cell_coords, -1)
						destroyed_count += 1
	
	print("TileDestructionTrigger: Destroyed ", destroyed_count, " tiles.")

func spawn_explosion(pos: Vector2) -> void:
	if not destruction_effect:
		return
		
	var effect = destruction_effect.instantiate()
	get_parent().add_child(effect)
	effect.global_position = pos

