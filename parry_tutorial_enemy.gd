extends "res://enemy.gd"

# Parry Tutorial Enemy - exactly like normal enemy but with perfect tracking,
# super fast bullets, and bullets that cannot be kicked
# Stops shooting once a bullet triggers the tutorial (when bullet stops near player)

var tutorial_has_been_triggered: bool = false
var bullet_has_been_parried: bool = false

func _ready() -> void:
	# Set perfect tracking and fast bullets
	tracking_speed_degrees = 999999.0  # Essentially instant tracking
	bullet_speed = 4000.0
	aim_duration = 0.1  # Shoot very quickly - just 0.1 seconds of aiming
	detection_range = 1000.0  # Medium-long range detection
	startup_delay = 0.0  # No delay - start aiming immediately when player enters range
	
	# Call parent ready
	super._ready()

func _shoot_at_player() -> void:
	"""Override shooting to spawn special unkickable bullets."""
	# Don't shoot if tutorial has already been triggered or bullet has been parried
	if tutorial_has_been_triggered or bullet_has_been_parried:
		return
	
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
	
	# Connect to bullet's tutorial trigger signal
	bullet.tutorial_triggered.connect(_on_bullet_triggered_tutorial)
	
	# Connect to bullet's parried signal to stop shooting when deflected
	bullet.bullet_parried.connect(_on_bullet_parried)
	
	# Add bullet to scene (as sibling, not child)
	get_parent().add_child(bullet)

func _on_bullet_triggered_tutorial() -> void:
	"""Called when one of our bullets triggers the tutorial - stop shooting."""
	tutorial_has_been_triggered = true
	shooting_enabled = false
	print("[ParryTutorialEnemy] Tutorial triggered, stopping all shooting")

func _on_bullet_parried() -> void:
	"""Called when one of our bullets is deflected by kicking - stop shooting."""
	bullet_has_been_parried = true
	shooting_enabled = false
	print("[ParryTutorialEnemy] Bullet parried, stopping all shooting")

