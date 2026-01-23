extends Node2D

signal rocket_created(rocket)

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
@export var grunt_offset: Vector2 = Vector2(-300, -80) ## Offset of the grunt relative to super enemy
@export var grunt_base_scale: float = 1.0 ## Base scale multiplier for the grunt size
@export var grunt_duration: float = 1.0 ## Duration the grunt lasts (seconds)
@export var grunt_fade_duration: float = 0.8 ## Duration of the fade out effect (seconds)
@export var grunt_scale_start: Vector2 = Vector2(0.3, 0.3) ## Starting scale of the grunt
@export var grunt_scale_end: Vector2 = Vector2(0.5, 0.5) ## Ending scale of the grunt (expansion)

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
		
		emit_signal("rocket_created", rocket)
		
		print("[SuperEnemy] Rocket #", i, " spawned at: ", rocket.global_position, 
			  " targeting: ", target.global_position,
			  " distance: ", spawn_pos.distance_to(target.global_position))

func _show_grunt_effect() -> void:
	"""Show the grunt effect above the super enemy when firing."""
	if not grunt_texture: return
	
	var grunt = Sprite2D.new()
	grunt.texture = grunt_texture
	grunt.position = grunt_offset
	grunt.scale = grunt_scale_start
	grunt.modulate.a = 0.0
	add_child(grunt)
	
	# Animate appearance
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(grunt, "modulate:a", 1.0, 0.2)
	tween.tween_property(grunt, "scale", grunt_scale_end, grunt_duration)
	
	# Animate disappearance after duration
	tween.chain().tween_property(grunt, "modulate:a", 0.0, grunt_fade_duration)
	tween.tween_callback(grunt.queue_free)

func speak(text: String, duration: float = 2.0) -> void:
	if not grunt_texture:
		push_warning("[SuperEnemy] No grunt_texture assigned for speak()!")
		return
		
	# Create a sprite for the grunt instead of a Label
	var grunt_sprite = Sprite2D.new()
	grunt_sprite.texture = grunt_texture
	grunt_sprite.position = grunt_offset
	# Apply base scale multiplied by start scale
	grunt_sprite.scale = Vector2.ONE * grunt_base_scale * grunt_scale_start
	grunt_sprite.z_index = 100
	grunt_sprite.modulate.a = 0.0 # Start invisible
	add_child(grunt_sprite)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade in
	tween.tween_property(grunt_sprite, "modulate:a", 1.0, 0.2)
	
	# Calculate final scale
	var final_scale = Vector2.ONE * grunt_base_scale * grunt_scale_end
	
	# Expand slightly while visible
	tween.tween_property(grunt_sprite, "scale", final_scale, 0.3)
	
	# Chain a fade out after the duration
	tween.chain().tween_interval(duration) 
	tween.tween_property(grunt_sprite, "modulate:a", 0.0, 0.5)
	
	tween.tween_callback(grunt_sprite.queue_free)

func stop_speaking() -> void:
	for child in get_children():
		if child is Sprite2D and child.texture == grunt_texture:
			var tween = create_tween()
			tween.tween_property(child, "modulate:a", 0.0, 0.2)
			tween.tween_callback(child.queue_free)
