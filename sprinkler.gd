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
@export var droplet_count: int = 110
@export var droplet_size_min: float = 0.8
@export var droplet_size_max: float = 3.0
@export var head_mist_drop_count: int = 56
@export var floor_splash_drop_count: int = 44
@export var cone_spread_multiplier: float = 1.65
@export var bottom_fan_multiplier: float = 1.35
@export var shader_time_scale: float = 1.0
@export var shader_distortion: float = 0.03
@export var shader_streak_density: float = 38.0
@export var shader_edge_softness: float = 0.045
@export var shader_flow_strength: float = 3.8
@export var shader_core_fill: float = 0.92
@export var shader_bottom_density_boost: float = 1.7
@export var show_status_label: bool = false

var _sequence_id: int = 0
var is_watering: bool = false
var _spray_intensity: float = 0.0
var _anim_time: float = 0.0
var _current_spray_height: float = 0.0
var _players_in_water: Array[Node2D] = []
var _extinguish_tick_accum: float = 0.0

@onready var spray_area: Area2D = $SprayArea
@onready var spray_shape: CollisionShape2D = get_node_or_null("SprayArea/CollisionShape2D") as CollisionShape2D
@onready var spray_polygon: CollisionPolygon2D = get_node_or_null("SprayArea/CollisionPolygon2D") as CollisionPolygon2D
@onready var sprinkler_head: Polygon2D = $SprinklerHead
@onready var spray_shader: Polygon2D = get_node_or_null("SprayShader") as Polygon2D
@onready var spray_shader_material: ShaderMaterial = spray_shader.material as ShaderMaterial if spray_shader else null
var _water_sfx_player: AudioStreamPlayer2D


func _ready() -> void:
	_setup_audio_player()
	_current_spray_height = spray_height
	_refresh_spray_height(true)
	_update_spray_shape()
	_update_shader_visual()
	_update_shader_params()
	if spray_area:
		spray_area.body_entered.connect(_on_spray_body_entered)
		spray_area.body_exited.connect(_on_spray_body_exited)
	_set_watering_state(always_watering)
	queue_redraw()


func _process(delta: float) -> void:
	_anim_time += delta
	var target_intensity := 1.0 if is_watering else 0.0
	var transition_speed := 8.0
	_spray_intensity = move_toward(_spray_intensity, target_intensity, delta * transition_speed)
	_update_shader_params()
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
		spray_shader.visible = true
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

	# Fine mist droplets near the head to complement shader body.
	for i in range(maxi(0, head_mist_drop_count)):
		var seed := float(i) * 5.731
		var x := lerpf(left_x * 0.22, right_x * 0.22, _hash01(seed + 1.3))
		var y := lerpf(5.0, 26.0, _hash01(seed + 2.9))
		var pulse := 0.55 + 0.45 * sin(_anim_time * 9.0 + seed)
		var size := lerpf(1.0, 2.6, _hash01(seed + 3.2))
		draw_circle(
			Vector2(x + pulse * 2.0, y),
			size,
			Color(water_color.r, water_color.g, water_color.b, 0.30 * _spray_intensity)
		)

	# Fast droplets with stronger downward fall and sideways spread.
	var drops := maxi(0, int(droplet_count * _spray_intensity))
	for i in range(drops):
		var seed := float(i) * 13.173
		var lane := _hash01(seed + 1.7)
		var flow := fposmod(_anim_time * (1.7 + _hash01(seed + 4.0) * 1.8) + _hash01(seed + 9.0), 1.0)
		var drift := sin(_anim_time * 7.1 + seed) * (spray_width * 0.08 * (0.3 + flow * 0.8))
		var spread := lerpf(0.25, cone_spread_multiplier * 1.2, pow(flow, 1.2))
		var x := lerpf(left_x * spread, right_x * spread, lane) + drift
		var y := 10.0 + flow * (height - 8.0)
		var size := lerpf(droplet_size_max * 1.1, droplet_size_min * 0.8, flow)
		var alpha := (0.78 + flow * 0.18) * _spray_intensity
		draw_circle(Vector2(x, y), size, Color(water_color.r, water_color.g, water_color.b, alpha))
	
	# Bottom haze band so ground-adjacent water stays visible.
	var haze_alpha := 0.24 * _spray_intensity
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(left_x * 1.55, height - 30.0),
			Vector2(right_x * 1.55, height - 30.0),
			Vector2(right_x * 1.75, height + 8.0),
			Vector2(left_x * 1.75, height + 8.0),
		]),
		Color(water_color.r, water_color.g, water_color.b, haze_alpha)
	)
	
	# Ground splash droplets close to floor to avoid laser ending.
	for i in range(maxi(0, floor_splash_drop_count)):
		var seed := float(i) * 17.91
		var lane := _hash01(seed + 2.1)
		var x := lerpf(left_x * 1.55, right_x * 1.55, lane)
		var bounce := absf(sin(_anim_time * 12.0 + seed))
		var y := height - 2.0 - bounce * 7.0
		var r := lerpf(1.1, 2.8, _hash01(seed + 7.4))
		draw_circle(
			Vector2(x, y),
			r,
			Color(water_color.r, water_color.g, water_color.b, 0.42 * _spray_intensity)
		)
	
	# Softer splash line at bottom.
	var splash_alpha := 0.24 * _spray_intensity
	draw_line(
		Vector2(left_x * 1.4, height),
		Vector2(right_x * 1.4, height),
		Color(water_color.r, water_color.g, water_color.b, splash_alpha),
		2.8,
		true
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
	
	var pulse := 0.6 + 0.4 * sin(_anim_time * 10.0)
	var highlight_color := Color(0.9, 1.0, 1.0, 0.42 * _spray_intensity * pulse)
	var foam_color := Color(1.0, 1.0, 1.0, 0.55 * _spray_intensity * pulse)
	
	for i in range(_players_in_water.size() - 1, -1, -1):
		var player = _players_in_water[i]
		if not player or not is_instance_valid(player):
			_players_in_water.remove_at(i)
			continue
		
		var p_local := to_local(player.global_position)
		var head_pos := Vector2(p_local.x, p_local.y - 20.0)
		var body_pos := Vector2(p_local.x, p_local.y - 2.0)
		
		# Bright halo ring and body ring make it obvious player is soaked.
		draw_arc(head_pos, 20.0, 0.0, TAU, 28, highlight_color, 2.4, true)
		draw_arc(body_pos, 16.0, 0.0, TAU, 24, highlight_color * Color(1, 1, 1, 0.8), 1.8, true)
		
		# Small foam streaks around the player's head area.
		draw_line(head_pos + Vector2(-16, -6), head_pos + Vector2(16, -6), foam_color, 1.8, true)
		draw_line(head_pos + Vector2(-12, 0), head_pos + Vector2(12, 0), foam_color * Color(1, 1, 1, 0.8), 1.4, true)


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


func _update_water_audio_state() -> void:
	if not _water_sfx_player or not _water_sfx_player.stream:
		return
	if is_watering:
		if not _water_sfx_player.playing:
			_water_sfx_player.play()
	else:
		_water_sfx_player.stop()


func _on_water_sfx_finished() -> void:
	if is_watering and _water_sfx_player and _water_sfx_player.stream:
		_water_sfx_player.play()


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
