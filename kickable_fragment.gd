extends Node2D

var velocity: Vector2 = Vector2.ZERO
var gravity: float = 2000.0
var life_time: float = 1.0
var timer: float = 0.0
var rotation_speed: float = 0.0

@onready var visual: Polygon2D = Polygon2D.new()

func _ready() -> void:
	add_child(visual)
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
	
	# Inherit initial rotation and add some variety
	rotation = obj_rotation + randf_range(-0.5, 0.5)

func _physics_process(delta: float) -> void:
	timer += delta
	
	# Apply gravity
	velocity.y += gravity * delta
	
	# Move
	global_position += velocity * delta
	rotation += rotation_speed * delta
	
	# Fade out
	if timer > life_time * 0.5:
		var fade_progress = (timer - life_time * 0.5) / (life_time * 0.5)
		modulate.a = 1.0 - fade_progress
	
	# Clean up
	if timer >= life_time:
		queue_free()

