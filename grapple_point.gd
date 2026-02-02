extends Node2D

## Grapple Point
## A point in the level that the player can grapple to.
## Shows a pink light indicator when player is in range, pointing in the direction
## the player will travel when grappling.

# ====================================
# GRAPPLE POINT CONFIGURATION
# ====================================

@export_group("Grapple Configuration")
@export var grapple_range: float = 300.0  ## Maximum distance at which player can grapple to this point
@export var grapple_velocity: float = 1500.0  ## Speed at which player moves toward grapple point
@export var exit_momentum: float = 1500.0  ## Momentum given to player after reaching grapple point
@export var slowdown_duration: float = 0.2  ## Time to slow player to halt before grappling

@export_group("Visual Indicator")
@export var indicator_color: Color = Color(1.0, 0.4, 0.8, 0.8)  ## Color of the indicator (pink)
@export var indicator_length: float = 80.0  ## Length of the directional indicator line
@export var indicator_width: float = 4.0  ## Width of the indicator line
@export var point_radius: float = 8.0  ## Radius of the grapple point circle
@export var point_color: Color = Color(1.0, 0.4, 0.8, 1.0)  ## Color of the grapple point
@export var pulse_speed: float = 2.0  ## Speed of the pulsing animation
@export var pulse_intensity: float = 0.3  ## Intensity of the pulse effect (0.0-1.0)

# Internal state
var player: CharacterBody2D = null
var is_player_in_range: bool = false
var indicator_line: Line2D = null
var point_circle: Polygon2D = null
var pulse_timer: float = 0.0

func _ready() -> void:
	# Find player in scene
	player = get_tree().get_first_node_in_group("player")
	
	# Create visual indicator
	_create_indicator()
	_create_point_circle()
	
	# Initially hide indicator
	indicator_line.visible = false
	
	# Add to grapple_points group so player can find us
	add_to_group("grapple_points")

func _create_indicator() -> void:
	## Creates the directional indicator line
	indicator_line = Line2D.new()
	indicator_line.width = indicator_width
	indicator_line.default_color = indicator_color
	indicator_line.z_index = 10
	add_child(indicator_line)

func _create_point_circle() -> void:
	## Creates the circular grapple point visual
	point_circle = Polygon2D.new()
	point_circle.color = point_color
	point_circle.z_index = 10
	
	# Create circle polygon
	var points: PackedVector2Array = []
	var num_segments: int = 32
	for i in range(num_segments):
		var angle: float = (i * 2.0 * PI) / num_segments
		points.append(Vector2(cos(angle), sin(angle)) * point_radius)
	
	point_circle.polygon = points
	add_child(point_circle)

func _physics_process(delta: float) -> void:
	if not player:
		return
	
	# Update pulse animation
	pulse_timer += delta * pulse_speed
	var pulse_factor: float = (sin(pulse_timer) * 0.5 + 0.5) * pulse_intensity
	var current_scale: float = 1.0 + pulse_factor
	point_circle.scale = Vector2(current_scale, current_scale)
	
	# Check if player is in range
	var distance: float = global_position.distance_to(player.global_position)
	is_player_in_range = distance <= grapple_range
	
	# Update indicator visibility and direction
	if is_player_in_range:
		_update_indicator()
		indicator_line.visible = true
	else:
		indicator_line.visible = false

func _update_indicator() -> void:
	## Updates the indicator to point in the grapple direction
	if not player:
		return
	
	# Calculate direction from player to grapple point
	var direction: Vector2 = (global_position - player.global_position).normalized()
	
	# Calculate start and end points in local space
	var start_point: Vector2 = Vector2.ZERO
	var end_point: Vector2 = direction * indicator_length
	
	# Update line points
	indicator_line.clear_points()
	indicator_line.add_point(start_point)
	indicator_line.add_point(end_point)
	
	# Add arrowhead for direction
	var arrow_size: float = 12.0
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var arrow_left: Vector2 = end_point - direction * arrow_size + perpendicular * arrow_size * 0.5
	var arrow_right: Vector2 = end_point - direction * arrow_size - perpendicular * arrow_size * 0.5
	
	indicator_line.add_point(arrow_left)
	indicator_line.add_point(end_point)
	indicator_line.add_point(arrow_right)

func get_grapple_direction() -> Vector2:
	## Returns the normalized direction from player to this grapple point
	if not player:
		return Vector2.ZERO
	return (global_position - player.global_position).normalized()

func is_in_range() -> bool:
	## Returns whether player is currently in grapple range
	return is_player_in_range
