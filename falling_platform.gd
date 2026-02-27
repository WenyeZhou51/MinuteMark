extends Node2D

@export_group("Falling Platform")
@export var fall_delay: float = 1.0  ## Time before the platform starts falling
@export var fall_speed: float = 900.0  ## Downward speed in pixels/sec
@export var stop_on_first_platform: bool = false  ## Land on first platform/ground hit
@export var vibration_amplitude: float = 6.0  ## Visual shake amount (pixels)
@export var vibration_frequency: float = 22.0  ## Visual shake speed (Hz)
@export var debug_logs: bool = false  ## Print debug info while testing

@export_group("Behavior")
@export var auto_update_from_shape: bool = true  ## If true, Visual/Trigger shapes are auto-synced from CollisionShape in _ready()
const DESPAWN_PADDING: float = 200.0
const LANDING_MARGIN: float = 6.0
const PLAYER_FALLBACK_MARGIN: float = 10.0
const FALL_COLLISION_MASK: int = 1

@onready var platform_body: AnimatableBody2D = $PlatformBody
@onready var collision_shape: CollisionShape2D = $PlatformBody/CollisionShape2D
@onready var visual: Node2D = $PlatformBody/Visual
@onready var trigger_area: Area2D = $PlatformBody/TriggerArea
@onready var trigger_shape: CollisionShape2D = $PlatformBody/TriggerArea/CollisionShape2D

var is_triggered: bool = false
var is_falling: bool = false
var fall_timer: float = 0.0
var vibration_time: float = 0.0
var base_visual_pos: Vector2 = Vector2.ZERO
var base_body_pos: Vector2 = Vector2.ZERO
var has_logged_fall_start: bool = false
var debug_timer: float = 0.0
var fall_start_bottom_y: float = 0.0
var has_landed: bool = false


func _ready() -> void:
	set_process(true)
	set_physics_process(true)
	
	if platform_body:
		platform_body.collision_layer = 1
		platform_body.collision_mask = 0
		platform_body.add_to_group("platforms")
		base_body_pos = platform_body.position
	
	if trigger_area:
		trigger_area.collision_layer = 0
		trigger_area.collision_mask = 0xFFFFFFFF
		trigger_area.monitoring = true
		trigger_area.monitorable = true
		trigger_area.body_entered.connect(_on_body_entered)
	
	if visual:
		base_visual_pos = visual.position
		if auto_update_from_shape:
			_update_visual_from_shape()
	
	if auto_update_from_shape:
		_sync_trigger_shape()
	


func _process(delta: float) -> void:
	if is_triggered and not is_falling and not has_landed and visual:
		vibration_time += delta
		var offset = Vector2(
			sin(vibration_time * vibration_frequency * TAU),
			cos(vibration_time * vibration_frequency * TAU * 0.7)
		) * vibration_amplitude
		visual.position = base_visual_pos + offset
	elif is_triggered and not is_falling and not has_landed and platform_body and not visual:
		# Fallback: shake the body if no visual is present
		vibration_time += delta
		var offset = Vector2(
			sin(vibration_time * vibration_frequency * TAU),
			cos(vibration_time * vibration_frequency * TAU * 0.7)
		) * vibration_amplitude
		platform_body.position = base_body_pos + offset


func _physics_process(delta: float) -> void:
	if not is_triggered and trigger_area:
		var bodies = trigger_area.get_overlapping_bodies()
		for body in bodies:
			if body == platform_body or body == self:
				continue
			if _is_player(body) and (_is_landing_from_above(body) or _is_player_wall_interacting(body)):
				is_triggered = true
				fall_timer = 0.0
				vibration_time = 0.0
				break
	
	if not is_triggered:
		_try_trigger_from_player_fallback()
	
	if is_triggered and not is_falling:
		fall_timer += delta
		if fall_timer >= fall_delay:
			_start_fall()
	
	if is_falling and platform_body:
		if stop_on_first_platform:
			_fall_with_collision(delta)
		else:
			platform_body.position.y += fall_speed * delta
		if not stop_on_first_platform and _is_below_viewport():
			queue_free()


func _on_body_entered(body: Node) -> void:
	if is_triggered:
		return
	if body == platform_body or body == self:
		return
	if not _is_player(body):
		return
	if not _is_landing_from_above(body) and not _is_player_wall_interacting(body):
		return
	
	is_triggered = true
	fall_timer = 0.0
	vibration_time = 0.0


