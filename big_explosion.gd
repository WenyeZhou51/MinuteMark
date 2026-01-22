extends Node2D

@export var explosion_radius: float = 360.0
@export var custom_data_layer: String = "is_destructable"

func _ready() -> void:
	# Trigger particle systems (position will be correct by the time this runs)
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

func destroy_tiles_in_radius() -> bool:
	print("[BigExplosion] destroy_tiles_in_radius() called at position: ", global_position, " with radius: ", explosion_radius)
	
	var tilemaps = []
	_find_tilemaps(get_tree().current_scene, tilemaps)
	
	print("[BigExplosion] Found ", tilemaps.size(), " tilemaps")
	
	var any_tiles_destroyed = false
	var total_destroyed = 0
	
	for tilemap in tilemaps:
		if not tilemap is TileMap: 
			print("[BigExplosion] WARNING: Non-tilemap found in list: ", tilemap)
			continue
		
		print("[BigExplosion] Checking tilemap: ", tilemap.name, " at scale: ", tilemap.global_scale)
		
		# Get the radius in the tilemap's local coordinate system
		var local_radius = explosion_radius / ((tilemap.global_scale.x + tilemap.global_scale.y) / 2.0)
		var local_center = tilemap.to_local(global_position)
		
		print("[BigExplosion] Local center: ", local_center, " local radius: ", local_radius)
		
		# Calculate the bounding box of the circle in local coordinates
		var start_cell = tilemap.local_to_map(local_center - Vector2(local_radius, local_radius))
		var end_cell = tilemap.local_to_map(local_center + Vector2(local_radius, local_radius))
		
		print("[BigExplosion] Checking cells from ", start_cell, " to ", end_cell)
		
		# Ensure we iterate correctly even if cells are negative or order is flipped
		var x_min = min(start_cell.x, end_cell.x)
		var x_max = max(start_cell.x, end_cell.x)
		var y_min = min(start_cell.y, end_cell.y)
		var y_max = max(start_cell.y, end_cell.y)
		
		var destroyed_in_map = 0
		var checked_cells = 0
		var destructable_cells = 0
		
		for x in range(x_min, x_max + 1):
			for y in range(y_min, y_max + 1):
				checked_cells += 1
				var cell_coords = Vector2i(x, y)
				var tile_data = tilemap.get_cell_tile_data(0, cell_coords)
				
				if tile_data:
					var is_destructable = tile_data.get_custom_data(custom_data_layer)
					if is_destructable:
						destructable_cells += 1
						var cell_world_pos = tilemap.to_global(tilemap.map_to_local(cell_coords))
						var dist = global_position.distance_to(cell_world_pos)
						if dist <= explosion_radius:
							tilemap.set_cell(0, cell_coords, -1)
							destroyed_in_map += 1
							any_tiles_destroyed = true
							print("[BigExplosion] Destroyed tile at cell: ", cell_coords, " world pos: ", cell_world_pos, " distance: ", dist)
		
		print("[BigExplosion] Tilemap '", tilemap.name, "': checked ", checked_cells, " cells, found ", destructable_cells, " destructable, destroyed ", destroyed_in_map)
		total_destroyed += destroyed_in_map
	
	print("[BigExplosion] TOTAL TILES DESTROYED: ", total_destroyed, " (returning ", any_tiles_destroyed, ")")
	return any_tiles_destroyed
	
func _find_tilemaps(node: Node, list: Array) -> void:
	if node is TileMap:
		list.append(node)
	for child in node.get_children():
		_find_tilemaps(child, list)

