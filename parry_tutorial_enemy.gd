extends "res://enemy.gd"

# Parry Tutorial Enemy - exactly like normal enemy but with perfect tracking,
# super fast bullets, and bullets that cannot be kicked

func _ready() -> void:
	# Set perfect tracking and fast bullets
	tracking_speed_degrees = 999999.0  # Essentially instant tracking
	bullet_speed = 4000.0
	
	# Call parent ready
	super._ready()

func _shoot_at_player() -> void:
	"""Override shooting to spawn special unkickable bullets."""
	if not player_ref or not is_instance_valid(player_ref):
		return
	
	# Play attack animation
	if animated_sprite:
		is_firing_animation = true
		animated_sprite.play("attack")
	
	# Calculate direction based on current laser angle
	var shoot_direction = Vector2(cos(current_laser_angle), sin(current_laser_angle))
	
	# Create bullet
	const BulletScene = preload("res://parry_tutorial_bullet.tscn")
	var bullet = BulletScene.instantiate()
	
	# Position bullet at gunpoint location
	var spawn_pos = gunpoint.global_position if gunpoint else global_position
	bullet.global_position = spawn_pos
	
	# Initialize bullet with direction, speed, and shooter reference
	bullet.initialize(shoot_direction, bullet_speed, self)
	
	# Add bullet to scene (as sibling, not child)
	get_parent().add_child(bullet)

