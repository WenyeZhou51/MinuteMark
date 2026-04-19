extends Area2D

## Kickable fire bottle (Molotov). Sits idle until kicked.
## When kicked: immediately ignites fire at its position AND flies off.
## On collision it shatters, sprays more fire particles, and ignites again.

@export_group("Kick")
@export var kick_speed: float = 1800.0
@export var rotation_speed_min: float = -12.0
@export var rotation_speed_max: float = 12.0

@export_group("Fire")
@export var kick_particle_burst: int = 40  ## Particles spawned on kick
@export var collision_particle_burst: int = 60  ## Particles spawned on collision
@export var fire_spread_radius: int = 8  ## How many cells to ignite
@export var idle_flame_particles: int = 3  ## Small flame particles while idle (wick)

@export_group("Collision")
@export var object_size: Vector2 = Vector2(40, 64)
@export var gravity_strength: float = 1800.0

@export_group("Indicator")
@export var indicator_bob_speed: float = 3.0
@export var indicator_bob_height: float = 6.0
@export var indicator_color: Color = Color(1.0, 0.7, 0.2, 0.9)

var is_kicked: bool = false
var kick_velocity: Vector2 = Vector2.ZERO
var rotation_speed: float = 0.0
var has_collided: bool = false
var raycast: RayCast2D = null
var rng := RandomNumberGenerator.new()
var fire_sim_ref: Node2D = null  # Cached reference

# Trail while flying
var trail_timer: float = 0.0

# Wick particles (small idle flame on top)
var wick_particles: Array[Dictionary] = []

# Kick indicator
var player_nearby: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Node2D = $Visual


func _ready() -> void:
	rng.randomize()
	collision_layer = 32  # kickable objects layer
	collision_mask = 5    # walls (1) + enemies (3)
	add_to_group("kickable_objects")
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

	# Cache fire sim reference
	call_deferred("_cache_fire_sim")


func _cache_fire_sim() -> void:
	fire_sim_ref = _find_fire_sim()
	if fire_sim_ref:
		print("[FIREBOTTLE] Found fire sim: ", fire_sim_ref.name)
	else:
		print("[FIREBOTTLE] WARNING: No PixelFireSimulation found!")


func _physics_process(delta: float) -> void:
	# Check if player is nearby (for kick indicator)
	if not is_kicked:
		_check_player_nearby()

	if not is_kicked or has_collided:
		_update_wick(delta)
		queue_redraw()
		return

	# Apply gravity while flying
	kick_velocity.y += gravity_strength * delta

	# Spawn trailing fire particles while flying
	trail_timer += delta
	if trail_timer >= 0.03 and fire_sim_ref:
		trail_timer = 0.0
		_spawn_trail_particle(fire_sim_ref)

	# Raycast ahead
	raycast.target_position = kick_velocity.normalized() * kick_velocity.length() * delta * 1.5
	raycast.force_raycast_update()

	if raycast.is_colliding():
		_handle_collision(raycast.get_collider())
	else:
		global_position += kick_velocity * delta
		rotation += rotation_speed * delta

	_update_wick(delta)
	queue_redraw()


func kick(direction: Vector2, speed: float = 0.0) -> void:
	if is_kicked:
		return
	is_kicked = true
	var final_speed = speed if speed > 0 else kick_speed
	kick_velocity = direction.normalized() * final_speed
	rotation_speed = randf_range(rotation_speed_min, rotation_speed_max)
	raycast.enabled = true
	set_collision_mask_value(2, false)

	# ===== IMMEDIATELY START FIRE WHEN KICKED =====
	if not fire_sim_ref:
		fire_sim_ref = _find_fire_sim()

	if fire_sim_ref:
		# Ignite the ground at the bottle's current position
		fire_sim_ref.ignite_at(global_position, fire_spread_radius / 2)

		# Spawn a burst of fire particles at kick point
		_spawn_kick_burst(fire_sim_ref)

		print("[FIREBOTTLE] Kicked! Fire started at ", global_position)
	else:
		print("[FIREBOTTLE] Kicked but no fire sim found!")


func can_be_kicked() -> bool:
	return not is_kicked


func _handle_collision(collider: Node) -> void:
	if has_collided:
		return
	has_collided = true
	raycast.enabled = false

	# Check if collider is enemy
	if collider and (collider.is_in_group("enemies") or collider.is_in_group("enemy")):
		if collider.has_method("become_physics_object"):
			collider.become_physics_object(kick_velocity.normalized(), kick_velocity.length())
		elif collider.has_method("kick"):
			collider.kick(kick_velocity.normalized(), kick_velocity.length())

	_shatter_and_ignite()


func _shatter_and_ignite() -> void:
	if not fire_sim_ref:
		fire_sim_ref = _find_fire_sim()

	if fire_sim_ref:
		# Ignite at impact point
		fire_sim_ref.ignite_at(global_position, fire_spread_radius)

		# Spawn a LOT of fire particles on collision
		_spawn_collision_burst(fire_sim_ref)

		print("[FIREBOTTLE] Shattered at ", global_position, " - ignited fire sim")
	else:
		print("[FIREBOTTLE] WARNING: No PixelFireSimulation found in scene!")

	# Ignite burnable tiles within 5-tile radius of impact
	var managers := get_tree().get_nodes_in_group("burnable_tile_manager")
	for mgr in managers:
		if mgr.has_method("ignite_at_world_pos"):
			mgr.ignite_at_world_pos(global_position, 5)

	# Spawn glass fragments
	_spawn_glass_fragments()

	queue_free()


