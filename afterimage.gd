extends Node2D

# Afterimage that transitions from green to red and fades out

@export var lifetime: float = 1.0  ## Total time before the afterimage disappears (1 second for 8 images)
@export var initial_alpha: float = 0.6  ## Starting opacity

var elapsed_time: float = 0.0
var polygon: Polygon2D
var start_color: Color = Color(0.2, 1.0, 0.2)  # Green
var end_color: Color = Color(1.0, 0.2, 0.2)  # Red


func _ready() -> void:
	# Find the polygon child
	polygon = $Polygon2D if has_node("Polygon2D") else null
	
	if polygon:
		# Store the initial color that was set
		start_color = polygon.color
		start_color.a = 1.0  # Remove alpha for color lerp
		# Set initial alpha
		var color = polygon.color
		color.a = initial_alpha
		polygon.color = color


func _process(delta: float) -> void:
	elapsed_time += delta
	
	# Calculate fade progress (0.0 to 1.0)
	var fade_progress = elapsed_time / lifetime
	
	if fade_progress >= 1.0:
		# Lifetime expired, delete the afterimage
		queue_free()
		return
	
	# Update the polygon with color gradient and fade
	if polygon:
		# Lerp from green (start_color) to red (end_color)
		var current_color = start_color.lerp(end_color, fade_progress)
		# Apply fade out to alpha
		current_color.a = initial_alpha * (1.0 - fade_progress)
		polygon.color = current_color

