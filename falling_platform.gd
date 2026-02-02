extends Node2D

@export_group("Falling Platform")
@export var fall_delay: float = 1.0  ## Time before the platform starts falling
@export var fall_speed: float = 900.0  ## Downward speed in pixels/sec
@export var vibration_amplitude: float = 6.0  ## Visual shake amount (pixels)
@export var vibration_frequency: float = 22.0  ## Visual shake speed (Hz)
@export var debug_logs: bool = false  ## Print debug info while testing
const DESPAWN_PADDING: float = 200.0
const LANDING_MARGIN: float = 6.0
const PLAYER_FALLBACK_MARGIN: float = 10.0

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
		_update_visual_from_shape()
	
	_sync_trigger_shape()
	
	if debug_logs:
		print("[FallingPlatform] Ready. Trigger mask=", trigger_area.collision_mask if trigger_area else "null",
			" monitoring=", trigger_area.monitoring if trigger_area else "null",
			" layer=", platform_body.collision_layer if platform_body else "null")


func _process(delta: float) -> void:
	if is_triggered and not is_falling and visual:
		vibration_time += delta
		var offset = Vector2(
			sin(vibration_time * vibration_frequency * TAU),
			cos(vibration_time * vibration_frequency * TAU * 0.7)
		) * vibration_amplitude
		visual.position = base_visual_pos + offset
	elif is_triggered and not is_falling and platform_body and not visual:
		# Fallback: shake the body if no visual is present
		vibration_time += delta
		var offset = Vector2(
			sin(vibration_time * vibration_frequency * TAU),
			cos(vibration_time * vibration_frequency * TAU * 0.7)
		) * vibration_amplitude
		platform_body.position = base_body_pos + offset


func _physics_process(delta: float) -> void:
	if debug_logs:
		debug_timer += delta
		if debug_timer >= 0.5:
			debug_timer = 0.0
			var overlap_bodies = trigger_area.get_overlapping_bodies() if trigger_area else []
			var overlap_names: Array[String] = []
			for body in overlap_bodies:
				overlap_names.append("%s(%s)" % [body.name, body.get_class()])
			var player = get_tree().get_first_node_in_group("player") as CharacterBody2D
			var player_floor_info = ""
			if player:
				player_floor_info = " player_on_floor=%s standing_on_platform=%s" % [
					player.is_on_floor(),
					_is_player_standing_on_platform(player)
				]
			print("[FallingPlatform] Tick. overlap_bodies=", overlap_bodies.size(),
				" list=", overlap_names,
				" triggered=", is_triggered, " falling=", is_falling, player_floor_info)
	
	if not is_triggered and trigger_area:
		var bodies = trigger_area.get_overlapping_bodies()
		for body in bodies:
			if body == platform_body or body == self:
				continue
			if _is_player(body) and _is_landing_from_above(body):
				is_triggered = true
				fall_timer = 0.0
				vibration_time = 0.0
				if debug_logs:
					print("[FallingPlatform] Triggered by overlap: ", body.name)
				break
	
	if not is_triggered:
		_try_trigger_from_player_fallback()
	
	if is_triggered and not is_falling:
		fall_timer += delta
		if fall_timer >= fall_delay:
			_start_fall()
	
	if is_falling and platform_body:
		platform_body.position.y += fall_speed * delta
		if debug_logs and not has_logged_fall_start:
			has_logged_fall_start = true
			print("[FallingPlatform] Falling started. speed=", fall_speed)
		if _is_below_viewport():
			if debug_logs:
				print("[FallingPlatform] Despawned (left viewport).")
			queue_free()


func _on_body_entered(body: Node) -> void:
	if is_triggered:
		return
	if body == platform_body or body == self:
		return
	if not _is_player(body):
		return
	if not _is_landing_from_above(body):
		return
	
	is_triggered = true
	fall_timer = 0.0
	vibration_time = 0.0
	if debug_logs:
		print("[FallingPlatform] Triggered by body_entered: ", body.name)


func _start_fall() -> void:
	is_falling = true
	if visual:
		visual.position = base_visual_pos
	if platform_body:
		platform_body.position = base_body_pos


func _is_player(body: Node) -> bool:
	return body and (body.is_in_group("player") or body.name == "Player")


func _is_landing_from_above(body: Node) -> bool:
	if body is CharacterBody2D:
		var player_body := body as CharacterBody2D
		return _is_player_standing_on_platform(player_body)
	
	# Fallback for non-player bodies.
	return true


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
	if player is CharacterBody2D:
		var player_body := player as CharacterBody2D
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
		if debug_logs:
			print("[FallingPlatform] Triggered by fallback check at pos=", player.global_position)


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