func _spawn_kick_burst(fire_sim: Node2D) -> void:
	## Burst of fire at the kick point (initial ignition)
	for i in range(kick_particle_burst):
		var angle = rng.randf_range(-PI, PI)
		var speed = rng.randf_range(40, 180)
		var vel = Vector2(cos(angle) * speed, sin(angle) * speed - rng.randf_range(60, 150))
		# Bias in kick direction
		vel += kick_velocity.normalized() * rng.randf_range(20, 80)

		var particle = {
			"pos": global_position + Vector2(rng.randf_range(-16, 16), rng.randf_range(-16, 16)),
			"vel": vel,
			"life": 1.0,
			"max_life": 1.0,
			"heat": rng.randf_range(0.6, 1.0),
			"size": rng.randf_range(16.0, 32.0),
		}
		fire_sim.particles.append(particle)


func _spawn_collision_burst(fire_sim: Node2D) -> void:
	## Huge explosion of fire at impact
	for i in range(collision_particle_burst):
		var angle = rng.randf_range(-PI, PI)
		var speed = rng.randf_range(60, 300)
		var vel = Vector2(cos(angle) * speed, sin(angle) * speed - rng.randf_range(80, 250))
		vel += kick_velocity * 0.15

		var particle = {
			"pos": global_position + Vector2(rng.randf_range(-24, 24), rng.randf_range(-24, 24)),
			"vel": vel,
			"life": 1.0,
			"max_life": 1.0,
			"heat": rng.randf_range(0.6, 1.0),
			"size": rng.randf_range(16.0, 36.0),
		}
		fire_sim.particles.append(particle)


func _spawn_trail_particle(fire_sim: Node2D) -> void:
	## Small fire particle trailing behind the flying bottle
	var particle = {
		"pos": global_position + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4)),
		"vel": Vector2(rng.randf_range(-20, 20), rng.randf_range(-80, -30)),
		"life": rng.randf_range(0.2, 0.6),
		"max_life": 0.6,
		"heat": rng.randf_range(0.5, 0.9),
		"size": rng.randf_range(5.0, 12.0),
	}
	fire_sim.particles.append(particle)


func _spawn_glass_fragments() -> void:
	var fragment_script = load("res://kickable_fragment.gd")
	if not fragment_script:
		return

	var half := object_size / 2.0
	var corners = [
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	]

	for i in range(6):
		var p1 = corners[i % 4]
		var p2 = corners[(i + 1) % 4]
		var center = Vector2.ZERO
		var frag_points = PackedVector2Array([center, p1, p2])

		var explode_dir = ((p1 + p2) / 2.0).normalized()
		var explode_vel = explode_dir * rng.randf_range(200, 500)
		var start_vel = kick_velocity * 0.3 + explode_vel

		var fragment = fragment_script.new()
		get_parent().add_child(fragment)
		fragment.life_time = 0.8
		var color = Color(0.2, 0.5, 0.15, 0.8)
		fragment.setup(frag_points, global_position, rotation, start_vel, color, gravity_strength)


func _find_fire_sim() -> Node2D:
	# Search up through all ancestors to find the PixelFireSimulation
	var node = get_parent()
	while node:
		# Check this node
		if node.has_method("ignite_at"):
			return node
		# Check children of this node
		for child in node.get_children():
			if child == self:
				continue
			if child.has_method("ignite_at"):
				return child
		node = node.get_parent()
	
	# Fallback: search entire tree
	var tree = get_tree()
	if tree:
		for node2 in tree.get_nodes_in_group("fire_simulation"):
			return node2
		# Last resort: find by class
		var root = tree.current_scene
		if root:
			return _search_recursive(root)
	return null


func _search_recursive(node: Node) -> Node2D:
	if node.has_method("ignite_at"):
		return node
	for child in node.get_children():
		var found = _search_recursive(child)
		if found:
			return found
	return null


func _check_player_nearby() -> void:
	var players = get_tree().get_nodes_in_group("player")
	player_nearby = false
	for p in players:
		if p and is_instance_valid(p):
			var dist = global_position.distance_to(p.global_position)
			if dist < 200.0:
				player_nearby = true
				break


func _update_wick(delta: float) -> void:
	if wick_particles.size() < idle_flame_particles * 3:
		wick_particles.append({
			"offset": Vector2(rng.randf_range(-6, 6), -object_size.y * 0.5 - rng.randf_range(0, 8)),
			"vel": Vector2(rng.randf_range(-16, 16), rng.randf_range(-80, -30)),
			"life": rng.randf_range(0.15, 0.4),
			"max_life": 0.4,
			"heat": rng.randf_range(0.6, 1.0),
			"size": rng.randf_range(4, 10),
		})

	var i := 0
	while i < wick_particles.size():
		var p = wick_particles[i]
		p["life"] -= delta
		if p["life"] <= 0:
			wick_particles.remove_at(i)
			continue
		p["offset"] = p["offset"] + p["vel"] * delta
		p["heat"] *= 0.95
		wick_particles[i] = p
		i += 1


