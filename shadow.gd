extends StaticBody2D

# Shadow entity that acts as a platform after rewind
# Animates through the player's past path, then persists as a platform

@export var lifetime: float = 3.0  ## Total time before the shadow disappears (after animation completes)
@export var shadow_color: Color = Color(0.5, 0.2, 0.8, 0.7)  ## Purple color with transparency

var elapsed_time: float = 0.0
var polygon: Polygon2D
var despawn_timer: Timer

# Path animation variables
var path_points: Array[Dictionary] = []  # [{position: Vector2, timestamp: float}, ...]
var animation_duration: float = 2.0  # Duration to trace the path (same as rewind_time)
var animation_start_time: float = 0.0
var is_animating: bool = false
var path_start_time: float = 0.0  # Timestamp of first path point
var path_end_time: float = 0.0  # Timestamp of last path point


func _ready() -> void:
	# Find the polygon child
	polygon = $Polygon2D if has_node("Polygon2D") else null
	
	if polygon:
		# Set the shadow color
		polygon.color = shadow_color
	
	# Set up despawn timer (but don't start it yet - wait for animation to complete)
	despawn_timer = $DespawnTimer if has_node("DespawnTimer") else null
	if despawn_timer:
		despawn_timer.wait_time = lifetime
		despawn_timer.one_shot = true
		despawn_timer.timeout.connect(_on_despawn_timer_timeout)
		# Don't start timer yet - will start after animation completes
	
	# Initialize animation (path will be set via set_path() after _ready())
	# If no path is provided, we'll handle it in set_path()
	if path_points.size() > 0:
		_initialize_animation()
	else:
		# No path provided yet - will be set via set_path()
		is_animating = false


func _process(delta: float) -> void:
	elapsed_time += delta
	
	if is_animating:
		# Animate through the path
		var animation_progress = elapsed_time / animation_duration
		
		if animation_progress >= 1.0:
			# Animation complete - move to final position and stop animating
			if path_points.size() > 0:
				global_position = path_points[path_points.size() - 1]["position"]
			is_animating = false
			# Start the despawn timer now
			if despawn_timer:
				despawn_timer.start()
		else:
			# Interpolate position along the path
			var target_time = path_start_time + (path_end_time - path_start_time) * animation_progress
			global_position = _get_position_at_time(target_time)
	
	# Fade out effect in the last second (only after animation completes)
	if not is_animating and polygon and elapsed_time >= animation_duration + lifetime - 1.0:
		var fade_start_time = animation_duration + lifetime - 1.0
		var fade_progress = (elapsed_time - fade_start_time) / 1.0
		var current_color = shadow_color
		current_color.a = shadow_color.a * (1.0 - fade_progress)
		polygon.color = current_color


func _get_position_at_time(target_time: float) -> Vector2:
	"""Get the interpolated position at the given timestamp using smooth interpolation."""
	if path_points.is_empty():
		return global_position
	
	# Find the two path points to interpolate between
	var prev_point: Dictionary = path_points[0]
	var next_point: Dictionary = path_points[path_points.size() - 1]
	
	# Find the segment containing target_time
	for i in range(path_points.size() - 1):
		if path_points[i]["timestamp"] <= target_time and path_points[i + 1]["timestamp"] >= target_time:
			prev_point = path_points[i]
			next_point = path_points[i + 1]
			break
	
	# If target_time is before first point, return first point
	if target_time < prev_point["timestamp"]:
		return prev_point["position"]
	
	# If target_time is after last point, return last point
	if target_time > next_point["timestamp"]:
		return next_point["position"]
	
	# Interpolate between the two points
	var time_range = next_point["timestamp"] - prev_point["timestamp"]
	if time_range <= 0.0:
		return prev_point["position"]
	
	var t = (target_time - prev_point["timestamp"]) / time_range
	# Use smoothstep for smoother interpolation
	t = t * t * (3.0 - 2.0 * t)  # Smoothstep function
	
	return prev_point["position"].lerp(next_point["position"], t)


func _initialize_animation() -> void:
	"""Initialize the animation with the current path_points."""
	if path_points.size() > 0:
		# Set initial position to first path point
		global_position = path_points[0]["position"]
		is_animating = true
		animation_start_time = 0.0
		elapsed_time = 0.0
		if path_points.size() > 1:
			path_start_time = path_points[0]["timestamp"]
			path_end_time = path_points[path_points.size() - 1]["timestamp"]
		else:
			path_start_time = 0.0
			path_end_time = 0.0
	else:
		# No path provided - behave like old stationary shadow
		is_animating = false
		if despawn_timer:
			despawn_timer.start()


func set_path(new_path_points: Array[Dictionary], anim_duration: float) -> void:
	"""Set the path for the shadow to animate through."""
	path_points = new_path_points
	animation_duration = anim_duration
	
	# Initialize animation with the new path
	_initialize_animation()


func _on_despawn_timer_timeout() -> void:
	"""Called when the despawn timer expires."""
	queue_free()

