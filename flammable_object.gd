extends Area2D

enum BurnState { IDLE, BEGINNING, BRIGHT, DYING }

@export_group("Object Properties")
@export var object_size: Vector2 = Vector2(40, 40)
@export var object_color: Color = Color(0.55, 0.35, 0.18, 1.0)
@export var kickable: bool = true

@export_group("Kick Properties")
@export var kick_speed: float = 2000.0
@export var rotation_speed_min: float = -10.0
@export var rotation_speed_max: float = 10.0

@export_group("Collision Response")
@export var fragment_count: int = 8
@export var fragment_lifetime: float = 1.0
@export var bounce_damping: float = 0.4
@export var gravity_strength: float = 2000.0

@export_group("Burn Timing")
@export var burn_time_begin: float = 0.8
@export var burn_time_bright: float = 2.5
@export var burn_time_dying: float = 1.5
@export var ignition_radius: float = 120.0

var burn_state: BurnState = BurnState.IDLE
var burn_timer: float = 0.0
var fire_shader_material: ShaderMaterial = null
var burn_light: PointLight2D = null

var is_kicked: bool = false
var kick_velocity: Vector2 = Vector2.ZERO
var rotation_speed: float = 0.0
var has_collided: bool = false
var raycast: RayCast2D = null

var speed_lines: Array[Line2D] = []
var afterimage_timer: float = 0.0
const AFTERIMAGE_INTERVAL: float = 0.015
const SPEED_LINE_COUNT: int = 4
const SPEED_LINE_LENGTH: float = 80.0

var _fire_check_counter: int = 0
var ambient_light: PointLight2D = null
var fire_sim_ref: Node2D = null
var fire_trail_timer: float = 0.0
var rng := RandomNumberGenerator.new()

@onready var visual: Polygon2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var blocking_body: StaticBody2D = $BlockingBody


func _ready() -> void:
	rng.randomize()
	collision_layer = 32
	collision_mask = 5

	if kickable:
		add_to_group("kickable_objects")
	add_to_group("flammable_objects")

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	raycast = RayCast2D.new()
	raycast.enabled = false
	raycast.collide_with_areas = true
	raycast.collide_with_bodies = true
	raycast.exclude_parent = true
	add_child(raycast)
	raycast.set_collision_mask_value(1, true)
	raycast.set_collision_mask_value(3, true)

	_update_visual()
	_setup_blocking_body()
	_create_ambient_light()
	call_deferred("_cache_fire_sim")


func _update_visual() -> void:
	if visual and visual.polygon.size() < 3:
		var half := object_size / 2.0
		visual.polygon = PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y)
		])

	if collision_shape:
		var rect := RectangleShape2D.new()
		rect.size = object_size
		collision_shape.shape = rect


func _setup_blocking_body() -> void:
	if not blocking_body:
		return
	blocking_body.collision_layer = 1
	blocking_body.collision_mask = 0
	var bc := blocking_body.get_node_or_null("CollisionShape2D")
	if bc:
		var rect := RectangleShape2D.new()
		rect.size = object_size
		bc.shape = rect


func _create_ambient_light() -> void:
	ambient_light = PointLight2D.new()
	ambient_light.color = Color(
		lerpf(object_color.r, 1.0, 0.3),
		lerpf(object_color.g, 1.0, 0.3),
		lerpf(object_color.b, 1.0, 0.3)
	)
	ambient_light.energy = 0.6
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var max_d := size * 0.48
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(center) / max_d
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	ambient_light.texture = ImageTexture.create_from_image(img)
	ambient_light.texture_scale = max(object_size.x, object_size.y) * 2.5 / 64.0
	add_child(ambient_light)


func _cache_fire_sim() -> void:
	fire_sim_ref = _find_fire_sim()


func _find_fire_sim() -> Node2D:
	var node = get_parent()
	while node:
		if node.has_method("ignite_at"):
			return node
		for child in node.get_children():
			if child == self:
				continue
			if child.has_method("ignite_at"):
				return child
		node = node.get_parent()
	var tree = get_tree()
	if tree:
		for n in tree.get_nodes_in_group("fire_simulation"):
			return n
	return null


func _physics_process(delta: float) -> void:
	_process_burn(delta)
	_process_ignition_check()

	if is_kicked and not has_collided:
		if burn_state != BurnState.IDLE:
			_spawn_fire_trail(delta)

		raycast.target_position = kick_velocity.normalized() * kick_velocity.length() * delta * 1.5
		raycast.force_raycast_update()
		if raycast.is_colliding():
			_handle_collision(raycast.get_collider())
		else:
			global_position += kick_velocity * delta
			rotation += rotation_speed * delta
			_update_speed_lines()
			_spawn_afterimage(delta)


