extends Node2D
## Sprinkler water system.
## Current design: always watering (no button trigger required).

@export_group("Timing")
@export var activation_delay: float = 0.5
@export var watering_duration: float = 2.0
@export var always_watering: bool = true

@export_group("Audio")
@export var water_sfx_path: String = "res://audio/water.wav"
@export var water_sfx_volume_db: float = 3.0

@export_group("Water Light")
@export var enable_water_light: bool = true
@export var water_light_color: Color = Color(0.32, 0.88, 1.0, 1.0)
@export var water_light_energy: float = 1.55
@export var water_light_flicker_strength: float = 0.06
@export var enable_fluorescent_droplet_lights: bool = false
@export var droplet_light_count: int = 10
@export var droplet_light_energy: float = 0.42
@export var droplet_light_radius: float = 34.0

@export_group("Water Area")
@export var spray_width: float = 150.0
@export var spray_height: float = 200.0 ## Minimum spray distance.
@export var auto_size_to_floor: bool = true
@export var max_floor_probe_distance: float = 8000.0
@export var floor_collision_mask: int = 1
@export var floor_visual_padding: float = 2.0
@export var ignore_dynamic_bodies_in_floor_probe: bool = true
@export var water_color: Color = Color(0.58, 0.9, 1.0, 1.0)

@export_group("Water Visual")
@export var droplet_count: int = 52
@export var droplet_size_min: float = 1.5
@export var droplet_size_max: float = 4.2
@export var head_mist_drop_count: int = 22
@export var floor_splash_drop_count: int = 18
@export var cone_spread_multiplier: float = 1.65
@export var bottom_fan_multiplier: float = 1.35
@export var shader_time_scale: float = 1.0
@export var shader_distortion: float = 0.03
@export var shader_streak_density: float = 38.0
@export var shader_edge_softness: float = 0.045
@export var shader_flow_strength: float = 3.8
@export var shader_core_fill: float = 0.92
@export var shader_bottom_density_boost: float = 1.7
@export var droplet_glow_color: Color = Color(0.55, 0.95, 1.0, 1.0)
@export var droplet_core_color: Color = Color(0.92, 1.0, 1.0, 1.0)
@export var droplet_glow_boost: float = 2.6
@export var droplet_core_boost: float = 2.0
@export var additive_droplet_render: bool = true
@export var show_spray_body_shader: bool = false
@export var show_status_label: bool = false

var _sequence_id: int = 0
var is_watering: bool = false
var _spray_intensity: float = 0.0
var _anim_time: float = 0.0
var _current_spray_height: float = 0.0
var _players_in_water: Array[Node2D] = []
var _extinguish_tick_accum: float = 0.0
var _droplet_lights: Array[PointLight2D] = []
var _droplet_light_texture: Texture2D
var _droplet_draw_material: CanvasItemMaterial

@onready var spray_area: Area2D = $SprayArea
@onready var spray_shape: CollisionShape2D = get_node_or_null("SprayArea/CollisionShape2D") as CollisionShape2D
@onready var spray_polygon: CollisionPolygon2D = get_node_or_null("SprayArea/CollisionPolygon2D") as CollisionPolygon2D
@onready var sprinkler_head: Polygon2D = $SprinklerHead
@onready var spray_shader: Polygon2D = get_node_or_null("SprayShader") as Polygon2D
@onready var spray_shader_material: ShaderMaterial = spray_shader.material as ShaderMaterial if spray_shader else null
@onready var water_light: PointLight2D = get_node_or_null("WaterLight") as PointLight2D
@onready var water_rim_light: PointLight2D = get_node_or_null("WaterRimLight") as PointLight2D
var _water_sfx_player: AudioStreamPlayer2D


func _ready() -> void:
	_setup_droplet_render_material()
	_setup_audio_player()
	_setup_water_light()
	_setup_fluorescent_droplet_lights()
	_current_spray_height = spray_height
	_refresh_spray_height(true)
	_update_spray_shape()
	_update_shader_visual()
	_update_shader_params()
	if spray_shader:
		spray_shader.visible = show_spray_body_shader and is_watering
	if spray_area:
		spray_area.body_entered.connect(_on_spray_body_entered)
		spray_area.body_exited.connect(_on_spray_body_exited)
	_set_watering_state(always_watering)
	queue_redraw()


