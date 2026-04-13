extends Node2D

## Noita-style pixel fire simulation.
## Temperature-based spread + rising fire particles for organic flames.
## Fire spreads along tilemap platform surfaces via heat conduction.

@export var ignition_points: Array[Vector2] = []
@export var eternal_ignition_points: Array[Vector2] = []  ## Fires that never burn out and don't spread — burn in-place forever
@export var cell_size: int = 8
@export var flame_particle_count: int = 300  ## Max rising fire particles
@export var spread_interval: float = 0.05
@export var ignition_temp: float = 0.4  ## Temperature needed to ignite
@export var burn_heat_output: float = 2.0  ## Heat emitted by burning cell per second
@export var heat_conductivity: float = 1.5  ## How fast heat spreads to neighbors
@export var heat_dissipation: float = 0.3  ## How fast heat cools naturally
@export var burn_rate: float = 0.05  ## Fuel consumed per second while burning (decreased for longer duration)
@export var darkness_color: Color = Color(0.03, 0.02, 0.04, 1.0)
@export var light_energy_max: float = 1.8
@export var light_radius: float = 400.0
@export var num_lights: int = 8
@export var max_brightness: float = 1.0  ## Tonemap cap — single lights look normal, stacked lights compress

# Cell data — only surface cells exist in these dictionaries
# surface_fuel: Vector2i -> float (1.0 = full fuel, 0.0 = burnt out)
# surface_temp: Vector2i -> float (0.0 = cold, 1.0+ = hot)
var surface_fuel: Dictionary = {}
var surface_temp: Dictionary = {}

# OPTIMIZATION: track only actively burning cells in a separate set
# instead of iterating ALL surface_burning entries every frame
var burning_set: Dictionary = {}  # Vector2i -> true (only burning cells)
# Track cells with non-zero temperature for targeted iteration
var heated_set: Dictionary = {}  # Vector2i -> true
# Cells that burn forever and don't spread heat — set up via eternal_ignition_points or ignite_eternal_at()
var eternal_cells: Dictionary = {}  # Vector2i -> true

# ===== PARTICLE POOL (flat arrays, no Dictionaries) =====
# Each particle has 8 floats: pos_x, pos_y, vel_x, vel_y, life, max_life, heat, size
const P_POS_X := 0
const P_POS_Y := 1
const P_VEL_X := 2
const P_VEL_Y := 3
const P_LIFE := 4
const P_MAX_LIFE := 5
const P_HEAT := 6
const P_SIZE := 7
const PARTICLE_STRIDE := 8

var particle_pool: PackedFloat32Array  # pre-allocated flat buffer
var particle_count: int = 0  # number of LIVE particles (always at front of pool)

# Legacy compatibility: fire bottle injects particles as Dictionaries via this array
var particles: Array[Dictionary] = []  # external inject buffer, drained each frame

var tilemap: TileMap
var tile_size_world: float = 64.0
var spread_timer: float = 0.0

var lights: Array[PointLight2D] = []
var light_texture: ImageTexture
var canvas_modulate: CanvasModulate
var rng := RandomNumberGenerator.new()

# Debug (reduced frequency)
var debug_timer: float = 0.0
var debug_interval: float = 3.0
var frame_count: int = 0

# Cached viewport rect for culling
var cam_rect: Rect2 = Rect2()
var cam_margin: float = 200.0


func _ready() -> void:
	rng.randomize()
	add_to_group("fire_simulation")

	# Pre-allocate particle pool
	particle_pool.resize(flame_particle_count * PARTICLE_STRIDE)
	particle_pool.fill(0.0)
	particle_count = 0

	tilemap = get_parent().get_node_or_null("Platform Tilemap")
	if not tilemap:
		push_error("PixelFireSimulation: No 'Platform Tilemap' found as sibling!")
		return

	tile_size_world = tilemap.tile_set.tile_size.x * tilemap.scale.x

	_build_surface()
	_setup_darkness()
	_setup_lights()
	_setup_tonemap()
	call_deferred("_ignite_start_points")


