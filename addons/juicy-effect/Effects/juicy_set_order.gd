extends Juicy_effect

@export var target_node : CanvasItem

@export var set_to : int = 0

func Play_Enter():
	if target_node:
		target_node.z_index = set_to
	pass

func Play_Exit():
	if target_node:
		target_node.z_index = 0
	pass