func _setup_droplet_render_material() -> void:
	if additive_droplet_render:
		_droplet_draw_material = CanvasItemMaterial.new()
		_droplet_draw_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = _droplet_draw_material
	else:
		material = null


func _process(delta: float) -> void:
	_anim_time += delta
	var target_intensity := 1.0 if is_watering else 0.0
	var transition_speed := 8.0
	_spray_intensity = move_toward(_spray_intensity, target_intensity, delta * transition_speed)
	_update_shader_params()
	_update_water_light()
	_update_fluorescent_droplet_lights()
	if _spray_intensity > 0.001 or is_watering:
		queue_redraw()


func _physics_process(_delta: float) -> void:
	if auto_size_to_floor:
		_refresh_spray_height(false)
	if is_watering:
		_extinguish_tick_accum += _delta
		if _extinguish_tick_accum >= 0.1:
			_extinguish_tick_accum = 0.0
			_extinguish_players_in_water()


func trigger_sprinkler() -> void:
	"""Start sprinkler sequence (delay + active duration)."""
	if always_watering:
		_set_watering_state(true)
		return
	
	_sequence_id += 1
	var sequence = _sequence_id
	_set_watering_state(false)
	
	await get_tree().create_timer(activation_delay).timeout
	if sequence != _sequence_id:
		return
	
	_set_watering_state(true)
	
	await get_tree().create_timer(watering_duration).timeout
	if sequence != _sequence_id:
		return
	
	_set_watering_state(false)


func _set_watering_state(active: bool) -> void:
	is_watering = active
	if spray_area:
		spray_area.monitoring = active
	if spray_shape:
		# When polygon collider exists, keep rectangle disabled.
		spray_shape.disabled = true if spray_polygon else (not active)
	if spray_polygon:
		spray_polygon.disabled = not active
	if not active:
		_set_water_protection_for_all(false)
		_players_in_water.clear()
		_extinguish_tick_accum = 0.0
	if sprinkler_head:
		sprinkler_head.color = Color(0.55, 0.85, 1.0, 1.0) if active else Color(0.65, 0.65, 0.7, 1.0)
	if spray_shader:
		spray_shader.visible = show_spray_body_shader and active
	if active:
		_collect_players_currently_in_water()
		_extinguish_players_in_water()
	_update_water_audio_state()
	queue_redraw()


func _update_spray_shape() -> void:
	if spray_shape and spray_shape.shape is RectangleShape2D:
		var rect := spray_shape.shape as RectangleShape2D
		rect.size = Vector2(spray_width, _current_spray_height)
		spray_shape.position = Vector2(0.0, _current_spray_height * 0.5)
	
	if spray_polygon:
		var top_half := spray_width * 0.5 * 0.38
		var bottom_half := spray_width * 0.5 * cone_spread_multiplier * bottom_fan_multiplier
		spray_polygon.polygon = PackedVector2Array([
			Vector2(-top_half, 6.0),
			Vector2(top_half, 6.0),
			Vector2(bottom_half, _current_spray_height),
			Vector2(-bottom_half, _current_spray_height),
		])
	_update_shader_visual()


func _refresh_spray_height(force_update: bool) -> void:
	var target_height := spray_height
	
	if auto_size_to_floor:
		var from := global_position + Vector2(0.0, 6.0)
		var to := from + Vector2(0.0, max_floor_probe_distance)
		var hit := _intersect_floor_ray(from, to)
		if not hit.is_empty():
			var hit_pos: Vector2 = hit["position"]
			var local_y := to_local(hit_pos).y - floor_visual_padding
			target_height = maxf(spray_height, local_y)
	
	target_height = clampf(target_height, spray_height, max_floor_probe_distance)
	if force_update or absf(target_height - _current_spray_height) > 0.5:
		_current_spray_height = target_height
		_update_spray_shape()
		queue_redraw()


func _draw() -> void:
	_draw_water_accents()
	
	if show_status_label:
		var label_color := Color(0.3, 0.9, 1.0, 0.9) if is_watering else Color(0.6, 0.6, 0.65, 0.9)
		_draw_text_label("WATER ON" if is_watering else "WATER OFF", Vector2(0, -26), label_color, 14)


