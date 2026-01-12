extends Juicy_effect

@export var target_node : Node

enum state {
	Active,
	Inactive,
	Toggle
}

@export var initial_state : state  ## The initial state on ready 
@export var play_start_state : state  ## state on play start
@export var action : state  ## State on play exit
@export var also_set_process : bool ## Set the process as the state as well

func Initialize():
	if target_node :
		var is_active = initial_state == state.Active
		target_node.visible = is_active
		if also_set_process :
			target_node.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED
	pass

func Pre_Enter():
	if target_node :
		if play_start_state == state.Active:
			target_node.visible = true
			if also_set_process :
				target_node.process_mode = Node.PROCESS_MODE_INHERIT
		elif play_start_state == state.Inactive:
			target_node.visible = false
			if also_set_process :
				target_node.process_mode = Node.PROCESS_MODE_DISABLED
		elif play_start_state == state.Toggle:
			target_node.visible = !target_node.visible
			if also_set_process :
				target_node.process_mode = Node.PROCESS_MODE_INHERIT if target_node.visible else Node.PROCESS_MODE_DISABLED
	pass

func Play_Exit():
	if target_node :
		if action == state.Active:
			target_node.visible = true
			if also_set_process :
				target_node.process_mode = Node.PROCESS_MODE_INHERIT
		elif action == state.Inactive:
			target_node.visible = false
			if also_set_process :
				target_node.process_mode = Node.PROCESS_MODE_DISABLED
		elif action == state.Toggle:
			target_node.visible = !target_node.visible
			if also_set_process :
				target_node.process_mode = Node.PROCESS_MODE_INHERIT if target_node.visible else Node.PROCESS_MODE_DISABLED
	pass

