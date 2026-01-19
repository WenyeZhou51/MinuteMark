extends Area2D

@export var speed: float = 800.0
@export var explosion_scene: PackedScene = preload("res://BigExplosion.tscn")

var target_position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var shooter: Node2D = null

func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 # Platforms and Player
	body_entered.connect(_on_body_entered)
	
	# If target was set before ready, initialize direction
	if target_position != Vector2.ZERO:
		_setup_direction()

func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO and target_position != Vector2.ZERO:
		_setup_direction()
		
	global_position += direction * speed * delta
	
	# Check if we've reached or passed the target position
	if target_position != Vector2.ZERO and global_position.distance_to(target_position) < speed * delta:
		explode()

func initialize(target: Vector2, start_shooter: Node2D) -> void:
	target_position = target
	shooter = start_shooter
	# If already in tree, setup direction now
	if is_inside_tree():
		_setup_direction()

func _setup_direction() -> void:
	direction = (target_position - global_position).normalized()
	if direction != Vector2.ZERO:
		rotation = direction.angle()

func _on_body_entered(_body: Node2D) -> void:
	explode()

func explode() -> void:
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		# Set position BEFORE adding to tree if possible, 
		# or use a method that ensures it's set before destruction logic runs.
		explosion.position = global_position
		get_parent().add_child(explosion)
		
		# If the explosion has the method, call it explicitly now that position is set
		if explosion.has_method("destroy_tiles_in_radius"):
			explosion.destroy_tiles_in_radius()
	queue_free()

