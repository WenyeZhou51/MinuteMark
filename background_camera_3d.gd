extends Camera3D
## 3D Camera that follows the 2D player with parallax effect

@export var player_path: NodePath = "../../../Player"
@export var parallax_strength: float = 0.08
@export var vertical_parallax_strength: float = 0.05
@export var base_distance: float = 15.0
@export var smooth_speed: float = 5.0

var player: Node2D
var target_position: Vector3

func _ready():
	# Try to find the player
	if player_path:
		player = get_node_or_null(player_path)
	
	if not player:
		# Try to find player in the scene tree
		player = get_tree().get_first_node_in_group("player")
	
	if player:
		# Initialize position
		target_position = Vector3(
			player.position.x * parallax_strength,
			-player.position.y * vertical_parallax_strength,
			base_distance
		)
		position = target_position
	else:
		position = Vector3(0, 0, base_distance)

func _process(delta):
	if player:
		# Calculate target position based on player's 2D position
		target_position = Vector3(
			player.position.x * parallax_strength,
			-player.position.y * vertical_parallax_strength,
			base_distance
		)
		
		# Smoothly interpolate to target position
		position = position.lerp(target_position, smooth_speed * delta)

