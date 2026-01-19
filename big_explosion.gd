extends Node2D

@export var explosion_radius: float = 360.0
@export var custom_data_layer: String = "is_destructable"

func _ready() -> void:
	# Trigger particle systems
	if has_node("FireParticles"):
		$FireParticles.emitting = true
	if has_node("SmokeParticles"):
		$SmokeParticles.emitting = true
	if has_node("Flash"):
		_play_flash()
	
	# Auto-cleanup
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(queue_free)

func _play_flash() -> void:
	var flash = $Flash
	flash.visible = true
	flash.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(flash, "scale", Vector2(7.5, 7.5), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)

func destroy_tiles_in_radius() -> void:
	var tilemaps = []
	_find_tilemaps(get_tree().current_scene, tilemaps)
	
	for tilemap in tilemaps:
		if not tilemap is TileMap: continue
		
		# Get the radius in the tilemap's local coordinate system
		var local_radius = explosion_radius / ((tilemap.global_scale.x + tilemap.global_scale.y) / 2.0)
		var local_center = tilemap.to_local(global_position)
		
		# Calculate the bounding box of the circle in local coordinates
		var start_cell = tilemap.local_to_map(local_center - Vector2(local_radius, local_radius))
		var end_cell = tilemap.local_to_map(local_center + Vector2(local_radius, local_radius))
		
		# Ensure we iterate correctly even if cells are negative or order is flipped
		var x_min = min(start_cell.x, end_cell.x)
		var x_max = max(start_cell.x, end_cell.x)
		var y_min = min(start_cell.y, end_cell.y)
		var y_max = max(start_cell.y, end_cell.y)
		
		var destroyed_in_map = 0
		for x in range(x_min, x_max + 1):
			for y in range(y_min, y_max + 1):
				var cell_coords = Vector2i(x, y)
				var tile_data = tilemap.get_cell_tile_data(0, cell_coords)
				
				if tile_data:
					var is_destructable = tile_data.get_custom_data(custom_data_layer)
					if is_destructable:
						var cell_world_pos = tilemap.to_global(tilemap.map_to_local(cell_coords))
						var dist = global_position.distance_to(cell_world_pos)
						if dist <= explosion_radius:
							tilemap.set_cell(0, cell_coords, -1)
							destroyed_in_map += 1
	
func _find_tilemaps(node: Node, list: Array) -> void:
	if node is TileMap:
		list.append(node)
	for child in node.get_children():
		_find_tilemaps(child, list)