func _process_burn(delta: float) -> void:
	if burn_state == BurnState.IDLE:
		return

	burn_timer += delta

	match burn_state:
		BurnState.BEGINNING:
			var progress := clampf(burn_timer / burn_time_begin, 0.0, 1.0)
			_set_shader_param("fire_intensity", lerpf(0.0, 0.4, progress))
			_set_shader_param("char_amount", lerpf(0.0, 0.15, progress))
			_update_burn_light(lerpf(0.0, 0.4, progress))
			if burn_timer >= burn_time_begin:
				burn_timer = 0.0
				burn_state = BurnState.BRIGHT

		BurnState.BRIGHT:
			var progress := clampf(burn_timer / burn_time_bright, 0.0, 1.0)
			_set_shader_param("fire_intensity", lerpf(0.4, 1.0, progress))
			_set_shader_param("char_amount", lerpf(0.15, 0.7, progress))
			_update_burn_light(lerpf(0.4, 1.0, progress))
			if burn_timer >= burn_time_bright:
				burn_timer = 0.0
				burn_state = BurnState.DYING

		BurnState.DYING:
			var progress := clampf(burn_timer / burn_time_dying, 0.0, 1.0)
			_set_shader_param("fire_intensity", lerpf(1.0, 0.0, progress))
			_set_shader_param("char_amount", lerpf(0.7, 1.0, progress))
			_update_burn_light(lerpf(1.0, 0.0, progress))
			var burn_sprite := get_node_or_null("BurnSprite")
			if burn_sprite:
				burn_sprite.modulate.a = lerpf(1.0, 0.0, progress)
			if burn_timer >= burn_time_dying:
				_on_burn_finished()


func _process_ignition_check() -> void:
	if burn_state == BurnState.IDLE:
		_check_should_ignite()
	elif burn_state != BurnState.IDLE:
		_spread_fire_to_nearby()


func _check_should_ignite() -> void:
	_fire_check_counter += 1
	if _fire_check_counter % 10 != 0:
		return

	var fire_sims := get_tree().get_nodes_in_group("fire_simulation")
	for sim in fire_sims:
		if not is_instance_valid(sim):
			continue
		var cs: int = sim.cell_size
		if cs <= 0:
			continue
		var cx := int(round(global_position.x / cs))
		var cy := int(round(global_position.y / cs))
		for offset_x in range(-3, 4):
			for offset_y in range(-3, 4):
				if sim.burning_set.has(Vector2i(cx + offset_x, cy + offset_y)):
					ignite()
					return

	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if not is_instance_valid(p):
			continue
		if p.get("is_on_fire") and global_position.distance_to(p.global_position) < ignition_radius:
			ignite()
			return

	var flammables := get_tree().get_nodes_in_group("flammable_objects")
	for f in flammables:
		if f == self or not is_instance_valid(f):
			continue
		if f.burn_state != BurnState.IDLE and global_position.distance_to(f.global_position) < ignition_radius * 1.5:
			ignite()
			return

	var overlapping := get_overlapping_areas()
	for area in overlapping:
		if not is_instance_valid(area):
			continue
		if area.is_in_group("flammable_objects") and area != self:
			if area.get("burn_state") != null and area.burn_state != BurnState.IDLE:
				ignite()
				return


func _spread_fire_to_nearby() -> void:
	_fire_check_counter += 1
	if _fire_check_counter % 10 != 0:
		return

	var flammables := get_tree().get_nodes_in_group("flammable_objects")
	for f in flammables:
		if f == self or not is_instance_valid(f):
			continue
		if f.get("burn_state") != null and f.burn_state == BurnState.IDLE:
			if global_position.distance_to(f.global_position) < ignition_radius * 1.2:
				f.ignite()

	var overlapping := get_overlapping_areas()
	for area in overlapping:
		if not is_instance_valid(area) or area == self:
			continue
		if area.is_in_group("flammable_objects"):
			if area.get("burn_state") != null and area.burn_state == BurnState.IDLE:
				area.ignite()

	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if not is_instance_valid(p):
			continue
		if not p.get("is_on_fire") and global_position.distance_to(p.global_position) < ignition_radius:
			if p.has_method("set_on_fire"):
				p.set_on_fire()


