extends AnimatableBody2D

@export_group("Cage Properties")
@export var cage_width: float = 252.0
@export var cage_height: float = 274.0
@export var wall_thickness: float = 10.0
@export var push_speed: float = 195.0
@export var fall_speed: float = 800.0

@export_group("Kick Durability")
@export var kicks_to_break: int = 10
@export var kicks_between_crack_stages: int = 2
@export var shake_pixels: float = 7.0
@export var shake_duration: float = 0.12

@export_group("Shatter")
@export var fragment_count: int = 18
@export var fragment_lifetime: float = 1.5
@export var shatter_force: float = 500.0
@export var shatter_force_variation: float = 300.0
@export var cage_fragment_color: Color = Color(0.52, 0.44, 0.36, 0.92)

@export_group("Break VFX (door-style)")
@export var break_particle_amount: int = 32
@export var break_camera_shake: float = 18.0
@export var break_camera_shake_duration: float = 0.15
@export var break_hitstop_seconds: float = 0.04
@export var fracture_volume_boost_db: float = 6.0

@export_group("Fade After Escape")
@export var linger_time: float = 3.0
@export var fade_duration: float = 0.5

@onready var back_sprite: Sprite2D = $BackSprite
@onready var front_sprite: Sprite2D = $FrontSprite
@onready var crack_overlay: Node2D = $CrackOverlay

var player: CharacterBody2D = null
var _fall_velocity := 0.0
var _player_was_inside: bool = false
var _fading: bool = false
var _fade_timer: float = 0.0

var kick_count: int = 0
var _broken: bool = false
var _shake_tween: Tween

var sfx_player: AudioStreamPlayer
var crack_sfx: AudioStream
var fracture_sfx: AudioStream


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	add_to_group("kickable_objects")
	_setup_sprites()
	_setup_audio()


func _setup_audio() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	if AudioServer.get_bus_index("Game") != -1:
		sfx_player.bus = "Game"
	else:
		sfx_player.bus = "Master"
	add_child(sfx_player)
	if ResourceLoader.exists("res://audio/cracking.wav"):
		crack_sfx = load("res://audio/cracking.wav")
	if ResourceLoader.exists("res://audio/fracture.wav"):
		fracture_sfx = load("res://audio/fracture.wav")


func get_kick_range_override() -> float:
	return maxf(160.0, cage_width * 0.65)


func kick(direction: Vector2, _speed: float = 0.0) -> void:
	if _broken or _fading:
		return
	kick_count += 1
	_play_kick_shake()
	if kick_count >= kicks_to_break:
		_break_from_kicks(direction)
		return
	if crack_sfx and sfx_player:
		sfx_player.stream = crack_sfx
		sfx_player.pitch_scale = randf_range(0.95, 1.05)
		sfx_player.play()
	if kick_count % kicks_between_crack_stages == 0:
		_add_accumulated_crack_batch()


func can_be_kicked() -> bool:
	return not _broken and not _fading


func _play_kick_shake() -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	var o := Vector2(randf_range(-shake_pixels, shake_pixels), randf_range(-shake_pixels, shake_pixels))
	_shake_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_shake_tween.tween_property(front_sprite, "position", o, shake_duration * 0.35)
	_shake_tween.parallel().tween_property(back_sprite, "position", o * 0.85, shake_duration * 0.35)
	_shake_tween.tween_property(front_sprite, "position", Vector2.ZERO, shake_duration * 0.65)
	_shake_tween.parallel().tween_property(back_sprite, "position", Vector2.ZERO, shake_duration * 0.65)


func _add_accumulated_crack_batch() -> void:
	if not crack_overlay:
		return
	var batch_idx: int = kick_count / kicks_between_crack_stages
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position) ^ (batch_idx * 100003) ^ (kick_count * 9241)
	var n_primary: int = 2 if batch_idx <= 2 else 3
	for crack_i in range(n_primary):
		_spawn_stress_crack_group(rng, batch_idx, crack_i)


