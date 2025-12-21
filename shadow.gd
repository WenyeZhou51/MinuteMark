extends StaticBody2D

# Shadow entity that acts as a platform after rewind
# Spawned at the rewind position and persists for a duration

@export var lifetime: float = 3.0  ## Total time before the shadow disappears
@export var shadow_color: Color = Color(0.5, 0.2, 0.8, 0.7)  ## Purple color with transparency

var elapsed_time: float = 0.0
var polygon: Polygon2D
var despawn_timer: Timer


func _ready() -> void:
	# Find the polygon child
	polygon = $Polygon2D if has_node("Polygon2D") else null
	
	if polygon:
		# Set the shadow color
		polygon.color = shadow_color
	
	# Set up despawn timer
	despawn_timer = $DespawnTimer if has_node("DespawnTimer") else null
	if despawn_timer:
		despawn_timer.wait_time = lifetime
		despawn_timer.one_shot = true
		despawn_timer.timeout.connect(_on_despawn_timer_timeout)
		despawn_timer.start()


func _process(delta: float) -> void:
	elapsed_time += delta
	
	# Optional: Fade out effect in the last second
	if polygon and elapsed_time >= lifetime - 1.0:
		var fade_progress = (elapsed_time - (lifetime - 1.0)) / 1.0
		var current_color = shadow_color
		current_color.a = shadow_color.a * (1.0 - fade_progress)
		polygon.color = current_color


func _on_despawn_timer_timeout() -> void:
	"""Called when the despawn timer expires."""
	queue_free()