func _build_surface() -> void:
	var used = tilemap.get_used_cells(0)
	var used_set: Dictionary = {}
	for c in used:
		used_set[c] = true

	var cprt := int(tile_size_world / cell_size)

	for cell in used:
		var above := Vector2i(cell.x, cell.y - 1)
		if used_set.has(above):
			continue

		var tile_wx: float = tilemap.global_position.x + cell.x * tile_size_world
		var tile_wy: float = tilemap.global_position.y + cell.y * tile_size_world

		for dx in range(cprt):
			var wx: float = tile_wx + dx * cell_size
			var wy: float = tile_wy
			var key := Vector2i(int(round(wx / cell_size)), int(round(wy / cell_size)))
			surface_fuel[key] = 1.0
			surface_temp[key] = 0.0

	print("[FIRE] Surface cells: ", surface_fuel.size())


func _setup_darkness() -> void:
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.color = darkness_color
	get_parent().call_deferred("add_child", canvas_modulate)


func _setup_lights() -> void:
	var sz := 128 # Increased resolution for smoother scaling
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var center := Vector2(sz * 0.5, sz * 0.5)
	var max_d := sz * 0.48 # Use distance to EDGE (with buffer) instead of CORNER
	for y in sz:
		for x in sz:
			var d := Vector2(x, y).distance_to(center) / max_d
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a # Restore quadratic decay for smooth edge tapering
			img.set_pixel(x, y, Color(1, 1, 1, a))
	light_texture = ImageTexture.create_from_image(img)

	for i in range(num_lights):
		var pl := PointLight2D.new()
		pl.texture = light_texture
		pl.color = Color(1.0, 0.5, 0.15, 1.0)
		pl.energy = 0.0
		pl.texture_scale = light_radius / 64.0
		pl.visible = false
		pl.add_to_group("fire_lights")
		add_child(pl)
		lights.append(pl)


func _setup_tonemap() -> void:
	# Enable HDR 2D so the framebuffer stores values >1.0 from stacked lights
	get_viewport().use_hdr_2d = true

	var shader := load("res://shaders/light_tonemap.gdshader") as Shader
	if not shader:
		push_warning("PixelFireSimulation: light_tonemap.gdshader not found, skipping tonemap")
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("max_brightness", max_brightness)
	var layer := CanvasLayer.new()
	layer.layer = 100
	var rect := ColorRect.new()
	rect.material = mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
	# Size must be set after the node is in the tree
	var vp_size := get_viewport().get_visible_rect().size
	rect.position = Vector2.ZERO
	rect.size = vp_size
	get_viewport().size_changed.connect(func(): rect.size = get_viewport().get_visible_rect().size)


func _ignite_start_points() -> void:
	for pt in ignition_points:
		ignite_at(pt)
	for pt in eternal_ignition_points:
		ignite_eternal_at(pt)


func ignite_at(world_pos: Vector2, radius: int = 3) -> void:
	var cx := int(round(world_pos.x / cell_size))
	var cy := int(round(world_pos.y / cell_size))

	# Search for nearest surface cell
	var best_key := Vector2i.ZERO
	var best_dist := 99999.0
	for key in surface_fuel:
		var dx_f: float = key.x - cx
		var dy_f: float = key.y - cy
		var d := dx_f * dx_f + dy_f * dy_f  # squared distance (cheaper)
		if d < best_dist:
			best_dist = d
			best_key = key

	if best_dist > 40000:  # 200^2
		return

	var ignited := 0
	for dy in range(-1, 2):
		for ddx in range(-radius, radius + 1):
			var key := Vector2i(best_key.x + ddx, best_key.y + dy)
			if surface_fuel.has(key) and surface_fuel[key] > 0:
				surface_temp[key] = 1.0
				burning_set[key] = true
				heated_set[key] = true
				ignited += 1