func _draw_water_accents() -> void:
	if _spray_intensity <= 0.001:
		return
	
	var left_x := -spray_width * 0.5
	var right_x := spray_width * 0.5
	var height := _current_spray_height
	var glow_tint := droplet_glow_color
	var core_tint := droplet_core_color

	# --- Resolve player impact position (first player in spray) ---
	var has_impact := false
	var impact_pos := Vector2.ZERO   # local space
	var player_hw  := 20.0           # half-width of player hitbox for deflection
	var player_hh  := 52.0           # distance from origin to top of head
	for pl in _players_in_water:
		if pl and is_instance_valid(pl):
			impact_pos = to_local(pl.global_position)
			# Only block stream if player is within the spray volume
			if impact_pos.y > 10.0 and impact_pos.y < height:
				has_impact = true
			break
	# Flow-t at which a droplet would reach the player's top (head)
	var impact_top_y  := impact_pos.y - player_hh
	var impact_flow_t := clampf((impact_top_y - 10.0) / maxf(height - 8.0, 1.0), 0.0, 0.92)

	# --- Head mist (not affected by player) ---
	for i in range(maxi(0, head_mist_drop_count)):
		var seed := float(i) * 5.731
		var x := lerpf(left_x * 0.22, right_x * 0.22, _hash01(seed + 1.3))
		var y := lerpf(5.0, 26.0, _hash01(seed + 2.9))
		var pulse := 0.55 + 0.45 * sin(_anim_time * 9.0 + seed)
		var size := lerpf(1.0, 2.6, _hash01(seed + 3.2))
		var p := Vector2(x + pulse * 2.0, y)
		var core := size * 1.15
		draw_circle(p, core * 2.2, Color(glow_tint.r, glow_tint.g, glow_tint.b, 0.16 * _spray_intensity * droplet_glow_boost))
		draw_circle(p, core, Color(core_tint.r, core_tint.g, core_tint.b, 0.38 * _spray_intensity * droplet_core_boost))

	# --- Falling droplets: player-aware ---
	var drops := maxi(0, int(droplet_count * _spray_intensity))
	for i in range(drops):
		var seed := float(i) * 13.173
		var lane  := _hash01(seed + 1.7)
		var flow  := fposmod(_anim_time * (1.7 + _hash01(seed + 4.0) * 1.8) + _hash01(seed + 9.0), 1.0)
		var drift := sin(_anim_time * 7.1 + seed) * (spray_width * 0.08 * (0.3 + flow * 0.8))
		var spread := lerpf(0.25, cone_spread_multiplier * 1.2, pow(flow, 1.2))
		var x := lerpf(left_x * spread, right_x * spread, lane) + drift
		var y := 10.0 + flow * (height - 8.0)

		# Check whether this droplet lane intersects the player at impact height
		var lane_hits_player := false
		var x_at_impact := 0.0
		if has_impact:
			var imp_spread := lerpf(0.25, cone_spread_multiplier * 1.2, pow(impact_flow_t, 1.2))
			var imp_drift  := sin(_anim_time * 7.1 + seed) * (spray_width * 0.08 * (0.3 + impact_flow_t * 0.8))
			x_at_impact    = lerpf(left_x * imp_spread, right_x * imp_spread, lane) + imp_drift
			lane_hits_player = absf(x_at_impact - impact_pos.x) < player_hw

		if has_impact and lane_hits_player and flow > impact_flow_t:
			# Droplet has reached the player — deflect it outward.
			var deflect_phase := minf((flow - impact_flow_t) / 0.38, 1.0)
			# Side: outward from player centre. Ties go random direction.
			var side := signf(x_at_impact - impact_pos.x)
			if absf(x_at_impact - impact_pos.x) < 3.0:
				side = 1.0 if _hash01(seed * 3.1 + 7.0) > 0.5 else -1.0
			var sx := x_at_impact + side * deflect_phase * 38.0
			# Parabolic arc: rises briefly then falls (real splash physics).
			var sy := impact_top_y - deflect_phase * 14.0 + deflect_phase * deflect_phase * 28.0
			var size := lerpf(droplet_size_max, droplet_size_min, flow) * (1.0 - deflect_phase * 0.55)
			var alpha := (1.0 - deflect_phase) * _spray_intensity * 0.88
			var sp := Vector2(sx, sy)
			draw_circle(sp, size * 2.2, Color(glow_tint.r, glow_tint.g, glow_tint.b, alpha * 0.22 * droplet_glow_boost))
			draw_circle(sp, size, Color(core_tint.r, core_tint.g, core_tint.b, alpha * 0.80 * droplet_core_boost))
		else:
			# Normal downward droplet.
			# When hitting player lane but still above, draw only down to player top.
			var draw_y := y
			if has_impact and lane_hits_player:
				draw_y = minf(y, impact_top_y)
			var size  := lerpf(droplet_size_max, droplet_size_min, flow)
			var alpha := (0.78 + flow * 0.18) * _spray_intensity
			var p := Vector2(x, draw_y)
			draw_circle(p, size * 2.25, Color(glow_tint.r, glow_tint.g, glow_tint.b, alpha * 0.20 * droplet_glow_boost))
			draw_circle(p, size, Color(core_tint.r, core_tint.g, core_tint.b, alpha * 0.72 * droplet_core_boost))

	# --- Floor splashes (only draw if no player blocking the floor lane) ---
	for i in range(maxi(0, floor_splash_drop_count)):
		var seed := float(i) * 17.91
		var lane  := _hash01(seed + 2.1)
		var x     := lerpf(left_x * 1.55, right_x * 1.55, lane)
		# Skip floor droplets that are directly below the player (blocked).
		if has_impact and absf(x - impact_pos.x) < player_hw * 1.4:
			continue
		var bounce := absf(sin(_anim_time * 12.0 + seed))
		var y      := height - 2.0 - bounce * 7.0
		var r      := lerpf(1.1, 2.8, _hash01(seed + 7.4))
		draw_circle(Vector2(x, y), r * 2.1, Color(glow_tint.r, glow_tint.g, glow_tint.b, 0.18 * _spray_intensity * droplet_glow_boost))
		draw_circle(Vector2(x, y), r, Color(core_tint.r, core_tint.g, core_tint.b, 0.46 * _spray_intensity * droplet_core_boost))

	# Subtle near-floor mist.
	var haze_alpha := 0.055 * _spray_intensity
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(left_x * 1.18, height - 12.0),
			Vector2(right_x * 1.18, height - 12.0),
			Vector2(right_x * 1.24, height + 5.0),
			Vector2(left_x * 1.24, height + 5.0),
		]),
		Color(water_color.r, water_color.g, water_color.b, haze_alpha)
	)
	var splash_alpha := 0.08 * _spray_intensity
	draw_line(
		Vector2(left_x * 1.4, height), Vector2(right_x * 1.4, height),
		Color(water_color.r, water_color.g, water_color.b, splash_alpha), 1.4, true
	)

	_draw_player_in_water_feedback()