func _spawn_stress_crack_group(rng: RandomNumberGenerator, batch_idx: int, crack_i: int) -> void:
	var hw := cage_width * 0.5
	var hh := cage_height * 0.5
	var se := _random_frame_crack_endpoints(rng, hw, hh)
	var p0: Vector2 = se[0]
	var p1: Vector2 = se[1]
	var depth: int = 3 + mini(batch_idx, 2)
	var path := _jagged_stress_path(p0, p1, rng, depth)
	if path.size() < 2:
		return
	var group := Node2D.new()
	group.name = "StressCrack_%d_%d" % [batch_idx, crack_i]
	crack_overlay.add_child(group)
	_add_layered_metal_crack_lines(group, path, rng)
	if rng.randf() < 0.35 + float(batch_idx) * 0.08:
		var branch_len: float = rng.randf_range(14.0, 36.0)
		var mid_i: int = rng.randi_range(1, maxi(path.size() - 2, 1))
		var base: Vector2 = path[mid_i]
		var seg_dir: Vector2 = (path[mid_i] - path[mid_i - 1]).normalized()
		if seg_dir.length_squared() < 0.01:
			seg_dir = Vector2.RIGHT
		var branch_dir: Vector2 = seg_dir.rotated(rng.randf_range(0.5, 1.2) * (1.0 if rng.randf() > 0.5 else -1.0))
		var bend := base + branch_dir * branch_len
		var bpath := _jagged_stress_path(base, bend, rng, 2)
		if bpath.size() >= 2:
			_add_layered_metal_crack_lines(group, bpath, rng)


func _random_frame_crack_endpoints(rng: RandomNumberGenerator, hw: float, hh: float) -> Array:
	var side: int = rng.randi_range(0, 3)
	var start: Vector2
	match side:
		0:
			start = Vector2(-hw * rng.randf_range(0.82, 0.99), rng.randf_range(-hh * 0.78, hh * 0.78))
		1:
			start = Vector2(hw * rng.randf_range(0.82, 0.99), rng.randf_range(-hh * 0.78, hh * 0.78))
		2:
			start = Vector2(rng.randf_range(-hw * 0.72, hw * 0.72), -hh * rng.randf_range(0.82, 0.99))
		_:
			start = Vector2(rng.randf_range(-hw * 0.72, hw * 0.72), hh * rng.randf_range(0.82, 0.99))
	var inward := Vector2(rng.randf_range(-hw * 0.35, hw * 0.35), rng.randf_range(-hh * 0.35, hh * 0.35))
	var span: float = rng.randf_range(minf(hw, hh) * 0.42, minf(hw, hh) * 0.92)
	var end: Vector2 = start.move_toward(inward, span)
	end.x = clampf(end.x, -hw * 0.96, hw * 0.96)
	end.y = clampf(end.y, -hh * 0.96, hh * 0.96)
	return [start, end]


func _jagged_stress_path(p0: Vector2, p1: Vector2, rng: RandomNumberGenerator, subdivisions: int) -> PackedVector2Array:
	var pts := PackedVector2Array([p0, p1])
	for _s in range(subdivisions):
		var next := PackedVector2Array()
		next.append(pts[0])
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var mid: Vector2 = (a + b) * 0.5
			var seg: Vector2 = b - a
			var seg_len: float = seg.length()
			if seg_len < 0.5:
				next.append(b)
				continue
			var perp: Vector2 = seg.orthogonal().normalized()
			var disp_scale: float = minf(seg_len * 0.38, 22.0)
			var disp: float = rng.randf_range(-disp_scale, disp_scale)
			if rng.randf() < 0.22:
				disp *= 1.65
			mid += perp * disp
			next.append(mid)
			next.append(b)
		pts = next
	return pts


func _stress_width_curve(rng: RandomNumberGenerator) -> Curve:
	var c := Curve.new()
	var tip0: float = rng.randf_range(0.12, 0.28)
	var tip1: float = rng.randf_range(0.1, 0.26)
	# Godot 4.3+: Curve.add_point(position: Vector2, left_tangent, right_tangent, ...) — x = offset along line, y = value
	c.add_point(Vector2(0.0, tip0), 0.0, 0.0)
	c.add_point(Vector2(0.45 + rng.randf_range(-0.08, 0.08), rng.randf_range(0.85, 1.05)), 0.0, 0.0)
	c.add_point(Vector2(1.0, tip1), 0.0, 0.0)
	return c


