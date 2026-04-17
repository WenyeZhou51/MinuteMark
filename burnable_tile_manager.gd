extends Node2D

## Monitors fire sources (pixel fire simulation, burning player, burning flammable
## objects) and ignites burnable tilemap tiles. Burning tiles get the flammable_burn
## shader overlay, fire particles, dynamic light, and are destroyed after burn_duration.
## Supports rewind: burn timers run backward during rewind and tiles are restored.

@export var burn_duration: float = 1.0
@export var ignition_ramp: float = 0.2
@export var dying_ramp: float = 0.25
@export var spread_delay: float = 0.2
@export var check_interval: int = 5
@export var particle_interval: float = 0.08
@export var custom_data_layer: String = "is_burnable"
@export var player_ignite_radius: float = 100.0

var tilemap: TileMap
var fire_sim: Node2D
var tile_size_world: float = 64.0

var burnable_cells: Dictionary = {}  # Vector2i -> true
var burning_tiles: Dictionary = {}   # Vector2i -> BurningTileData

var frame_counter: int = 0
var rng := RandomNumberGenerator.new()
var light_texture: ImageTexture
var atlas_image_cache: Dictionary = {}  # source_id -> Image

var _player_ref: Node = null
var _is_rewinding: bool = false


class BurningTileData:
	var cell: Vector2i
	var timer: float = 0.0
	var sprite: Sprite2D
	var light: PointLight2D
	var body: StaticBody2D
	var shader_material: ShaderMaterial
	var particle_timer: float = 0.0
	var world_pos: Vector2
	var source_id: int
	var atlas_coords: Vector2i
	var has_spread: bool = false


func _ready() -> void:
	rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("burnable_tile_manager")
	_create_light_texture()
	call_deferred("_initialize")


func _create_light_texture() -> void:
	var sz := 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var center := Vector2(sz * 0.5, sz * 0.5)
	var max_d := sz * 0.48
	for y in sz:
		for x in sz:
			var d := Vector2(x, y).distance_to(center) / max_d
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	light_texture = ImageTexture.create_from_image(img)


func _initialize() -> void:
	tilemap = get_parent().get_node_or_null("Platform Tilemap")
	if not tilemap:
		push_error("BurnableTileManager: No 'Platform Tilemap' sibling found!")
		return

	tile_size_world = tilemap.tile_set.tile_size.x * tilemap.scale.x

	var sims := get_tree().get_nodes_in_group("fire_simulation")
	if sims.size() > 0:
		fire_sim = sims[0]
	else:
		push_warning("BurnableTileManager: No fire_simulation found in tree")

	_build_burnable_set()


func _build_burnable_set() -> void:
	burnable_cells.clear()
	var used := tilemap.get_used_cells(0)
	for cell in used:
		var td := tilemap.get_cell_tile_data(0, cell)
		if td and td.get_custom_data(custom_data_layer):
			burnable_cells[cell] = true
	print("[BURN] Burnable tiles: ", burnable_cells.size())


func _cache_player() -> void:
	if _player_ref and is_instance_valid(_player_ref):
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = players[0]


func _process(delta: float) -> void:
	if not tilemap:
		return

	_cache_player()

	# Detect rewind state from the player
	var rewinding_now := false
	if _player_ref and is_instance_valid(_player_ref):
		rewinding_now = _player_ref.get("is_rewind_tracing") == true

	if rewinding_now:
		_process_rewind(delta)
		return

	# If we just exited rewind, mark it
	_is_rewinding = false

	# Normal forward processing requires fire_sim
	if not fire_sim:
		return

	frame_counter += 1

	if frame_counter % check_interval == 0:
		_check_ignition_sources()

	var to_remove: Array[Vector2i] = []
	var to_spread: Array[Vector2i] = []
	for cell in burning_tiles:
		var data: BurningTileData = burning_tiles[cell]
		data.timer += delta
		data.particle_timer += delta

		if not data.has_spread and data.timer >= spread_delay:
			data.has_spread = true
			to_spread.append(cell)

		if data.timer >= burn_duration:
			to_remove.append(cell)
			continue

		_update_burning_tile(data)

	for cell in to_spread:
		_spread_to_neighbors(cell)

	for cell in to_remove:
		_finish_burn(cell)


func _process_rewind(delta: float) -> void:
	_is_rewinding = true

	var to_restore: Array[Vector2i] = []
	for cell in burning_tiles:
		var data: BurningTileData = burning_tiles[cell]
		data.timer -= delta
		if data.has_spread and data.timer < spread_delay:
			data.has_spread = false
		if data.timer <= 0.0:
			to_restore.append(cell)
			continue
		_update_burning_tile(data)

	for cell in to_restore:
		_restore_tile(cell)