func _update_shader_visual() -> void:
	if not spray_shader:
		return
	var top_half := spray_width * 0.5 * 0.42
	var bottom_half := spray_width * 0.5 * cone_spread_multiplier
	var lower_mid_half := bottom_half * bottom_fan_multiplier
	spray_shader.polygon = PackedVector2Array([
		Vector2(-top_half, 6),
		Vector2(top_half, 6),
		Vector2(bottom_half, _current_spray_height * 0.72),
		Vector2(lower_mid_half, _current_spray_height),
		Vector2(-lower_mid_half, _current_spray_height),
		Vector2(-bottom_half, _current_spray_height * 0.72),
	])


func _update_shader_params() -> void:
	if not spray_shader_material:
		return
	spray_shader_material.set_shader_parameter("water_color", water_color)
	spray_shader_material.set_shader_parameter("intensity", _spray_intensity)
	spray_shader_material.set_shader_parameter("time_scale", shader_time_scale)
	spray_shader_material.set_shader_parameter("distortion", shader_distortion)
	spray_shader_material.set_shader_parameter("streak_density", shader_streak_density)
	spray_shader_material.set_shader_parameter("edge_softness", shader_edge_softness)
	spray_shader_material.set_shader_parameter("flow_strength", shader_flow_strength)
	spray_shader_material.set_shader_parameter("core_fill", shader_core_fill)
	spray_shader_material.set_shader_parameter("bottom_density_boost", shader_bottom_density_boost)


