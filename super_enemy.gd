extends Node2D

@export var rocket_scene: PackedScene = preload("res://Rocket.tscn")
@export var target_spot: Node2D # A Marker2D or other node to aim at

@export_group("Trigger Timing")
@export var player_pause_duration: float = 0.5 ## How long the player is paused when triggered (seconds)
@export var grunt_delay: float = 0.5 ## Delay before showing grunt after trigger (seconds)
@export var fire_delay: float = 1.0 ## Delay before firing rockets after trigger (seconds)

@export_group("Rocket Properties")
@export var rocket_speed: float = 400.0 ## Speed of the fired rockets

@export_group("Grunt Effect")
@export var grunt_texture: Texture2D = preload("res://Sprites/Super enemy grunt.png") ## Texture for the grunt effect
@export var grunt_offset: Vector2 = Vector2(0, -80) ## Offset of the grunt relative to super enemy
@export var grunt_base_scale: float = 1.0 ## Base scale multiplier for the grunt size
@export var grunt_duration: float = 1.0 ## Duration the grunt lasts (seconds)
@export var grunt_fade_duration: float = 0.8 ## Duration of the fade out effect (seconds)
@export var grunt_scale_start: float = 1.0 ## Starting scale multiplier (relative to base scale)
@export var grunt_scale_end: float = 1.5 ## Ending scale multiplier (relative to base scale, for expansion)

func fire_at_target() -> void:
	if not rocket_scene: return
	
	# Show grunt effect
	_show_grunt_effect()
	
	# Fire rockets
	fire_rockets()

func show_grunt() -> void:
	"""Public method to show grunt effect without firing."""
	print("[SuperEnemy] Showing grunt at position: ", global_position)
	_show_grunt_effect()

func fire_rockets() -> void:
	"""Public method to fire rockets without showing grunt."""
	print("[SuperEnemy] fire_rockets() called at position: ", global_position)
	
	if not rocket_scene:
		push_error("[SuperEnemy] ERROR: No rocket scene assigned!")
		return
	
	# Find all rocket targets - can be nodes in the "rocket_target" group
	# or the specifically assigned target_spot
	var targets = get_tree().get_nodes_in_group("rocket_target")
	print("[SuperEnemy] Found ", targets.size(), " targets in 'rocket_target' group")
	
	# Add the specifically assigned target if it's not already in the group
	if target_spot and not target_spot in targets:
		targets.append(target_spot)
		print("[SuperEnemy] Added target_spot to targets: ", target_spot.name, " at ", target_spot.global_position)
		
	if targets.is_empty():
		push_error("[SuperEnemy] ERROR: No rocket targets found!")
		return
	
	print("[SuperEnemy] Firing ", targets.size(), " rockets from position: ", global_position)
	
	for i in range(targets.size()):
		var target = targets[i]
		print("[SuperEnemy] Creating rocket #", i, " targeting: ", target.name, " at ", target.global_position)
		
		var rocket = rocket_scene.instantiate()
		
		# Store the spawn position
		var spawn_pos = global_position
		
		# Add to parent FIRST
		get_parent().add_child(rocket)
		
		# Then set global position
		rocket.global_position = spawn_pos
		
		# Set the rocket speed
		rocket.speed = rocket_speed
		
		# Then initialize with target
		rocket.initialize(target.global_position, self)
		
		print("[SuperEnemy] Rocket #", i, " spawned at: ", rocket.global_position, 
			  " targeting: ", target.global_position,
			  " distance: ", spawn_pos.distance_to(target.global_position))

func _show_grunt_effect() -> void:
	"""Show the grunt effect above the super enemy when firing."""
	if not grunt_texture:
		return
	
	# Create a sprite for the grunt
	var grunt_sprite = Sprite2D.new()
	grunt_sprite.texture = grunt_texture
	grunt_sprite.position = grunt_offset
	# Apply base scale multiplied by start scale
	grunt_sprite.scale = Vector2.ONE * grunt_base_scale * grunt_scale_start
	grunt_sprite.z_index = 100
	grunt_sprite.modulate = Color.RED  # Start with red
	add_child(grunt_sprite)
	
	# Create tween for fade out and expansion
	var tween = grunt_sprite.create_tween()
	tween.set_parallel(true)
	
	# Calculate end scale (base scale * end scale multiplier)
	var final_scale = Vector2.ONE * grunt_base_scale * grunt_scale_end
	
	# Expand the grunt
	tween.tween_property(grunt_sprite, "scale", final_scale, grunt_fade_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Fade out the grunt (only fade alpha, preserve color)
	tween.tween_property(grunt_sprite, "modulate:a", 0.0, grunt_fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Create separate tween for color flashing (red/yellow)
	var color_tween = grunt_sprite.create_tween()
	color_tween.set_loops()  # Loop indefinitely
	# Flash to yellow
	color_tween.tween_property(grunt_sprite, "modulate", Color.YELLOW, 0.15)
	# Flash back to red
	color_tween.tween_property(grunt_sprite, "modulate", Color.RED, 0.15)
	
	# Clean up after duration
	await get_tree().create_timer(grunt_duration).timeout
	if is_instance_valid(grunt_sprite):
		grunt_sprite.queue_free()