func _restore_tile(cell: Vector2i) -> void:
	var data: BurningTileData = burning_tiles[cell]

	if data.sprite and is_instance_valid(data.sprite):
		data.sprite.queue_free()
	if data.light and is_instance_valid(data.light):
		data.light.queue_free()
	if data.body and is_instance_valid(data.body):
		data.body.queue_free()

	tilemap.set_cell(0, cell, data.source_id, data.atlas_coords)
	burnable_cells[cell] = true

	burning_tiles.erase(cell)


func _check_ignition_sources() -> void:
	var to_ignite: Array[Vector2i] = []

	for cell in burnable_cells:
		if burning_tiles.has(cell):
			continue

		var tile_center: Vector2 = tilemap.to_global(tilemap.map_to_local(cell))

		# 1) Fire simulation overlap
		if fire_sim and not fire_sim.burning_set.is_empty():
			if _fire_sim_overlaps_tile(cell):
				to_ignite.append(cell)
				continue

		# 2) Burning player proximity
		if _player_ref and is_instance_valid(_player_ref):
			if _player_ref.get("is_on_fire") == true:
				if _player_ref.global_position.distance_to(tile_center) < player_ignite_radius:
					to_ignite.append(cell)
					continue

		# 3) Nearby burning flammable objects
		var flammables := get_tree().get_nodes_in_group("flammable_objects")
		for f in flammables:
			if not is_instance_valid(f):
				continue
			var bs = f.get("burn_state")
			if bs != null and bs != 0:  # 0 = BurnState.IDLE
				if f.global_position.distance_to(tile_center) < player_ignite_radius:
					to_ignite.append(cell)
					break

	for cell in to_ignite:
		_ignite_tile(cell)


func _fire_sim_overlaps_tile(cell: Vector2i) -> bool:
	var cell_size: int = fire_sim.cell_size

	var tile_wx: float = tilemap.global_position.x + cell.x * tile_size_world
	var tile_wy: float = tilemap.global_position.y + cell.y * tile_size_world

	var fx_start := int(round(tile_wx / cell_size))
	var fx_end := int(round((tile_wx + tile_size_world) / cell_size))
	var fy_start := int(round(tile_wy / cell_size)) - 3
	var fy_end := int(round((tile_wy + tile_size_world) / cell_size)) + 1

	for fx in range(fx_start, fx_end + 1):
		for fy in range(fy_start, fy_end + 1):
			if fire_sim.burning_set.has(Vector2i(fx, fy)):
				return true
	return false


func _spread_to_neighbors(cell: Vector2i) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var adj := Vector2i(cell.x + dx, cell.y + dy)
			if burnable_cells.has(adj) and not burning_tiles.has(adj):
				_ignite_tile(adj)


func ignite_at_world_pos(world_pos: Vector2) -> void:
	if not tilemap:
		return
	var local_pos := tilemap.to_local(world_pos)
	var hit_cell := tilemap.local_to_map(local_pos)

	var cells_to_ignite: Array[Vector2i] = []
	if burnable_cells.has(hit_cell) and not burning_tiles.has(hit_cell):
		cells_to_ignite.append(hit_cell)

	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var adj := Vector2i(hit_cell.x + dx, hit_cell.y + dy)
			if burnable_cells.has(adj) and not burning_tiles.has(adj):
				cells_to_ignite.append(adj)

	for cell in cells_to_ignite:
		_ignite_tile(cell)


func _ignite_tile(cell: Vector2i) -> void:
	if burning_tiles.has(cell):
		return

	var data := BurningTileData.new()
	data.cell = cell
	data.world_pos = tilemap.to_global(tilemap.map_to_local(cell))

	data.source_id = tilemap.get_cell_source_id(0, cell)
	data.atlas_coords = tilemap.get_cell_atlas_coords(0, cell)

	data.sprite = _create_burn_sprite(data.source_id, data.atlas_coords, data.world_pos)
	data.body = _create_temp_body(data.world_pos)
	data.light = _create_burn_light(data.world_pos)

	var shader := load("res://shaders/flammable_burn.gdshader") as Shader
	data.shader_material = ShaderMaterial.new()
	data.shader_material.shader = shader
	data.shader_material.set_shader_parameter("fire_intensity", 0.0)
	data.shader_material.set_shader_parameter("char_amount", 0.0)
	if data.sprite:
		data.sprite.material = data.shader_material

	tilemap.set_cell(0, cell, -1)
	burnable_cells.erase(cell)

	burning_tiles[cell] = data


func _create_burn_sprite(source_id: int, atlas_coords: Vector2i, world_pos: Vector2) -> Sprite2D:
	var source := tilemap.tile_set.get_source(source_id)
	if not source or not source is TileSetAtlasSource:
		return null

	var atlas_source := source as TileSetAtlasSource
	var tile_size := tilemap.tile_set.tile_size

	var src_image: Image
	if atlas_image_cache.has(source_id):
		src_image = atlas_image_cache[source_id]
	else:
		src_image = atlas_source.texture.get_image()
		atlas_image_cache[source_id] = src_image

	var region := Rect2i(atlas_coords * tile_size, tile_size)
	var tile_img := src_image.get_region(region)

	var margin := int(max(tile_size.x, tile_size.y) * 0.6)
	var tex_w := tile_size.x + margin * 2
	var tex_h := tile_size.y + margin * 2
	var padded := Image.create(tex_w, tex_h, false, Image.FORMAT_RGBA8)
	padded.fill(Color(0, 0, 0, 0))
	padded.blit_rect(tile_img, Rect2i(Vector2i.ZERO, tile_size), Vector2i(margin, margin))

	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(padded)
	sprite.global_position = world_pos
	sprite.scale = tilemap.scale
	get_parent().add_child(sprite)
	return sprite