func ignite_eternal_at(world_pos: Vector2, radius: int = 3) -> void:
	var cx := int(round(world_pos.x / cell_size))
	var cy := int(round(world_pos.y / cell_size))

	var best_key := Vector2i.ZERO
	var best_dist := 99999.0
	for key in surface_fuel:
		var dx_f: float = key.x - cx
		var dy_f: float = key.y - cy
		var d := dx_f * dx_f + dy_f * dy_f
		if d < best_dist:
			best_dist = d
			best_key = key

	if best_dist > 40000:
		return

	for dy in range(-1, 2):
		for ddx in range(-radius, radius + 1):
			var key := Vector2i(best_key.x + ddx, best_key.y + dy)
			if surface_fuel.has(key):
				surface_fuel[key] = 1.0
				surface_temp[key] = 1.0
				burning_set[key] = true
				heated_set[key] = true
				eternal_cells[key] = true


func _process(delta: float) -> void:
	if tilemap == null:
		return

	frame_count += 1

	# Update camera rect for culling
	_update_cam_rect()

	# Drain external particle inject buffer (from fire bottles etc)
	_drain_injected_particles()

	# Sim step
	spread_timer += delta
	var max_steps := 10
	var steps_run := 0
	while spread_timer >= spread_interval and steps_run < max_steps:
		spread_timer -= spread_interval
		_simulate_step(spread_interval)
		steps_run += 1
	if steps_run >= max_steps:
		spread_timer = 0.0

	# Particles
	_update_particles(delta)

	# Lights (every other frame is fine)
	if frame_count % 2 == 0:
		_update_lights()

	# Check if player is near burning fire (every 10 frames)
	if frame_count % 10 == 0:
		_check_player_fire_proximity()

	queue_redraw()


func _update_cam_rect() -> void:
	var canvas_xform := get_canvas_transform()
	var vp_size := get_viewport_rect().size
	cam_rect = Rect2(-canvas_xform.origin / canvas_xform.x.x, vp_size / canvas_xform.x.x)
	cam_rect = cam_rect.grow(cam_margin)


func _drain_injected_particles() -> void:
	## Convert Dictionary-based particles (from fire bottle) into the flat pool
	for p in particles:
		if particle_count >= flame_particle_count:
			break
		var idx := particle_count * PARTICLE_STRIDE
		particle_pool[idx + P_POS_X] = p["pos"].x
		particle_pool[idx + P_POS_Y] = p["pos"].y
		particle_pool[idx + P_VEL_X] = p["vel"].x
		particle_pool[idx + P_VEL_Y] = p["vel"].y
		particle_pool[idx + P_LIFE] = p["life"]
		particle_pool[idx + P_MAX_LIFE] = p["max_life"]
		particle_pool[idx + P_HEAT] = p["heat"]
		particle_pool[idx + P_SIZE] = p["size"]
		particle_count += 1
	particles.clear()