func _draw_player_in_water_feedback() -> void:
	if _players_in_water.is_empty() or _spray_intensity <= 0.001:
		return

	var drop_col := droplet_glow_color
	var core_col := droplet_core_color
	var foam_col := Color(0.88, 1.0, 1.0, 1.0)

	for i in range(_players_in_water.size() - 1, -1, -1):
		var player = _players_in_water[i]
		if not player or not is_instance_valid(player):
			_players_in_water.remove_at(i)
			continue

		var p_local  := to_local(player.global_position)
		# origin is ~knee-level; shift down to reach actual ground/feet
		var feet_y   := p_local.y + 24.0
		var head_y   := p_local.y - 64.0
		var cx       := p_local.x
		var hw       := 18.0   # visual half-width

		# ── 1. Continuous shoulder/head impact spray ──────────────────────
		# Water hits the top of the player and fans outward left and right.
		var impact_count := 10
		for s in range(impact_count):
			var seed  := float(s) * 6.17 + 200.0
			var phase := fposmod(_anim_time * (2.4 + _hash01(seed) * 1.2) + _hash01(seed + 1.0), 1.0)
			# Left half → goes left; right half → goes right.
			var side  := -1.0 if s < impact_count / 2 else 1.0
			var angle := side * lerpf(0.05, 0.55, _hash01(seed + 2.0)) * PI
			var spd   := lerpf(20.0, 45.0, _hash01(seed + 3.0))
			var dx    := cos(angle - PI * 0.5) * spd * phase + side * phase * 8.0
			# Parabolic: initial upward kick then falls with gravity.
			var dy    := sin(angle - PI * 0.5) * spd * phase + 72.0 * phase * phase
			var drop  := Vector2(cx + dx, head_y + dy)
			var r     := lerpf(2.2, 0.9, phase)
			var alpha := (1.0 - phase) * _spray_intensity * 0.92
			draw_circle(drop, r * 2.4, Color(drop_col.r, drop_col.g, drop_col.b, alpha * 0.28 * droplet_glow_boost))
			draw_circle(drop, r,       Color(core_col.r, core_col.g, core_col.b, alpha * droplet_core_boost))

		# ── 2. Side-body drip streams ─────────────────────────────────────
		# Water runs down the sides of the player and drips off.
		var drip_count := 6
		for d in range(drip_count):
			var seed  := float(d) * 9.43 + 300.0
			var phase := fposmod(_anim_time * (1.8 + _hash01(seed) * 0.9) + _hash01(seed + 4.0), 1.0)
			var side  := -1.0 if d < drip_count / 2 else 1.0
			var sx    := cx + side * (hw + _hash01(seed + 6.0) * 8.0)
			# Drips travel downward along the body from head to feet.
			var sy    := lerpf(head_y + 8.0, feet_y, phase)
			var r     := lerpf(1.6, 0.7, phase)
			var alpha := _spray_intensity * 0.65 * (1.0 - absf(phase - 0.5) * 0.6)
			draw_circle(Vector2(sx, sy), r * 2.0, Color(drop_col.r, drop_col.g, drop_col.b, alpha * 0.22 * droplet_glow_boost))
			draw_circle(Vector2(sx, sy), r,        Color(core_col.r, core_col.g, core_col.b, alpha * droplet_core_boost))

		# ── 3. Floor splash puddle at feet ────────────────────────────────
		# Water that runs off the player hits the ground and fans outward.
		var puddle_count := 8
		for p_i in range(puddle_count):
			var seed  := float(p_i) * 11.29 + 400.0
			var phase := fposmod(_anim_time * (2.1 + _hash01(seed) * 1.3) + _hash01(seed + 2.0), 1.0)
			var side  := -1.0 if p_i < puddle_count / 2 else 1.0
			var px    := cx + side * lerpf(4.0, hw * 2.2, phase)
			var py    := feet_y - lerpf(0.0, 6.0, phase) + phase * phase * 8.0
			var r     := lerpf(2.0, 0.7, phase)
			var alpha := (1.0 - phase) * _spray_intensity * 0.78
			draw_circle(Vector2(px, py), r * 2.1, Color(drop_col.r, drop_col.g, drop_col.b, alpha * 0.24 * droplet_glow_boost))
			draw_circle(Vector2(px, py), r,        Color(core_col.r, core_col.g, core_col.b, alpha * droplet_core_boost))

		# Expanding foam ring on the floor.
		for f in range(2):
			var phase := fposmod(_anim_time * 1.6 + f * 0.5, 1.0)
			var fw    := lerpf(hw * 0.5, hw * 2.8, phase)
			var alpha := (1.0 - phase) * _spray_intensity * 0.44
			draw_line(
				Vector2(cx - fw, feet_y - 1.0), Vector2(cx + fw, feet_y - 1.0),
				Color(foam_col.r, foam_col.g, foam_col.b, alpha), 2.0, true
			)


