extends Node2D

@export var rocket_scene: PackedScene = preload("res://Rocket.tscn")
@export var target_spot: Node2D # A Marker2D or other node to aim at

func fire_at_target() -> void:
	if not rocket_scene: return
	if not target_spot:
		push_warning("SuperEnemy: No target_spot assigned!")
		return
		
	var rocket = rocket_scene.instantiate()
	# Set position BEFORE adding to tree so global_position is ready for _ready()
	rocket.global_position = global_position
	# Set target BEFORE adding to tree
	rocket.initialize(target_spot.global_position, self)
	
	get_parent().add_child(rocket)
	
	print("SuperEnemy: Rocket fired from ", rocket.global_position, " at ", target_spot.global_position)