func _simulate_step(dt: float) -> void:
	# Phase 1: Burning cells — consume fuel, emit heat, spawn particles
	var to_extinguish: Array[Vector2i] = []
	var new_heated: Array[Vector2i] = []

	for key in burning_set:
		var is_eternal: bool = eternal_cells.has(key)

		# Consume fuel (eternal cells never lose fuel)
		if not is_eternal:
			surface_fuel[key] -= burn_rate * dt
			if surface_fuel[key] <= 0.0:
				surface_fuel[key] = 0.0
				to_extinguish.append(key)
				continue

		# Keep burning cells hot
		surface_temp[key] = maxf(surface_temp[key], 0.8)

		# Conduct heat to neighbors (eternal cells don't spread)
		if not is_eternal:
			var heat_add: float = burn_heat_output * dt * heat_conductivity
			var nx: int = key.x
			var ny: int = key.y
			var neighbor_keys: Array[Vector2i] = [
				Vector2i(nx - 1, ny), Vector2i(nx + 1, ny),
				Vector2i(nx - 1, ny - 1), Vector2i(nx + 1, ny - 1),
				Vector2i(nx, ny - 1),
				Vector2i(nx - 2, ny), Vector2i(nx + 2, ny),
			]
			for n in neighbor_keys:
				if surface_temp.has(n):
					surface_temp[n] += heat_add
					if not heated_set.has(n):
						new_heated.append(n)

		# Spawn particles — scale probability by fuel so dim cells yield pool space
		var spawn_chance: float = surface_fuel.get(key, 0.0)
		if rng.randf() < 0.5 * spawn_chance and particle_count < flame_particle_count:
			_pool_spawn(
				key.x * cell_size + rng.randf_range(0, cell_size),
				key.y * cell_size,
				rng.randf_range(-25, 25), rng.randf_range(-160, -50),
				rng.randf_range(0.5, 1.2), 1.2,
				rng.randf_range(0.5, 1.0),
				rng.randf_range(cell_size * 1.0, cell_size * 2.5)
			)
		if rng.randf() < 0.2 * spawn_chance and particle_count < flame_particle_count:
			_pool_spawn(
				key.x * cell_size + rng.randf_range(0, cell_size),
				key.y * cell_size,
				rng.randf_range(-40, 40), rng.randf_range(-200, -80),
				rng.randf_range(0.3, 0.8), 0.8,
				rng.randf_range(0.7, 1.0),
				rng.randf_range(cell_size * 1.5, cell_size * 3.5)
			)

	# Merge newly heated cells BEFORE Phase 2 so they can ignite this tick
	for key in new_heated:
		heated_set[key] = true

	# Phase 2: Heated non-burning cells — check ignition
	var to_ignite: Array[Vector2i] = []
	var to_unheat: Array[Vector2i] = []

	for key in heated_set:
		if burning_set.has(key):
			continue
		if not surface_fuel.has(key) or surface_fuel[key] <= 0:
			to_unheat.append(key)
			continue

		var temp: float = surface_temp.get(key, 0.0)
		if temp >= ignition_temp:
			to_ignite.append(key)
		else:
			# Dissipate
			surface_temp[key] = maxf(temp - heat_dissipation * dt, 0.0)
			if surface_temp[key] <= 0.01:
				to_unheat.append(key)

	# Apply changes
	for key in to_ignite:
		burning_set[key] = true

	for key in to_extinguish:
		burning_set.erase(key)
		surface_temp[key] = 0.0
		heated_set.erase(key)

	for key in to_unheat:
		heated_set.erase(key)


func _pool_spawn(px: float, py: float, vx: float, vy: float, life: float, max_life: float, heat: float, sz: float) -> void:
	if particle_count >= flame_particle_count:
		return
	var idx := particle_count * PARTICLE_STRIDE
	particle_pool[idx + P_POS_X] = px
	particle_pool[idx + P_POS_Y] = py
	particle_pool[idx + P_VEL_X] = vx
	particle_pool[idx + P_VEL_Y] = vy
	particle_pool[idx + P_LIFE] = life
	particle_pool[idx + P_MAX_LIFE] = max_life
	particle_pool[idx + P_HEAT] = heat
	particle_pool[idx + P_SIZE] = sz
	particle_count += 1


func _update_particles(delta: float) -> void:
	var i := 0
	while i < particle_count:
		var idx := i * PARTICLE_STRIDE
		particle_pool[idx + P_LIFE] -= delta
		if particle_pool[idx + P_LIFE] <= 0:
			# Swap-remove: move last particle into this slot
			var last := (particle_count - 1) * PARTICLE_STRIDE
			if last != idx:
				for k in range(PARTICLE_STRIDE):
					particle_pool[idx + k] = particle_pool[last + k]
			particle_count -= 1
			continue  # re-check this index (now has a different particle)

		# Physics: rise with turbulence
		particle_pool[idx + P_VEL_X] += rng.randf_range(-80, 80) * delta
		# Added gravity effect to particles (they still rise, but gravity pulls them down)
		particle_pool[idx + P_VEL_Y] += (200.0 - 250.0) * delta # Gravity (200) vs Buoyancy (-250)
		particle_pool[idx + P_POS_X] += particle_pool[idx + P_VEL_X] * delta
		particle_pool[idx + P_POS_Y] += particle_pool[idx + P_VEL_Y] * delta
		particle_pool[idx + P_HEAT] *= 0.97

		i += 1