func _intersect_floor_ray(from: Vector2, to: Vector2) -> Dictionary:
	var exclude: Array[RID] = []
	if spray_area:
		exclude.append(spray_area.get_rid())
	
	var tries := 0
	while tries < 8:
		var query := PhysicsRayQueryParameters2D.create(from, to)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		query.collision_mask = floor_collision_mask
		query.exclude = exclude
		
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		
		var collider = hit.get("collider")
		if _should_ignore_floor_collider(collider):
			var collider_rid = hit.get("rid")
			if collider_rid != null:
				exclude.append(collider_rid)
			tries += 1
			continue
		
		return hit
	
	return {}


func _should_ignore_floor_collider(collider: Variant) -> bool:
	if collider == null:
		return false
	if collider is Node and (collider as Node).is_in_group("player"):
		return true
	if collider is Node and (collider as Node).name == "Player":
		return true
	if ignore_dynamic_bodies_in_floor_probe and (collider is CharacterBody2D or collider is RigidBody2D):
		return true
	return false


func _on_spray_body_entered(body: Node2D) -> void:
	if _is_player_body(body) and not _players_in_water.has(body):
		_players_in_water.append(body)
		_set_player_water_protection(body, true)
		_try_extinguish_player(body)


func _on_spray_body_exited(body: Node2D) -> void:
	if _is_player_body(body):
		_players_in_water.erase(body)
		_set_player_water_protection(body, false)


func _is_player_body(body: Node2D) -> bool:
	return body and (body.is_in_group("player") or body.name == "Player")


func _collect_players_currently_in_water() -> void:
	if not spray_area:
		return
	var bodies := spray_area.get_overlapping_bodies()
	for b in bodies:
		if b is Node2D and _is_player_body(b as Node2D):
			var player_body := b as Node2D
			if not _players_in_water.has(player_body):
				_players_in_water.append(player_body)
			_set_player_water_protection(player_body, true)


func _extinguish_players_in_water() -> void:
	for i in range(_players_in_water.size() - 1, -1, -1):
		var p = _players_in_water[i]
		if not p or not is_instance_valid(p):
			_players_in_water.remove_at(i)
			continue
		_try_extinguish_player(p)


func _try_extinguish_player(player: Node2D) -> void:
	if not player or not is_instance_valid(player):
		return
	_set_player_water_protection(player, is_watering)
	if player.get("is_on_fire") and player.has_method("extinguish_fire"):
		player.extinguish_fire()


func _set_player_water_protection(player: Node2D, active: bool) -> void:
	if not player or not is_instance_valid(player):
		return
	if player.has_method("set_water_protected"):
		player.set_water_protected(active)


func _set_water_protection_for_all(active: bool) -> void:
	for p in _players_in_water:
		if p and is_instance_valid(p):
			_set_player_water_protection(p, active)


func _setup_audio_player() -> void:
	_water_sfx_player = AudioStreamPlayer2D.new()
	_water_sfx_player.name = "WaterSfxPlayer"
	_water_sfx_player.volume_db = water_sfx_volume_db
	_water_sfx_player.finished.connect(_on_water_sfx_finished)
	add_child(_water_sfx_player)
	
	var water_stream = load(water_sfx_path)
	if water_stream:
		_water_sfx_player.stream = water_stream


