extends Node2D

@export_group("Moving Platform")
@export var move_speed: float = 160.0  ## Pixels per second along the path
@export var motion_mode: MotionMode = MotionMode.PING_PONG
@export var pause_at_ends: float = 0.0  ## Pause duration at each end for ping-pong
@export_range(0.0, 1.0, 0.01) var start_progress_ratio: float = 0.0
@export var debug_logs: bool = false

enum MotionMode { LOOP, PING_PONG }

@onready var path: Path2D = $Path2D
@onready var path_follow: PathFollow2D = $Path2D/PathFollow2D
@onready var platform_body: AnimatableBody2D = $Path2D/PathFollow2D/PlatformBody
@onready var collision_shape: CollisionShape2D = $Path2D/PathFollow2D/PlatformBody/CollisionShape2D
@onready var visual: Node2D = $Path2D/PathFollow2D/PlatformBody/Visual

var direction: float = 1.0
var pause_timer: float = 0.0
var path_length: float = 0.0


func _ready() -> void:
	if not path.curve or path.curve.point_count == 0:
		var default_curve = Curve2D.new()
		default_curve.add_point(Vector2.ZERO)
		default_curve.add_point(Vector2(400, 0))
		path.curve = default_curve
	
	path_follow.rotates = false
	path_length = path.curve.get_baked_length()
	path_follow.progress = clamp(start_progress_ratio, 0.0, 1.0) * path_length
	
	if platform_body:
		# Keep physics body in sync even though it's parented under PathFollow2D.
		# This avoids parent-transform desync in the physics server.
		platform_body.top_level = true
		platform_body.global_position = path_follow.global_position
		platform_body.collision_layer = 1
		platform_body.collision_mask = 0
		platform_body.add_to_group("platforms")
	
	_update_visual_from_shape()
	
	if debug_logs:
		print("[MovingPlatform] Ready. path_length=", path_length, " mode=", motion_mode)


func _physics_process(delta: float) -> void:
	if path_length <= 0.0:
		return
	
	if pause_timer > 0.0:
		pause_timer = max(pause_timer - delta, 0.0)
		return
	
	var step = move_speed * delta * direction
	var next_progress = path_follow.progress + step
	
	match motion_mode:
		MotionMode.LOOP:
			next_progress = fposmod(next_progress, path_length)
		MotionMode.PING_PONG:
			if next_progress > path_length:
				next_progress = path_length
				direction = -1.0
				if pause_at_ends > 0.0:
					pause_timer = pause_at_ends
			elif next_progress < 0.0:
				next_progress = 0.0
				direction = 1.0
				if pause_at_ends > 0.0:
					pause_timer = pause_at_ends
	
	path_follow.progress = next_progress
	if platform_body:
		platform_body.global_position = path_follow.global_position


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