func _draw() -> void:
	var gp_x := global_position.x
	var gp_y := global_position.y

	# Draw burning surface cells (ember base) — only those on screen
	for key in burning_set:
		var wx: float = key.x * cell_size
		var wy: float = key.y * cell_size
		if not cam_rect.has_point(Vector2(wx, wy)):
			continue
		var fuel: float = surface_fuel.get(key, 0.0)
		var lx: float = wx - gp_x
		var ly: float = wy - gp_y
		var intensity: float = clampf(fuel, 0.3, 1.0)
		draw_rect(Rect2(lx, ly, cell_size, cell_size),
			Color(1.0, 0.3 * intensity, 0.05, 0.4 + intensity * 0.5))
		draw_rect(Rect2(lx + 1, ly + 1, cell_size - 2, cell_size - 2),
			Color(1.0, 0.6 * intensity, 0.1, 0.3 + intensity * 0.4))

	# Draw heated cells (about to ignite) — only those on screen
	for key in heated_set:
		if burning_set.has(key):
			continue
		var temp: float = surface_temp.get(key, 0.0)
		if temp > 0.1:
			var wx2: float = key.x * cell_size
			var wy2: float = key.y * cell_size
			if not cam_rect.has_point(Vector2(wx2, wy2)):
				continue
			var lx2: float = wx2 - gp_x
			var ly2: float = wy2 - gp_y
			var t: float = clampf(temp / ignition_temp, 0.0, 1.0)
			draw_rect(Rect2(lx2, ly2, cell_size, cell_size),
				Color(0.5 * t, 0.05 * t, 0.0, t * 0.4))

	# Draw fire particles from pool
	for i in range(particle_count):
		var idx := i * PARTICLE_STRIDE
		var px: float = particle_pool[idx + P_POS_X]
		var py: float = particle_pool[idx + P_POS_Y]

		# Camera culling
		if px < cam_rect.position.x or px > cam_rect.end.x:
			continue
		if py < cam_rect.position.y or py > cam_rect.end.y:
			continue

		var life: float = particle_pool[idx + P_LIFE]
		var max_life: float = particle_pool[idx + P_MAX_LIFE]
		var heat: float = particle_pool[idx + P_HEAT]
		var base_sz: float = particle_pool[idx + P_SIZE]

		var life_frac: float = life / max_life
		var sz: float = base_sz * (0.3 + life_frac * 0.7)
		if sz < 1.5:
			continue

		var color := _fire_particle_color(heat, life_frac)
		var lx3: float = px - gp_x
		var ly3: float = py - gp_y

		# Outer glow
		var glow_sz: float = sz * 1.5
		draw_rect(Rect2(lx3 - glow_sz * 0.5, ly3 - glow_sz * 0.5, glow_sz, glow_sz),
			Color(color.r, color.g * 0.5, color.b * 0.3, color.a * 0.25))

		# Core
		draw_rect(Rect2(lx3 - sz * 0.5, ly3 - sz * 0.5, sz, sz), color)


func _fire_particle_color(heat: float, life: float) -> Color:
	var h := heat * life
	if h > 0.8:
		return Color(1.0, 0.95, 0.7, life)
	elif h > 0.6:
		return Color(1.0, 0.7, 0.15, life * 0.95)
	elif h > 0.4:
		return Color(1.0, 0.45, 0.05, life * 0.85)
	elif h > 0.2:
		return Color(0.8, 0.2, 0.02, life * 0.7)
	else:
		return Color(0.3, 0.08, 0.02, life * 0.4)


