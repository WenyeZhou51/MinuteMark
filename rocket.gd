extends Area2D

signal exploded

@export var speed: float = 800.0
@export var explosion_scene: PackedScene = preload("res://BigExplosion.tscn")
@export var safe_distance_from_spawn: float = 100.0 ## Disable tile collision within this distance from super enemy

var target_position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var shooter: Node2D = null
var has_exploded: bool = false
var collision_enabled: bool = false

func _ready() -> void:
	add_to_group("super_enemy_rockets")
	collision_layer = 16
	# Start with collision DISABLED to prevent immediate explosion near super enemy
	collision_mask = 0
	body_entered.connect(_on_body_entered)
	
	print("[Rocket] Ready at position: ", global_position)
	print("[Rocket] Target position: ", target_position)
	print("[Rocket] Collision DISABLED (will enable after ", safe_distance_from_spawn, " units from spawn)")
	
	# If target was set before ready, initialize direction
	if target_position != Vector2.ZERO:
		_setup_direction()
	else:
		push_error("[Rocket] ERROR: No target position set!")

func _physics_process(delta: float) -> void:
	if has_exploded:
		return
		
	if direction == Vector2.ZERO and target_position != Vector2.ZERO:
		_setup_direction()
	
	# Check distance from shooter and enable collision when safe
	if not collision_enabled and shooter:
		var distance_from_spawn = global_position.distance_to(shooter.global_position)
		if distance_from_spawn > safe_distance_from_spawn:
			collision_mask = 1 # Enable collision with tiles and player
			collision_enabled = true
			print("[Rocket] Now ", distance_from_spawn, " units from spawn - collision ENABLED")
		
	global_position += direction * speed * delta
	
	# Check if we've reached or passed the target position
	var distance_to_target = global_position.distance_to(target_position)
	if target_position != Vector2.ZERO and distance_to_target < speed * delta * 2:
		print("[Rocket] Reached target position, exploding")
		explode()

func initialize(target: Vector2, start_shooter: Node2D) -> void:
	print("[Rocket] Initialize called with target: ", target, " from shooter: ", start_shooter.name if start_shooter else "null")
	target_position = target
	shooter = start_shooter
	# If already in tree, setup direction now
	if is_inside_tree():
		_setup_direction()

func _setup_direction() -> void:
	var old_direction = direction
	direction = (target_position - global_position).normalized()
	if direction != Vector2.ZERO:
		rotation = direction.angle()
		print("[Rocket] Direction set to: ", direction, " (angle: ", rad_to_deg(rotation), " degrees)")
		print("[Rocket] From: ", global_position, " To: ", target_position, " Distance: ", global_position.distance_to(target_position))
	else:
		push_error("[Rocket] ERROR: Direction is ZERO! Start: ", global_position, " Target: ", target_position)

func _on_body_entered(body: Node2D) -> void:
	print("[Rocket] Body entered: ", body.name, " at position: ", global_position)
	explode()

func explode() -> void:
	if has_exploded:
		print("[Rocket] Already exploded, ignoring duplicate call")
		return
	
	has_exploded = true
	emit_signal("exploded")
	print("[Rocket] EXPLODING at position: ", global_position)
	
	var tiles_destroyed = false
	var explosion_pos = global_position
	
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		
		# Set position BEFORE adding to tree (using position since it will be local to parent)
		# Calculate what the local position should be
		var parent = get_parent()
		if parent:
			# Add to parent
			parent.add_child(explosion)
			# Immediately set global position (this will be correct even in _ready)
			explosion.global_position = explosion_pos
		else:
			push_error("[Rocket] ERROR: No parent to add explosion to!")
			return
		
		print("[Rocket] Explosion spawned at: ", explosion.global_position)
		
		# If the explosion has the method, call it explicitly now that position is set
		if explosion.has_method("destroy_tiles_in_radius"):
			tiles_destroyed = explosion.destroy_tiles_in_radius()
			print("[Rocket] Explosion destroyed tiles: ", tiles_destroyed)
		else:
			push_error("[Rocket] ERROR: Explosion doesn't have destroy_tiles_in_radius method!")
	else:
		push_error("[Rocket] ERROR: No explosion scene assigned!")
	
	# If this rocket destroyed tiles, lift the speed cap immediately
	if tiles_destroyed:
		print("[Rocket] Tiles destroyed! Lifting speed cap...")
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("set_speed_cap"):
			player.set_speed_cap(false)
			print("[Rocket] Speed cap DISABLED on player")
		else:
			push_error("[Rocket] ERROR: Could not find player or set_speed_cap method!")
	else:
		print("[Rocket] No tiles destroyed, speed cap remains active")
	
	queue_free()