func _draw() -> void:
	var time := Time.get_ticks_msec() / 1000.0
	var half := object_size / 2.0

	# === KICK INDICATOR (when player is nearby and bottle is idle) ===
	if player_nearby and not is_kicked:
		# Pulsing glow around bottle
		var pulse := (sin(time * 5.0) * 0.5 + 0.5)
		var glow_alpha := 0.3 + pulse * 0.4
		var glow_color := Color(indicator_color.r, indicator_color.g, indicator_color.b, glow_alpha)
		var glow_expand := 4.0 + pulse * 3.0
		draw_rect(Rect2(-half.x - glow_expand, -half.y - glow_expand,
			object_size.x + glow_expand * 2, object_size.y + glow_expand * 2), glow_color, false, 2.0)

		# Bobbing arrow above bottle
		var bob_y := sin(time * indicator_bob_speed) * indicator_bob_height
		var arrow_y := -half.y - 20.0 + bob_y
		# Arrow triangle pointing down
		var arrow_points := PackedVector2Array([
			Vector2(-6, arrow_y - 8),
			Vector2(6, arrow_y - 8),
			Vector2(0, arrow_y),
		])
		draw_colored_polygon(arrow_points, indicator_color)

		# "KICK" text indicator
		draw_string(ThemeDB.fallback_font, Vector2(-14, arrow_y - 12), "KICK", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, indicator_color)

	# === MOLOTOV COCKTAIL BODY ===
	# Bottle body (dark brown/amber glass for a beer bottle look)
	var body_color = Color(0.25, 0.15, 0.05, 0.95)
	var neck_color = Color(0.2, 0.12, 0.04, 0.95)
	
	# Main body (rounded bottom)
	var body_rect = Rect2(-half.x, -half.y * 0.4, object_size.x, object_size.y * 0.75)
	draw_rect(body_rect, body_color)
	
	# Shoulder (tapering to neck)
	var shoulder_points = PackedVector2Array([
		Vector2(-half.x, -half.y * 0.4),
		Vector2(half.x, -half.y * 0.4),
		Vector2(half.x * 0.4, -half.y * 0.7),
		Vector2(-half.x * 0.4, -half.y * 0.7)
	])
	draw_colored_polygon(shoulder_points, body_color)

	# Bottle neck
	var neck_rect = Rect2(-half.x * 0.4, -half.y, object_size.x * 0.4, object_size.y * 0.3)
	draw_rect(neck_rect, neck_color)
	
	# Bottle rim
	var rim_rect = Rect2(-half.x * 0.5, -half.y - 4, object_size.x * 0.5, 6)
	draw_rect(rim_rect, neck_color)

	# Liquid inside (sloshing effect)
	var slosh := sin(time * 2.0 + global_position.x * 0.01) * 4.0
	var liquid_height := object_size.y * 0.4
	var liquid_rect = Rect2(-half.x + 4, slosh, object_size.x - 8, liquid_height)
	draw_rect(liquid_rect, Color(0.95, 0.4, 0.1, 0.75)) # Brighter fuel color
	
	# Wick cloth (rag stuffed in the neck)
	var rag_color = Color(0.8, 0.75, 0.7, 1.0)
	var rag_points = PackedVector2Array([
		Vector2(-half.x * 0.3, -half.y - 2),
		Vector2(half.x * 0.3, -half.y - 2),
		Vector2(half.x * 0.6, -half.y - 12),
		Vector2(-half.x * 0.2, -half.y - 16),
		Vector2(-half.x * 0.5, -half.y - 10)
	])
	draw_colored_polygon(rag_points, rag_color)

	# Wick flame glow (dynamic)
	var flame_pulse := (sin(time * 15.0) * 0.2 + 0.8)
	draw_circle(Vector2(0, -half.y - 12), 15.0 * flame_pulse, Color(1.0, 0.5, 0.1, 0.2 * flame_pulse))

	# Draw wick flame particles
	for p in wick_particles:
		var life_frac: float = p["life"] / p["max_life"]
		var heat: float = p["heat"]
		var sz: float = p["size"] * life_frac
		if sz < 0.5:
			continue
		var h := heat * life_frac
		var color: Color
		if h > 0.7:
			color = Color(1.0, 0.9, 0.5, life_frac)
		elif h > 0.4:
			color = Color(1.0, 0.55, 0.1, life_frac * 0.9)
		else:
			color = Color(0.7, 0.2, 0.02, life_frac * 0.6)
		draw_rect(Rect2(p["offset"].x - sz * 0.5, p["offset"].y - sz * 0.5, sz, sz), color)


func _on_body_entered(body: Node2D) -> void:
	if is_kicked and not has_collided:
		if body.is_in_group("player"):
			return
		_handle_collision(body)


func _on_area_entered(area: Area2D) -> void:
	if is_kicked and not has_collided:
		_handle_collision(area)