func _update_lights() -> void:
	# Collect visible fire sources: burning cells + bright particles
	var fire_sources_x: PackedFloat32Array = []
	var fire_sources_y: PackedFloat32Array = []
	var fire_sources_w: PackedFloat32Array = []

	for key in burning_set:
		var fuel: float = surface_fuel.get(key, 0.0)
		var weight: float = 0.3 + fuel * 0.7
		fire_sources_x.append(key.x * cell_size + cell_size * 0.5)
		fire_sources_y.append(key.y * cell_size)
		fire_sources_w.append(weight)

	# Sample some particles for light (not all — sample every 8th for performance)
	var step := 8
	var pi := 0
	while pi < particle_count:
		var pidx := pi * PARTICLE_STRIDE
		var life: float = particle_pool[pidx + P_LIFE]
		var max_life: float = particle_pool[pidx + P_MAX_LIFE]
		var heat: float = particle_pool[pidx + P_HEAT]
		var life_frac: float = life / max_life
		# Particles emit light that fades with their life
		if heat * life_frac > 0.3:
			fire_sources_x.append(particle_pool[pidx + P_POS_X])
			fire_sources_y.append(particle_pool[pidx + P_POS_Y])
			# Light brightness is weighted by life_frac for fading effect
			fire_sources_w.append(heat * life_frac * 0.5)
		pi += step

	var total_sources := fire_sources_x.size()
	if total_sources == 0:
		for l in lights:
			l.visible = false
			l.energy = 0.0
		return

	# Distribute lights evenly across fire sources sorted by x
	var sorted_idx: Array[int] = []
	sorted_idx.resize(total_sources)
	for si in range(total_sources):
		sorted_idx[si] = si
	sorted_idx.sort_custom(func(a, b): return fire_sources_x[a] < fire_sources_x[b])

	var sources_per_light := maxi(1, total_sources / num_lights)
	var light_idx := 0
	var si := 0
	while si < total_sources and light_idx < num_lights:
		var end_si: int = mini(si + sources_per_light, total_sources)
		if light_idx == num_lights - 1:
			end_si = total_sources

		var wx_sum := 0.0
		var wy_sum := 0.0
		var w_total := 0.0
		for j in range(si, end_si):
			var src := sorted_idx[j]
			var w: float = fire_sources_w[src]
			wx_sum += fire_sources_x[src] * w
			wy_sum += fire_sources_y[src] * w
			w_total += w

		if w_total >= 0.01:
			var cx2: float = wx_sum / w_total
			var cy2: float = wy_sum / w_total - cell_size * 2.0
			lights[light_idx].global_position = Vector2(cx2, cy2)
			var intensity := clampf(w_total / 8.0, 0.2, 1.0)
			lights[light_idx].energy = light_energy_max * intensity
			lights[light_idx].texture_scale = (light_radius * (0.4 + intensity * 0.6)) / 64.0
			lights[light_idx].visible = true
			light_idx += 1
		si = end_si

	while light_idx < lights.size():
		lights[light_idx].visible = false
		lights[light_idx].energy = 0.0
		light_idx += 1


func _check_player_fire_proximity() -> void:
	if burning_set.is_empty():
		return
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if not p or not is_instance_valid(p):
			continue
		if p.get("is_on_fire"):
			continue
		var pos: Vector2 = p.global_position
		var px := pos.x
		var py := pos.y
		var detection_radius := 80.0
		var cx_min := int(round((px - detection_radius) / cell_size))
		var cx_max := int(round((px + detection_radius) / cell_size))
		var cy_min := int(round((py - detection_radius) / cell_size))
		var cy_max := int(round((py + detection_radius) / cell_size))
		var found := false
		for bx in range(cx_min, cx_max + 1):
			if found:
				break
			for by in range(cy_min, cy_max + 1):
				var key := Vector2i(bx, by)
				if burning_set.has(key):
					if p.has_method("set_on_fire"):
						p.set_on_fire()
					found = true
					break
