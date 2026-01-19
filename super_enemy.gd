extends Node2D

@export var rocket_scene: PackedScene = preload("res://Rocket.tscn")
@export var target_spot: Node2D # A Marker2D or other node to aim at

func fire_at_target() -> void:
	if not rocket_scene: return
	
	# Find all rocket targets - can be nodes in the "rocket_target" group
	# or the specifically assigned target_spot
	var targets = get_tree().get_nodes_in_group("rocket_target")
	
	# Add the specifically assigned target if it's not already in the group
	if target_spot and not target_spot in targets:
		targets.append(target_spot)
		
	if targets.is_empty():
		push_warning("SuperEnemy: No rocket targets found!")
		return
		
	for target in targets:
		var rocket = rocket_scene.instantiate()
		# Set position BEFORE adding to tree so global_position is ready for _ready()
		rocket.global_position = global_position
		# Set target BEFORE adding to tree
		rocket.initialize(target.global_position, self)
		get_parent().add_child(rocket)