func _start_fall() -> void:
	is_falling = true
	has_landed = false
	if visual:
		visual.position = base_visual_pos
	if platform_body:
		platform_body.position = base_body_pos
		fall_start_bottom_y = platform_body.global_position.y + _get_platform_half_height()


func _is_player(body: Node) -> bool:
	return body and (body.is_in_group("player") or body.name == "Player")


func _is_landing_from_above(body: Node) -> bool:
	if body is CharacterBody2D:
		var player_body := body as CharacterBody2D
		return _is_player_standing_on_platform(player_body)
	
	# Fallback for non-player bodies.
	return true


func _is_player_wall_interacting(body: Node) -> bool:
	"""Check if the player is wall running on or wall jumping off this platform."""
	if not body is CharacterBody2D or not platform_body:
		return false
	var player_body := body as CharacterBody2D
	
	# Check if player is wall running on this platform
	if player_body.get("is_wall_running") and player_body.is_wall_running:
		# Verify they're actually colliding with THIS platform (side collision)
		if _has_wall_collision_with_platform(player_body):
			return true
	
	# Check if player is wall sliding on this platform
	if player_body.get("is_wall_sliding") and player_body.is_wall_sliding:
		if _has_wall_collision_with_platform(player_body):
			return true
	
	# Check if player just wall jumped off this platform (wall_jump_cooldown was just set)
	if player_body.get("wall_jump_cooldown") != null and player_body.wall_jump_cooldown > 0.2:
		# Player very recently wall jumped — check proximity to this platform
		if _is_player_beside_platform(player_body):
			return true
	
	return false


func _has_wall_collision_with_platform(player_body: CharacterBody2D) -> bool:
	"""Check if the player has a wall-type slide collision with this platform's body."""
	var collision_count = player_body.get_slide_collision_count()
	for i in range(collision_count):
		var collision = player_body.get_slide_collision(i)
		# Wall collision = horizontal normal (abs(x) > 0.7)
		if abs(collision.get_normal().x) > 0.7:
			if collision.get_collider() == platform_body:
				return true
	return false


func _is_player_beside_platform(player_body: CharacterBody2D) -> bool:
	"""Check if the player is right beside (touching the side of) this platform."""
	var half_width = _get_platform_half_width()
	var half_height = _get_platform_half_height()
	if half_width <= 0.0 or half_height <= 0.0:
		return false
	
	var plat_pos = platform_body.global_position
	var player_pos = player_body.global_position
	
	# Check vertical overlap (player is alongside the platform, not above/below)
	var within_y = player_pos.y >= plat_pos.y - half_height - PLAYER_FALLBACK_MARGIN and \
				   player_pos.y <= plat_pos.y + half_height + PLAYER_FALLBACK_MARGIN
	# Check horizontal proximity (player is right next to the side)
	var dist_x = abs(player_pos.x - plat_pos.x)
	var within_x = dist_x <= half_width + PLAYER_FALLBACK_MARGIN + 20.0  # slightly wider margin for wall jump push-off
	
	return within_x and within_y


func _get_platform_half_height() -> float:
	if collision_shape and collision_shape.shape and collision_shape.shape is RectangleShape2D:
		var rect_shape := collision_shape.shape as RectangleShape2D
		return rect_shape.size.y / 2.0
	return 0.0


func _get_platform_half_width() -> float:
	if collision_shape and collision_shape.shape and collision_shape.shape is RectangleShape2D:
		var rect_shape := collision_shape.shape as RectangleShape2D
		return rect_shape.size.x / 2.0
	return 0.0


func _try_trigger_from_player_fallback() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not platform_body:
		return
	
	# Check wall interaction first (wall run / wall jump / wall slide)
	if player is CharacterBody2D:
		var player_body := player as CharacterBody2D
		if _is_player_wall_interacting(player_body):
			is_triggered = true
			fall_timer = 0.0
			vibration_time = 0.0
			return
		if not _is_player_standing_on_platform(player_body):
			return
	
	var half_width = _get_platform_half_width()
	var half_height = _get_platform_half_height()
	if half_width <= 0.0 or half_height <= 0.0:
		return
	
	var top_y = platform_body.global_position.y - half_height
	var within_y = player.global_position.y <= top_y + PLAYER_FALLBACK_MARGIN
	var within_x = abs(player.global_position.x - platform_body.global_position.x) <= half_width + PLAYER_FALLBACK_MARGIN
	
	if within_x and within_y:
		is_triggered = true
		fall_timer = 0.0
		vibration_time = 0.0