func _setup_water_light() -> void:
	if not water_light:
		return
	if not enable_water_light:
		water_light.visible = false
		water_light.energy = 0.0
		if water_rim_light:
			water_rim_light.visible = false
			water_rim_light.energy = 0.0
		return
	var cone_tex := _build_smooth_cone_light_texture()
	water_light.texture = cone_tex
	water_light.color = water_light_color
	water_light.texture_scale = 1.0
	water_light.energy = 0.0
	water_light.visible = false
	if water_rim_light:
		water_rim_light.texture = cone_tex
		water_rim_light.color = water_light_color
		water_rim_light.texture_scale = 1.0
		water_rim_light.energy = 0.0
		water_rim_light.visible = false


func _setup_fluorescent_droplet_lights() -> void:
	for l in _droplet_lights:
		if l and is_instance_valid(l):
			l.queue_free()
	_droplet_lights.clear()
	
	if not enable_fluorescent_droplet_lights:
		return
	
	var count := maxi(0, droplet_light_count)
	if count <= 0:
		return
	
	_droplet_light_texture = _build_droplet_light_texture()
	for i in range(count):
		var light := PointLight2D.new()
		light.name = "DropletLight_%d" % i
		light.texture = _droplet_light_texture
		light.texture_scale = 1.0
		light.energy = 0.0
		light.visible = false
		light.color = droplet_glow_color
		light.z_index = 12
		var s := droplet_light_radius / 64.0
		light.scale = Vector2(s, s)
		add_child(light)
		_droplet_lights.append(light)


func _update_fluorescent_droplet_lights() -> void:
	if _droplet_lights.is_empty():
		return
	
	var active := enable_fluorescent_droplet_lights and _spray_intensity > 0.01 and is_watering
	if not active:
		for l in _droplet_lights:
			if not l:
				continue
			l.visible = false
			l.energy = 0.0
		return
	
	var left_x := -spray_width * 0.5
	var right_x := spray_width * 0.5
	var h := _current_spray_height
	for i in range(_droplet_lights.size()):
		var l := _droplet_lights[i]
		if not l:
			continue
		# Keep light positions aligned with the same droplet motion used in _draw_water_accents().
		var seed := float(i) * 13.173
		var lane := _hash01(seed + 1.7)
		var flow := fposmod(_anim_time * (1.7 + _hash01(seed + 4.0) * 1.8) + _hash01(seed + 9.0), 1.0)
		var spread := lerpf(0.25, cone_spread_multiplier * 1.2, pow(flow, 1.2))
		var drift := sin(_anim_time * 7.1 + seed) * (spray_width * 0.08 * (0.3 + flow * 0.8))
		var x := lerpf(left_x * spread, right_x * spread, lane) + drift
		var y := 10.0 + flow * (h - 8.0)
		var pulse := 0.90 + 0.10 * sin(_anim_time * 10.0 + seed * 0.5)
		l.position = Vector2(x, y)
		l.color = droplet_glow_color
		l.energy = droplet_light_energy * _spray_intensity * pulse
		l.visible = true


