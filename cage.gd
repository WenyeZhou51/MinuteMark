extends Node2D

@export_group("Cage Properties")
@export var cage_width: float = 252.0   ## Width in pixels (75% of sprite native 336)
@export var cage_height: float = 274.0  ## Height in pixels (75% of sprite native 366)
@export var wall_thickness: float = 10.0
@export var push_speed: float = 195.0   ## Horizontal push speed in px/sec
@export var fall_speed: float = 800.0   ## Gravity when not grounded

@export_group("Fade After Escape")
@export var linger_time: float = 3.0
@export var fade_duration: float = 0.5

@onready var cage_body: AnimatableBody2D = $CageBody

var player: CharacterBody2D = null
var _fall_velocity := 0.0
var _player_was_inside: bool = false
var _fading: bool = false
var _fade_timer: float = 0.0


func _ready() -> void:
	cage_body.top_level = true
	cage_body.global_position = global_position
	cage_body.collision_layer = 8  # Layer 4 — separate from terrain (layer 1)
	cage_body.collision_mask = 0
	_setup_sprites()


func _physics_process(delta: float) -> void:
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
		cage_body.global_position.x += push_dir * actual


func _apply_gravity(delta: float) -> void:
	var half_h := cage_height / 2.0
	var bottom_y := cage_body.global_position.y + half_h
	var space_state := get_world_2d().direct_space_state

	# Check if grounded (ray from just above bottom to just below)
	var ground_check := PhysicsRayQueryParameters2D.create(
		Vector2(cage_body.global_position.x, bottom_y - 4.0),
		Vector2(cage_body.global_position.x, bottom_y + 2.0))
	ground_check.collision_mask = 1  # Terrain only — cage is on layer 4, not 1
	if space_state.intersect_ray(ground_check):
		_fall_velocity = 0.0
		return

	# Not grounded — accelerate and fall
	_fall_velocity += fall_speed * delta
	var fall_dist := _fall_velocity * delta
	var from := Vector2(cage_body.global_position.x, bottom_y)
	var to := from + Vector2(0, fall_dist + 2.0)
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1
	var result := space_state.intersect_ray(query)
	if result:
		cage_body.global_position.y = result.position.y - half_h
		_fall_velocity = 0.0
	else:
		cage_body.global_position.y += fall_dist


func _get_push_direction() -> int:
	for i in range(player.get_slide_collision_count()):
		var collision := player.get_slide_collision(i)
		if not collision:
			continue
		if collision.get_collider() == cage_body:
			var normal := collision.get_normal()
			if abs(normal.x) > 0.7:
				return -int(sign(normal.x))
	return 0


func _get_max_move_distance(dir: int, desired: float) -> float:
	var half_w := cage_width / 2.0
	var half_h := cage_height / 2.0
	var wt := wall_thickness
	var leading_x := cage_body.global_position.x + dir * half_w
	var space_state := get_world_2d().direct_space_state
	var min_dist := desired

	# Cast 3 rays along the height of the leading wall
	for offset_y in [-half_h + wt, 0.0, half_h - wt]:
		var origin := Vector2(leading_x, cage_body.global_position.y + offset_y)
		var end := origin + Vector2(dir * (desired + 2.0), 0)
		var query := PhysicsRayQueryParameters2D.create(origin, end)
		query.collision_mask = 1  # Terrain only
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
	var cp := cage_body.global_position
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
		cage_body.modulate.a = 1.0 - t

	if _fade_timer >= linger_time:
		cage_body.collision_layer = 0
		for child in cage_body.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
		queue_free()


func _setup_sprites() -> void:
	var back: Sprite2D = $CageBody/BackSprite
	var front: Sprite2D = $CageBody/FrontSprite
	if back and back.texture:
		var tex_size := back.texture.get_size()
		back.scale = Vector2(cage_width / tex_size.x, cage_height / tex_size.y)
	if front and front.texture:
		var tex_size := front.texture.get_size()
		front.scale = Vector2(cage_width / tex_size.x, cage_height / tex_size.y)