func ignite() -> void:
	if burn_state != BurnState.IDLE:
		return

	burn_state = BurnState.BEGINNING
	burn_timer = 0.0

	var shader := load("res://shaders/flammable_burn.gdshader")
	fire_shader_material = ShaderMaterial.new()
	fire_shader_material.shader = shader
	fire_shader_material.set_shader_parameter("fire_intensity", 0.0)
	fire_shader_material.set_shader_parameter("char_amount", 0.0)

	if visual:
		# Create an Image texture from the Polygon2D so the shader has TEXTURE to sample
		_apply_shader_texture()
		visual.material = fire_shader_material

	_create_burn_light()


func _apply_shader_texture() -> void:
	if not visual:
		return
	# Create a texture LARGER than the object with transparent margins.
	# The shader needs transparent pixels outside the object to render fire flames,
	# and alpha transitions at the edges to detect the rim.
	var margin := int(max(object_size.x, object_size.y) * 0.6)
	var half := object_size / 2.0
	var tex_w := int(object_size.x) + margin * 2
	var tex_h := int(object_size.y) + margin * 2
	var img := Image.create(maxi(tex_w, 4), maxi(tex_h, 4), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Rasterize the actual polygon shape into the texture
	var poly := visual.polygon
	if poly.size() >= 3:
		for y in img.get_height():
			for x in img.get_width():
				# Map pixel to local coords (polygon space)
				var lx := float(x) - float(margin) - half.x
				var ly := float(y) - float(margin) - half.y
				if _point_in_polygon(Vector2(lx, ly), poly):
					img.set_pixel(x, y, object_color)
	else:
		# Fallback: fill rectangle
		for y in range(margin, margin + int(object_size.y)):
			for x in range(margin, margin + int(object_size.x)):
				if x < img.get_width() and y < img.get_height():
					img.set_pixel(x, y, object_color)

	var tex := ImageTexture.create_from_image(img)

	var sprite := Sprite2D.new()
	sprite.name = "BurnSprite"
	sprite.texture = tex
	sprite.material = fire_shader_material
	sprite.z_index = visual.z_index
	add_child(sprite)

	visual.visible = false


func _point_in_polygon(point: Vector2, poly: PackedVector2Array) -> bool:
	var inside := false
	var n := poly.size()
	var j := n - 1
	for i in n:
		var pi := poly[i]
		var pj := poly[j]
		if ((pi.y > point.y) != (pj.y > point.y)) and \
			(point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	return inside


func _create_burn_light() -> void:
	burn_light = PointLight2D.new()
	burn_light.energy = 0.0
	burn_light.color = Color(1.0, 0.6, 0.2)

	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var max_d := size * 0.48
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(center) / max_d
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	burn_light.texture = ImageTexture.create_from_image(img)
	burn_light.texture_scale = max(object_size.x, object_size.y) * 4.0 / 64.0

	add_child(burn_light)


func _update_burn_light(intensity: float) -> void:
	if burn_light:
		burn_light.energy = intensity * 2.0
		var flicker := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.02)
		burn_light.energy *= flicker
	if ambient_light:
		ambient_light.energy = lerpf(0.6, 0.0, clampf(intensity / 0.4, 0.0, 1.0))


func _set_shader_param(param: String, value: float) -> void:
	if fire_shader_material:
		fire_shader_material.set_shader_parameter(param, value)


func _on_burn_finished() -> void:
	if blocking_body:
		blocking_body.collision_layer = 0
		var bc := blocking_body.get_node_or_null("CollisionShape2D")
		if bc:
			bc.set_deferred("disabled", true)
	if ambient_light:
		ambient_light.queue_free()
		ambient_light = null

	_spawn_ash_particles()
	queue_free()


func _spawn_ash_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = 16
	particles.lifetime = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 90.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 80.0
	particles.gravity = Vector2(0, 40)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 3.0
	particles.color = Color(0.2, 0.15, 0.1, 0.8)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.3, 0.2, 0.1, 0.8))
	ramp.set_color(1, Color(0.1, 0.08, 0.05, 0.0))
	particles.color_ramp = ramp
	particles.global_position = global_position
	get_parent().add_child(particles)
	get_tree().create_timer(1.5, true, false, true).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


# ---- KICK MECHANICS (mirrors kickable_object.gd) ----

func kick(direction: Vector2, speed: float = 0.0) -> void:
	if is_kicked or not kickable:
		return

	is_kicked = true
	var final_speed := speed if speed > 0 else kick_speed
	kick_velocity = direction.normalized() * final_speed
	rotation_speed = randf_range(rotation_speed_min, rotation_speed_max)
	raycast.enabled = true
	set_collision_mask_value(2, false)
	modulate = Color(1.5, 0.5, 0.5)

	if blocking_body:
		blocking_body.set_deferred("collision_layer", 0)
		var bc := blocking_body.get_node_or_null("CollisionShape2D")
		if bc:
			bc.set_deferred("disabled", true)

	if burn_state != BurnState.IDLE:
		_ignite_fire_at_position(global_position, 4)
		_spawn_fire_kick_burst()

	_create_speed_lines()