func _is_player_standing_on_platform(player_body: CharacterBody2D) -> bool:
	if not player_body or not platform_body:
		return false
	if not player_body.is_on_floor():
		return false
	
	var collision_count = player_body.get_slide_collision_count()
	for i in range(collision_count):
		var collision = player_body.get_slide_collision(i)
		if collision.get_normal().y < -0.7:
			var collider = collision.get_collider()
			if collider == platform_body:
				return true
	return false


func _fall_with_collision(delta: float) -> void:
	var step = fall_speed * delta
	if step <= 0.0 or not platform_body:
		return
	
	var collision = _get_fall_collision(step)
	if collision.is_empty():
		platform_body.position.y += step
		return
	
	var hit_pos: Vector2 = collision.position
	var half_height = _get_platform_half_height()
	platform_body.global_position.y = hit_pos.y - half_height - LANDING_MARGIN
	is_falling = false
	has_landed = true
	
	var collider = collision.collider
	if _is_ground_collider(collider):
		_kill_enemies_in_falling_path(hit_pos.y)
	


func _get_fall_collision(step: float) -> Dictionary:
	var half_height = _get_platform_half_height()
	var ray_start = platform_body.global_position + Vector2(0.0, half_height)
	var ray_end = ray_start + Vector2(0.0, step + LANDING_MARGIN)
	
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.collision_mask = FALL_COLLISION_MASK
	query.exclude = _get_fall_exclude()
	
	var space_state = get_world_2d().direct_space_state
	return space_state.intersect_ray(query)


func _get_fall_exclude() -> Array:
	var exclude: Array = [self]
	if platform_body:
		exclude.append(platform_body)
	if trigger_area:
		exclude.append(trigger_area)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		exclude.append(player)
	return exclude


func _is_ground_collider(collider: Object) -> bool:
	if collider and collider.is_in_group("platforms"):
		return false
	return true


func _kill_enemies_in_falling_path(impact_y: float) -> void:
	if not platform_body:
		return
	
	var half_width = _get_platform_half_width()
	if half_width <= 0.0:
		return
	
	var min_y = min(fall_start_bottom_y, impact_y)
	var max_y = max(fall_start_bottom_y, impact_y)
	var left_x = platform_body.global_position.x - half_width - LANDING_MARGIN
	var right_x = platform_body.global_position.x + half_width + LANDING_MARGIN
	
	var enemies: Array = []
	enemies.append_array(get_tree().get_nodes_in_group("enemy"))
	enemies.append_array(get_tree().get_nodes_in_group("enemies"))
	
	for enemy in enemies:
		if not enemy or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node := enemy as Node2D
		var pos = enemy_node.global_position
		if pos.x < left_x or pos.x > right_x:
			continue
		if pos.y < min_y or pos.y > max_y:
			continue
		
		if enemy_node.has_method("destroy"):
			enemy_node.destroy()
		elif enemy_node.has_method("queue_free"):
			enemy_node.queue_free()


func _update_visual_from_shape() -> void:
	if not visual or not collision_shape or not collision_shape.shape:
		return
	if visual is Polygon2D and collision_shape.shape is RectangleShape2D:
		var rect_shape := collision_shape.shape as RectangleShape2D
		var half = rect_shape.size / 2.0
		var poly := visual as Polygon2D
		poly.polygon = PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y)
		])


func _sync_trigger_shape() -> void:
	if trigger_shape and collision_shape and collision_shape.shape:
		trigger_shape.shape = collision_shape.shape.duplicate()


func _is_below_viewport() -> bool:
	var rect = _get_world_viewport_rect()
	if rect.size == Vector2.ZERO or not platform_body:
		return false
	
	var half_height = _get_platform_half_height()
	var top_y = platform_body.global_position.y - half_height
	return top_y > rect.position.y + rect.size.y + DESPAWN_PADDING


func _get_world_viewport_rect() -> Rect2:
	var viewport = get_viewport()
	if not viewport:
		return Rect2()
	
	var rect = viewport.get_visible_rect()
	var camera = viewport.get_camera_2d()
	if camera:
		var center = camera.get_screen_center_position()
		return Rect2(center - rect.size / 2.0, rect.size)
	
	return rect
