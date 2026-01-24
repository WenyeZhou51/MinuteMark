extends Node2D

var velocity: Vector2 = Vector2.ZERO
var gravity: float = 2000.0
var life_time: float = 1.0
var timer: float = 0.0
var rotation_speed: float = 0.0

@onready var visual: Polygon2D = Polygon2D.new()
@onready var outline: Line2D = null
@onready var shadow: Polygon2D = null

func _ready() -> void:
	# Create shadow (rendered first, behind everything)
	shadow = Polygon2D.new()
	shadow.z_index = -2
	add_child(shadow)
	
	# Add main visual
	add_child(visual)
	
	# Create outline (rendered on top)
	outline = Line2D.new()
	outline.width = 2.0
	outline.default_color = Color(0.5, 0.0, 0.8, 1.0)  # Purple outline
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	outline.z_index = 1
	add_child(outline)
	
	rotation_speed = randf_range(-15.0, 15.0)

func setup(points: PackedVector2Array, obj_global_pos: Vector2, obj_rotation: float, start_vel: Vector2, color: Color, grav: float = 2000.0) -> void:
	# Calculate centroid of points (relative to original object center)
	var centroid = Vector2.ZERO
	for p in points:
		centroid += p
	centroid /= points.size()
	
	# Shift points so centroid is at (0,0) for the fragment's local space
	var shifted_points = PackedVector2Array()
	for p in points:
		shifted_points.append(p - centroid)
	
	global_position = obj_global_pos + centroid.rotated(obj_rotation)
	velocity = start_vel
	gravity = grav
	visual.polygon = shifted_points
	visual.color = color
	
	# Setup shadow - yellow, offset diagonally (down-right)
	if shadow:
		var shadow_offset = Vector2(3, 3)  # Diagonal offset
		var shadow_points = PackedVector2Array()
		for p in shifted_points:
			shadow_points.append(p + shadow_offset)
		shadow.polygon = shadow_points
		shadow.color = Color(1.0, 0.9, 0.0, 0.6)  # Yellow shadow with transparency
	
	# Setup outline - purple line around the fragment
	if outline:
		# Close the polygon by adding first point at the end
		var outline_points = PackedVector2Array()
		for p in shifted_points:
			outline_points.append(p)
		# Close the loop
		if shifted_points.size() > 0:
			outline_points.append(shifted_points[0])
		outline.points = outline_points
	
	# Inherit initial rotation and add some variety
	rotation = obj_rotation + randf_range(-0.5, 0.5)

func _physics_process(delta: float) -> void:
	timer += delta
	
	# Apply gravity
	velocity.y += gravity * delta
	
	# Move
	global_position += velocity * delta
	rotation += rotation_speed * delta
	
	# Fade out all visual elements
	if timer > life_time * 0.5:
		var fade_progress = (timer - life_time * 0.5) / (life_time * 0.5)
		var alpha = 1.0 - fade_progress
		modulate.a = alpha
		
		# Fade outline
		if outline:
			var outline_color = outline.default_color
			outline_color.a = alpha
			outline.default_color = outline_color
		
		# Fade shadow
		if shadow:
			var shadow_color = shadow.color
			shadow_color.a = 0.6 * alpha  # Keep original transparency ratio
			shadow.color = shadow_color
	
	# Clean up
	if timer >= life_time:
		queue_free()