func can_be_kicked() -> bool:
	return kickable and not is_kicked


func _handle_collision(collider: Node) -> void:
	if has_collided:
		return

	if collider and (collider.is_in_group("enemies") or collider.is_in_group("enemy")):
		_collide_with_enemy(collider)
	else:
		_collide_with_wall()


func _collide_with_enemy(enemy: Node) -> void:
	_apply_impact_vfx(true)
	if burn_state != BurnState.IDLE:
		_ignite_fire_at_position(global_position, 6)
		_spawn_fire_collision_burst()
	if enemy.has_method("become_physics_object"):
		enemy.become_physics_object(kick_velocity.normalized(), kick_velocity.length())
	elif enemy.has_method("kick"):
		enemy.kick(kick_velocity.normalized(), kick_velocity.length())
	_explode()


func _collide_with_wall() -> void:
	_apply_impact_vfx(false)
	if burn_state != BurnState.IDLE:
		_ignite_fire_at_position(global_position, 6)
		_spawn_fire_collision_burst()
	_explode()


func _explode() -> void:
	if has_collided:
		return
	has_collided = true

	var half_size := object_size / 2.0
	var fragment_script = load("res://kickable_fragment.gd")
	var center := Vector2.ZERO

	var corners := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	]

	var perimeter_points := []
	var extra_points_total: int = maxi(0, fragment_count - 4)
	var points_per_side: int = extra_points_total / 4
	var remainder: int = extra_points_total % 4

	for i in range(4):
		var start_corner: Vector2 = corners[i]
		var end_corner: Vector2 = corners[(i + 1) % 4]
		perimeter_points.append(start_corner)
		var points_on_this_side: int = points_per_side + (1 if i < remainder else 0)
		for j in range(1, points_on_this_side + 1):
			var t: float = float(j) / (points_on_this_side + 1)
			perimeter_points.append(start_corner.lerp(end_corner, t))

	var final_color := object_color * modulate
	if burn_state != BurnState.IDLE:
		final_color = Color(0.15, 0.1, 0.05) * modulate

	for i in range(perimeter_points.size()):
		var p1: Vector2 = perimeter_points[i]
		var p2: Vector2 = perimeter_points[(i + 1) % perimeter_points.size()]
		var fragment_points := PackedVector2Array([center, p1, p2])
		var edge_midpoint := (p1 + p2) / 2.0
		var explode_dir := edge_midpoint.normalized()
		var explode_vel := explode_dir * randf_range(300.0, 700.0)
		var start_vel := (kick_velocity * 0.4) + explode_vel

		var fragment = fragment_script.new()
		get_parent().add_child(fragment)
		fragment.life_time = fragment_lifetime
		fragment.setup(fragment_points, global_position, rotation, start_vel, final_color, gravity_strength)

	queue_free()


# ---- Fire spread helpers ----

func _ignite_fire_at_position(pos: Vector2, radius: int) -> void:
	if not fire_sim_ref:
		fire_sim_ref = _find_fire_sim()
	if fire_sim_ref and fire_sim_ref.has_method("ignite_at"):
		fire_sim_ref.ignite_at(pos, radius)


func _spawn_fire_kick_burst() -> void:
	if not fire_sim_ref:
		fire_sim_ref = _find_fire_sim()
	if not fire_sim_ref:
		return
	for i in range(30):
		var angle := rng.randf_range(-PI, PI)
		var spd := rng.randf_range(40, 180)
		var vel := Vector2(cos(angle) * spd, sin(angle) * spd - rng.randf_range(60, 150))
		vel += kick_velocity.normalized() * rng.randf_range(20, 80)
		var particle := {
			"pos": global_position + Vector2(rng.randf_range(-16, 16), rng.randf_range(-16, 16)),
			"vel": vel,
			"life": 1.0,
			"max_life": 1.0,
			"heat": rng.randf_range(0.6, 1.0),
			"size": rng.randf_range(16.0, 32.0),
		}
		fire_sim_ref.particles.append(particle)