func _normals_for_polyline(points: PackedVector2Array) -> PackedVector2Array:
	var n: int = points.size()
	var out := PackedVector2Array()
	out.resize(n)
	for i in range(n):
		var t: Vector2
		if i == 0:
			t = (points[1] - points[0]).normalized()
		elif i == n - 1:
			t = (points[n - 1] - points[n - 2]).normalized()
		else:
			t = (points[i + 1] - points[i - 1]).normalized()
		if t.length_squared() < 0.0001:
			t = Vector2.RIGHT
		out[i] = t.orthogonal().normalized()
	return out


func _offset_polyline(points: PackedVector2Array, normals: PackedVector2Array, dist: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in range(points.size()):
		out[i] = points[i] + normals[i] * dist
	return out


func _add_layered_metal_crack_lines(parent: Node2D, points: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	if points.size() < 2:
		return
	var normals := _normals_for_polyline(points)
	var light_side: float = 1.0 if rng.randf() > 0.5 else -1.0
	var n_scaled := PackedVector2Array()
	for i in range(normals.size()):
		n_scaled.append(normals[i] * light_side)
	var rust_off: float = rng.randf_range(-1.4, -0.5)
	var rust_pts := _offset_polyline(points, n_scaled, rust_off)
	var rust := Line2D.new()
	rust.points = rust_pts
	rust.width = rng.randf_range(3.8, 6.2)
	rust.default_color = Color(0.38, 0.22, 0.12, rng.randf_range(0.22, 0.38))
	rust.joint_mode = Line2D.LINE_JOINT_SHARP
	rust.begin_cap_mode = Line2D.LINE_CAP_BOX
	rust.end_cap_mode = Line2D.LINE_CAP_BOX
	rust.antialiased = true
	rust.width_curve = _stress_width_curve(rng)
	parent.add_child(rust)
	var groove := Line2D.new()
	groove.points = points
	groove.width = rng.randf_range(3.0, 4.8)
	groove.default_color = Color(0.04, 0.038, 0.042, rng.randf_range(0.72, 0.9))
	groove.joint_mode = Line2D.LINE_JOINT_SHARP
	groove.begin_cap_mode = Line2D.LINE_CAP_BOX
	groove.end_cap_mode = Line2D.LINE_CAP_BOX
	groove.antialiased = true
	groove.width_curve = _stress_width_curve(rng)
	parent.add_child(groove)
	var hi_off: float = rng.randf_range(0.55, 1.15)
	var hi_pts := _offset_polyline(points, n_scaled, hi_off)
	var highlight := Line2D.new()
	highlight.points = hi_pts
	highlight.width = rng.randf_range(0.65, 1.25)
	highlight.default_color = Color(0.72, 0.7, 0.66, rng.randf_range(0.35, 0.55))
	highlight.joint_mode = Line2D.LINE_JOINT_SHARP
	highlight.begin_cap_mode = Line2D.LINE_CAP_ROUND
	highlight.end_cap_mode = Line2D.LINE_CAP_ROUND
	highlight.antialiased = true
	var hc := Curve.new()
	hc.add_point(Vector2(0.0, 0.35), 0.0, 0.0)
	hc.add_point(Vector2(0.5, 1.0), 0.0, 0.0)
	hc.add_point(Vector2(1.0, 0.3), 0.0, 0.0)
	highlight.width_curve = hc
	parent.add_child(highlight)


func _break_from_kicks(direction: Vector2) -> void:
	if _broken:
		return
	_broken = true
	remove_from_group("kickable_objects")
	var kick_dir := direction.normalized() if direction.length() > 0.001 else Vector2(1.0, 0.0)
	_shatter_cage(kick_dir)
	var pl := get_tree().get_first_node_in_group("player")
	if pl and pl.has_method("extend_dash_duration"):
		pl.extend_dash_duration()
	if fracture_sfx:
		_play_break_one_shot(fracture_sfx, randf_range(0.9, 1.1))
	_apply_door_style_cage_break_vfx(direction)
	queue_free()


func _play_break_one_shot(stream: AudioStream, pitch: float = 1.0) -> void:
	"""Play break audio on a temporary player that survives cage queue_free()."""
	if stream == null:
		return
	var host := get_parent()
	if host == null:
		# Fallback if no parent: try local player.
		if sfx_player:
			sfx_player.stream = stream
			sfx_player.volume_db = fracture_volume_boost_db
			sfx_player.pitch_scale = pitch
			sfx_player.play()
		return
	var one_shot := AudioStreamPlayer.new()
	if AudioServer.get_bus_index("Game") != -1:
		one_shot.bus = "Game"
	else:
		one_shot.bus = "Master"
	one_shot.stream = stream
	one_shot.volume_db = fracture_volume_boost_db
	one_shot.pitch_scale = pitch
	host.add_child(one_shot)
	one_shot.play()
	one_shot.finished.connect(func():
		if is_instance_valid(one_shot):
			one_shot.queue_free()
	)


func _shatter_cage(kick_direction: Vector2) -> void:
	var half_size := Vector2(cage_width, cage_height) / 2.0
	var inner_half := half_size - Vector2(wall_thickness, wall_thickness)
	var fragment_script: Script = load("res://kickable_fragment.gd")

	var seed_points: Array[Vector2] = []
	var min_distance: float = min(inner_half.x * 2.0, inner_half.y * 2.0) / sqrt(float(fragment_count)) * 0.6

	for _attempt in range(fragment_count * 3):
		if seed_points.size() >= fragment_count:
			break
		var attempts := 0
		var valid_point := false
		var new_point: Vector2
		while attempts < 50 and not valid_point:
			new_point = Vector2(
				randf_range(-inner_half.x, inner_half.x),
				randf_range(-inner_half.y, inner_half.y)
			)
			valid_point = true
			for existing_point in seed_points:
				if new_point.distance_to(existing_point) < min_distance:
					valid_point = false
					break
			attempts += 1
		if valid_point:
			seed_points.append(new_point)

	while seed_points.size() < fragment_count:
		seed_points.append(Vector2(
			randf_range(-inner_half.x, inner_half.x),
			randf_range(-inner_half.y, inner_half.y)
		))

	for seed_idx in range(mini(seed_points.size(), fragment_count)):
		var seed_point: Vector2 = seed_points[seed_idx]
		var fragment_points := _cage_fragment_polygon(seed_point, seed_points, inner_half)
		if fragment_points.size() < 3:
			continue
		var fragment_center := Vector2.ZERO
		for point in fragment_points:
			fragment_center += point
		fragment_center /= fragment_points.size()
		var radial_dir := fragment_center.normalized() if fragment_center.length() > 0.0 else Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		var shatter_dir := (kick_direction.normalized() * 0.85 + radial_dir * 0.15).normalized()
		var shatter_vel := shatter_dir * randf_range(
			shatter_force - shatter_force_variation,
			shatter_force + shatter_force_variation
		)
		shatter_vel = shatter_vel.rotated(randf_range(-0.15, 0.15))
		var fragment_color := cage_fragment_color
		fragment_color.r = clampf(fragment_color.r + randf_range(-0.08, 0.08), 0.0, 1.0)
		fragment_color.g = clampf(fragment_color.g + randf_range(-0.08, 0.08), 0.0, 1.0)
		fragment_color.b = clampf(fragment_color.b + randf_range(-0.05, 0.1), 0.0, 1.0)
		fragment_color.a = clampf(fragment_color.a + randf_range(-0.08, 0.08), 0.35, 0.98)
		var fragment = fragment_script.new()
		get_parent().add_child(fragment)
		fragment.life_time = fragment_lifetime
		fragment.setup(
			fragment_points,
			global_position + fragment_center,
			rotation + randf_range(-0.2, 0.2),
			shatter_vel,
			fragment_color,
			2000.0
		)

	if back_sprite:
		back_sprite.visible = false
	if front_sprite:
		front_sprite.visible = false
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	collision_layer = 0


func _cage_fragment_polygon(seed_point: Vector2, all_seeds: Array[Vector2], inner_half: Vector2) -> PackedVector2Array:
	var nearby_seeds: Array[Vector2] = []
	var max_check_distance: float = min(inner_half.x, inner_half.y) * 1.5
	for other_seed in all_seeds:
		if other_seed == seed_point:
			continue
		if seed_point.distance_to(other_seed) < max_check_distance:
			nearby_seeds.append(other_seed)
	if nearby_seeds.is_empty():
		return _cage_simple_polygon(seed_point, inner_half)
	var sample_count := 24
	var boundary_points: Array[Vector2] = []
	var two_pi := PI * 2.0
	for i in range(sample_count):
		var angle := (two_pi * float(i)) / float(sample_count)
		var direction := Vector2(cos(angle), sin(angle))
		var step_size: float = min(inner_half.x, inner_half.y) / 30.0
		var last_point_in_territory: Vector2 = seed_point
		var found_boundary := false
		for step in range(30):
			var test_point: Vector2 = seed_point + direction * (float(step) * step_size)
			if absf(test_point.x) > inner_half.x or absf(test_point.y) > inner_half.y:
				boundary_points.append(test_point)
				found_boundary = true
				break
			var dist_to_seed: float = test_point.distance_to(seed_point)
			for other_seed in nearby_seeds:
				if test_point.distance_to(other_seed) < dist_to_seed:
					boundary_points.append(last_point_in_territory)
					found_boundary = true
					break
			if found_boundary:
				break
			last_point_in_territory = test_point
		if not found_boundary:
			boundary_points.append(last_point_in_territory)
	var cleaned_points: Array[Vector2] = []
	var min_point_distance: float = min(inner_half.x, inner_half.y) * 0.05
	for point in boundary_points:
		var is_duplicate := false
		for existing in cleaned_points:
			if point.distance_to(existing) < min_point_distance:
				is_duplicate = true
				break
		if not is_duplicate:
			cleaned_points.append(point)
	if cleaned_points.size() < 3:
		return _cage_simple_polygon(seed_point, inner_half)
	cleaned_points.sort_custom(func(a, b): return (a - seed_point).angle() < (b - seed_point).angle())
	var polygon_points := PackedVector2Array()
	polygon_points.append(seed_point)
	for point in cleaned_points:
		polygon_points.append(point)
	if polygon_points.size() > 2:
		polygon_points.append(polygon_points[0])
	return polygon_points


func _cage_simple_polygon(center: Vector2, inner_half: Vector2) -> PackedVector2Array:
	var vertex_count := randi_range(3, 7)
	var base_radius := randf_range(min(inner_half.x, inner_half.y) * 0.15, min(inner_half.x, inner_half.y) * 0.35)
	var two_pi := PI * 2.0
	var points := PackedVector2Array()
	points.append(center)
	var angles: Array[float] = []
	for i in range(vertex_count):
		angles.append((two_pi * float(i)) / float(vertex_count) + randf_range(-0.4, 0.4))
	angles.sort()
	for angle in angles:
		var distance := base_radius * randf_range(0.6, 1.4)
		points.append(center + Vector2(cos(angle), sin(angle)) * distance)
	if points.size() > 2:
		points.append(points[0])
	return points


func _spawn_cage_break_impact_particles(kick_dir: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = break_particle_amount
	particles.lifetime = 0.48
	var dir := kick_dir.normalized() if kick_dir.length_squared() > 0.0001 else Vector2(1.0, 0.0)
	particles.direction = dir
	particles.spread = 58.0
	particles.initial_velocity_min = 260.0
	particles.initial_velocity_max = 560.0
	particles.gravity = Vector2(0, 800)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = Color(1.0, 0.95, 0.72)
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(1.0, 1.0, 0.82, 1.0))
	color_ramp.set_color(1, Color(1.0, 0.62, 0.22, 0.0))
	particles.color_ramp = color_ramp
	particles.global_position = global_position
	get_parent().add_child(particles)
	get_tree().create_timer(particles.lifetime + 0.12, true, false, true).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


func _apply_door_style_cage_break_vfx(kick_direction: Vector2) -> void:
	_spawn_cage_break_impact_particles(kick_direction)
	var pl := get_tree().get_first_node_in_group("player")
	if pl:
		if pl.has_method("apply_camera_shake"):
			pl.apply_camera_shake(break_camera_shake, break_camera_shake_duration)
		if pl.has_method("apply_hitstop"):
			pl.apply_hitstop(break_hitstop_seconds)


func _physics_process(delta: float) -> void:
	if _broken:
		return
	if _fading:
		_process_fade(delta)
		return
	_apply_gravity(delta)
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return
	_check_player_escape()
	var push_dir := _get_push_direction()
	if push_dir == 0:
		return
	var desired := push_speed * delta
	var actual := _get_max_move_distance(push_dir, desired)
	if actual > 0.001:
		global_position.x += push_dir * actual


func _apply_gravity(delta: float) -> void:
	var half_h := cage_height / 2.0
	var bottom_y := global_position.y + half_h
	var space_state := get_world_2d().direct_space_state
	var ground_check := PhysicsRayQueryParameters2D.create(
		Vector2(global_position.x, bottom_y - 4.0),
		Vector2(global_position.x, bottom_y + 2.0))
	ground_check.collision_mask = 1
	if space_state.intersect_ray(ground_check):
		_fall_velocity = 0.0
		return
	_fall_velocity += fall_speed * delta
	var fall_dist := _fall_velocity * delta
	var from := Vector2(global_position.x, bottom_y)
	var to := from + Vector2(0, fall_dist + 2.0)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1
	var result := space_state.intersect_ray(query)
	if result:
		global_position.y = result.position.y - half_h
		_fall_velocity = 0.0
	else:
		global_position.y += fall_dist


func _get_push_direction() -> int:
	for i in range(player.get_slide_collision_count()):
		var collision := player.get_slide_collision(i)
		if not collision:
			continue
		if collision.get_collider() == self:
			var normal := collision.get_normal()
			if absf(normal.x) > 0.7:
				return -int(sign(normal.x))
	return 0


func _get_max_move_distance(dir: int, desired: float) -> float:
	var half_w := cage_width / 2.0
	var half_h := cage_height / 2.0
	var wt := wall_thickness
	var leading_x := global_position.x + dir * half_w
	var space_state := get_world_2d().direct_space_state
	var min_dist := desired
	for offset_y in [-half_h + wt, 0.0, half_h - wt]:
		var origin := Vector2(leading_x, global_position.y + offset_y)
		var end := origin + Vector2(dir * (desired + 2.0), 0)
		var query := PhysicsRayQueryParameters2D.create(origin, end)
		query.collision_mask = 1
		var result := space_state.intersect_ray(query)
		if result:
			var hit_dist := absf(result.position.x - origin.x)
			min_dist = minf(min_dist, maxf(hit_dist - 1.0, 0.0))
	return min_dist


func _check_player_escape() -> void:
	if not player or not is_instance_valid(player):
		return
	var inside := _is_inside_cage(player.global_position)
	if _player_was_inside and not inside:
		_start_fade()
	_player_was_inside = inside


func _is_inside_cage(pos: Vector2) -> bool:
	var cp := global_position
	var hw := cage_width / 2.0
	var hh := cage_height / 2.0
	return pos.x > cp.x - hw and pos.x < cp.x + hw and pos.y > cp.y - hh and pos.y < cp.y + hh


func _start_fade() -> void:
	_fading = true
	_fade_timer = 0.0


func _process_fade(delta: float) -> void:
	_fade_timer += delta
	var fade_start := linger_time - fade_duration
	if _fade_timer >= fade_start:
		var t := clampf((_fade_timer - fade_start) / fade_duration, 0.0, 1.0)
		modulate.a = 1.0 - t
	if _fade_timer >= linger_time:
		collision_layer = 0
		for child in get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
		queue_free()


func _setup_sprites() -> void:
	if back_sprite and back_sprite.texture:
		var tex_size := back_sprite.texture.get_size()
		back_sprite.scale = Vector2(cage_width / tex_size.x, cage_height / tex_size.y)
	if front_sprite and front_sprite.texture:
		var tex_size := front_sprite.texture.get_size()
		front_sprite.scale = Vector2(cage_width / tex_size.x, cage_height / tex_size.y)