func _create_temp_body(world_pos: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tile_size_world, tile_size_world)
	shape.shape = rect
	body.add_child(shape)
	body.global_position = world_pos
	get_parent().add_child(body)
	return body


func _create_burn_light(world_pos: Vector2) -> PointLight2D:
	var pl := PointLight2D.new()
	pl.texture = light_texture
	pl.color = Color(1.0, 0.5, 0.15)
	pl.energy = 0.0
	pl.texture_scale = tile_size_world * 4.0 / 64.0
	pl.global_position = world_pos
	pl.add_to_group("fire_lights")
	get_parent().add_child(pl)
	return pl


func _update_burning_tile(data: BurningTileData) -> void:
	var t := clampf(data.timer, 0.0, burn_duration)

	var fire_intensity: float
	if t < ignition_ramp:
		fire_intensity = t / ignition_ramp
	elif t > burn_duration - dying_ramp:
		fire_intensity = (burn_duration - t) / dying_ramp
	else:
		fire_intensity = 1.0

	var char_amount := clampf(t / burn_duration * 1.2, 0.0, 1.0)

	if data.shader_material:
		data.shader_material.set_shader_parameter("fire_intensity", fire_intensity)
		data.shader_material.set_shader_parameter("char_amount", char_amount)

	if data.sprite:
		if t > burn_duration - dying_ramp:
			data.sprite.modulate.a = (burn_duration - t) / dying_ramp
		else:
			data.sprite.modulate.a = 1.0

	if data.light:
		var flicker := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.02)
		data.light.energy = fire_intensity * 2.0 * flicker

	if not _is_rewinding and fire_sim:
		if data.particle_timer >= particle_interval and fire_intensity > 0.1:
			data.particle_timer = 0.0
			_inject_particles(data.world_pos, fire_intensity)


func _inject_particles(world_pos: Vector2, intensity: float) -> void:
	var half := tile_size_world * 0.5
	var count := int(3 * intensity)
	for i in range(count):
		var particle := {
			"pos": world_pos + Vector2(rng.randf_range(-half, half), rng.randf_range(-half * 0.5, 0)),
			"vel": Vector2(rng.randf_range(-30, 30), rng.randf_range(-160, -50)),
			"life": rng.randf_range(0.4, 1.0),
			"max_life": 1.0,
			"heat": rng.randf_range(0.5, 1.0),
			"size": rng.randf_range(8.0, 20.0),
		}
		fire_sim.particles.append(particle)


func _finish_burn(cell: Vector2i) -> void:
	var data: BurningTileData = burning_tiles[cell]

	if data.sprite and is_instance_valid(data.sprite):
		data.sprite.queue_free()
	if data.light and is_instance_valid(data.light):
		data.light.queue_free()
	if data.body and is_instance_valid(data.body):
		data.body.queue_free()

	_spawn_ash(data.world_pos)
	_expose_tiles_below(cell)

	burning_tiles.erase(cell)


func _spawn_ash(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = 12
	p.lifetime = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 90.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2(0, 40)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.0
	p.color = Color(0.2, 0.15, 0.1, 0.8)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.3, 0.2, 0.1, 0.8))
	ramp.set_color(1, Color(0.1, 0.08, 0.05, 0.0))
	p.color_ramp = ramp
	p.global_position = pos
	get_parent().add_child(p)
	get_tree().create_timer(1.5, true, false, true).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)


func _expose_tiles_below(removed_cell: Vector2i) -> void:
	if not fire_sim:
		return

	var below := Vector2i(removed_cell.x, removed_cell.y + 1)
	var td := tilemap.get_cell_tile_data(0, below)
	if not td:
		return

	var cell_size: int = fire_sim.cell_size
	var cprt := int(tile_size_world / cell_size)
	var tile_wx: float = tilemap.global_position.x + below.x * tile_size_world
	var tile_wy: float = tilemap.global_position.y + below.y * tile_size_world

	for dx in range(cprt):
		var wx: float = tile_wx + dx * cell_size
		var key := Vector2i(int(round(wx / cell_size)), int(round(tile_wy / cell_size)))
		if not fire_sim.surface_fuel.has(key):
			fire_sim.surface_fuel[key] = 1.0
			fire_sim.surface_temp[key] = 0.8
			fire_sim.heated_set[key] = true

	if td.get_custom_data(custom_data_layer):
		burnable_cells[below] = true