func _spawn_fire_collision_burst() -> void:
	if not fire_sim_ref:
		fire_sim_ref = _find_fire_sim()
	if not fire_sim_ref:
		return
	for i in range(50):
		var angle := rng.randf_range(-PI, PI)
		var spd := rng.randf_range(60, 300)
		var vel := Vector2(cos(angle) * spd, sin(angle) * spd - rng.randf_range(80, 250))
		vel += kick_velocity * 0.15
		var particle := {
			"pos": global_position + Vector2(rng.randf_range(-24, 24), rng.randf_range(-24, 24)),
			"vel": vel,
			"life": 1.0,
			"max_life": 1.0,
			"heat": rng.randf_range(0.6, 1.0),
			"size": rng.randf_range(16.0, 36.0),
		}
		fire_sim_ref.particles.append(particle)


func _spawn_fire_trail(delta: float) -> void:
	fire_trail_timer += delta
	if fire_trail_timer < 0.03:
		return
	fire_trail_timer = 0.0
	if not fire_sim_ref:
		fire_sim_ref = _find_fire_sim()
	if not fire_sim_ref:
		return
	_ignite_fire_at_position(global_position, 2)
	var particle := {
		"pos": global_position + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4)),
		"vel": Vector2(rng.randf_range(-20, 20), rng.randf_range(-80, -30)),
		"life": rng.randf_range(0.2, 0.6),
		"max_life": 0.6,
		"heat": rng.randf_range(0.5, 0.9),
		"size": rng.randf_range(5.0, 12.0),
	}
	fire_sim_ref.particles.append(particle)


# ---- VFX helpers ----

func _create_speed_lines() -> void:
	for i in SPEED_LINE_COUNT:
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color(1.0, 1.0, 1.0, 0.6)
		line.z_index = -1
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.set_color(1, Color(1, 1, 1, 0.7))
		line.gradient = g
		get_parent().add_child(line)
		speed_lines.append(line)


func _update_speed_lines() -> void:
	var back_dir := -kick_velocity.normalized()
	for i in speed_lines.size():
		var line := speed_lines[i]
		if not is_instance_valid(line):
			continue
		var spread := Vector2(back_dir.y, -back_dir.x) * randf_range(-12.0, 12.0)
		var origin := global_position + spread
		line.clear_points()
		line.add_point(origin)
		line.add_point(origin + back_dir * SPEED_LINE_LENGTH * randf_range(0.6, 1.0))


func _remove_speed_lines() -> void:
	for line in speed_lines:
		if is_instance_valid(line):
			line.queue_free()
	speed_lines.clear()


func _spawn_afterimage(delta: float) -> void:
	afterimage_timer += delta
	if afterimage_timer < AFTERIMAGE_INTERVAL:
		return
	afterimage_timer = 0.0
	if not visual or not visual.visible:
		return
	var ghost := Polygon2D.new()
	ghost.polygon = visual.polygon
	ghost.color = visual.color
	ghost.global_position = global_position
	ghost.rotation = rotation
	ghost.modulate = Color(modulate.r, modulate.g, modulate.b, 0.7)
	ghost.z_index = z_index - 1
	var vel_dir := kick_velocity.normalized()
	ghost.scale = Vector2(1.0 + abs(vel_dir.x) * 0.3, 1.0 + abs(vel_dir.y) * 0.3)
	get_parent().add_child(ghost)
	var tw := get_tree().create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tw.tween_callback(ghost.queue_free)


func _spawn_impact_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 20
	particles.lifetime = 0.4
	particles.direction = -kick_velocity.normalized()
	particles.spread = 60.0
	particles.initial_velocity_min = 200.0
	particles.initial_velocity_max = 500.0
	particles.gravity = Vector2(0, 800)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.8, 0.6, 0.3)
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(0.9, 0.7, 0.4, 1.0))
	color_ramp.set_color(1, Color(0.5, 0.3, 0.1, 0.0))
	particles.color_ramp = color_ramp
	particles.global_position = global_position
	get_parent().add_child(particles)
	get_tree().create_timer(particles.lifetime + 0.1, true, false, true).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


func _apply_impact_vfx(is_enemy_hit: bool) -> void:
	_remove_speed_lines()
	_spawn_impact_particles()
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("apply_camera_shake"):
			player.apply_camera_shake(20.0 if is_enemy_hit else 15.0, 0.15)
		if player.has_method("apply_hitstop"):
			player.apply_hitstop(0.05 if is_enemy_hit else 0.03)


func _on_body_entered(body: Node2D) -> void:
	if is_kicked and not has_collided:
		if body.is_in_group("player"):
			return
		_handle_collision(body)


func _on_area_entered(area: Area2D) -> void:
	if is_kicked and not has_collided:
		_handle_collision(area)