func _build_droplet_light_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (float(x) / float(size - 1)) * 2.0 - 1.0
			var v := (float(y) / float(size - 1)) * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			if r >= 1.0:
				continue
			var core := exp(-pow(r, 2.0) * 5.2)
			var halo := exp(-pow(r, 1.25) * 1.9)
			var a := clampf(core * 0.95 + halo * 0.28, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _update_water_light() -> void:
	if not water_light:
		return
	if not enable_water_light:
		water_light.visible = false
		water_light.energy = 0.0
		if water_rim_light:
			water_rim_light.visible = false
			water_rim_light.energy = 0.0
		return
	
	var active := _spray_intensity > 0.01
	if not active:
		water_light.visible = false
		water_light.energy = 0.0
		if water_rim_light:
			water_rim_light.visible = false
			water_rim_light.energy = 0.0
		return
	
	var flicker := 1.0 + sin(_anim_time * 8.3) * water_light_flicker_strength
	var pulse  := 0.94 + 0.06 * sin(_anim_time * 3.7 + 1.1)
	
	# The cone texture apex is at v=0.5 (pixel row 128 of 256).
	# The bottom half of the texture covers the spray volume.
	# Anchor the light at the sprinkler head (y=6); scale Y so the
	# bottom half of the texture exactly covers _current_spray_height pixels.
	# The texture is 256px; bottom half = 128px reference.
	var spread_w := spray_width * cone_spread_multiplier * bottom_fan_multiplier * 2.0
	var scale_x := maxf(spread_w, 120.0) / 256.0
	var scale_y := (_current_spray_height * 1.05) / 128.0   # bottom-half reference
	water_light.position = Vector2(0.0, 6.0)
	water_light.scale = Vector2(scale_x, scale_y)
	water_light.texture_scale = 1.0
	water_light.color = water_light_color
	water_light.energy = water_light_energy * _spray_intensity * flicker * pulse
	water_light.visible = true
	
	# Rim light: same cone, slightly larger, centered lower for ambient spill.
	if water_rim_light:
		water_rim_light.position = Vector2(0.0, 6.0)
		water_rim_light.scale = Vector2(scale_x * 1.3, scale_y * 1.15)
		water_rim_light.texture_scale = 1.0
		water_rim_light.color = water_light_color
		water_rim_light.energy = water_light_energy * _spray_intensity * 0.28 * pulse
		water_rim_light.visible = true


func _build_smooth_cone_light_texture() -> ImageTexture:
	# Cone apex at (0.5, 0.5); cone opens downward through bottom half of texture.
	# All falloffs are pure Gaussian - no step functions, no hard contours,
	# so no bell silhouette or layer banding is possible.
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for yi in size:
		var v := float(yi) / float(size - 1)
		# Upper half stays dark (light only goes downward).
		if v < 0.5:
			continue
		var t := (v - 0.5) * 2.0   # 0 = apex, 1 = bottom
		# Cone grows wider as t increases; use smooth mapping so it never snaps.
		var half_w := lerpf(0.015, 0.42, t * t * (3.0 - 2.0 * t))
		for xi in size:
			var u := float(xi) / float(size - 1)
			var dx := absf(u - 0.5)
			# Normalize horizontal distance by the local cone half-width,
			# then apply a pure Gaussian. This produces smooth falloff at
			# every depth with NO hard edge anywhere.
			var norm := dx / maxf(half_w, 0.001)
			var side := exp(-norm * norm * 2.8)
			# Soft fade-in just below the apex so the top isn't a hard dot.
			var top_fade := smoothstep(0.0, 0.18, t)
			# Very slight brightness taper toward the floor (natural light loss).
			var depth_fade := 1.0 - t * 0.22
			var a := side * top_fade * depth_fade
			if a <= 0.002:
				continue
			# Sub-pixel dither to break 8-bit quantization bands.
			var g_seed: float = sin(Vector2(float(xi), float(yi)).dot(Vector2(12.9898, 78.233))) * 43758.5453
			var dither: float = (g_seed - floor(g_seed) - 0.5) * 0.009
			a = clampf(a + dither, 0.0, 1.0)
			img.set_pixel(xi, yi, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _update_water_audio_state() -> void:
	if not _water_sfx_player or not _water_sfx_player.stream:
		return
	if _is_death_scene_active():
		_water_sfx_player.stop()
		return
	if is_watering:
		if not _water_sfx_player.playing:
			_water_sfx_player.play()
	else:
		_water_sfx_player.stop()


func _on_water_sfx_finished() -> void:
	if is_watering and not _is_death_scene_active() and _water_sfx_player and _water_sfx_player.stream:
		_water_sfx_player.play()


func _is_death_scene_active() -> bool:
	# Death UI is added to root on player death.
	var root := get_tree().root
	if root and root.get_node_or_null("DeathUI"):
		return true
	
	# Fallback: player flagged as dying before UI fully appears.
	for p in get_tree().get_nodes_in_group("player"):
		if p and is_instance_valid(p) and p.get("is_dying"):
			return true
	return false


func _hash01(v: float) -> float:
	var n := sin(v * 12.9898) * 43758.5453
	return n - floor(n)


func _draw_text_label(text: String, pos: Vector2, color: Color, size: int = 14) -> void:
	var font := ThemeDB.fallback_font
	if not font:
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	var offset := Vector2(-text_size.x / 2.0, text_size.y / 4.0)
	draw_string(font, pos + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
