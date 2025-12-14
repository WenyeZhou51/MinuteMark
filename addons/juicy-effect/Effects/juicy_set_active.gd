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
		print("[JUICY_SET_ACTIVE DEBUG] Initialize() - Node: %s, initial_state: %s, is_active: %s" % [target_node.name, initial_state, is_active])
		target_node.visible = is_active
		if also_set_process :
			target_node.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED
		print("[JUICY_SET_ACTIVE DEBUG] After Initialize() - visible: %s, process_mode: %s" % [target_node.visible, target_node.process_mode])
	pass

func Pre_Enter():
	if target_node :
		print("[JUICY_SET_ACTIVE DEBUG] Pre_Enter() - Node: %s, play_start_state: %s" % [target_node.name, play_start_state])
		if play_start_state == state.Active:
			target_node.visible = true
			if also_set_process :
				target_node.process_mode = Node.PROCESS_MODE_INHERIT
			print("[JUICY_SET_ACTIVE DEBUG] Pre_Enter() set to ACTIVE - visible: true")
		elif play_start_state == state.Inactive:
			target_node.visible = false
			if also_set_process :
				target_node.process_mode = Node.PROCESS_MODE_DISABLED
			print("[JUICY_SET_ACTIVE DEBUG] Pre_Enter() set to INACTIVE - visible: false")
		elif play_start_state == state.Toggle:
			target_node.visible = !target_node.visible
			if also_set_process :
				target_node.process_mode = Node.PROCESS_MODE_INHERIT if target_node.visible else Node.PROCESS_MODE_DISABLED
			print("[JUICY_SET_ACTIVE DEBUG] Pre_Enter() TOGGLED - visible: %s" % target_node.visible)
	pass

func Play_Exit():
	if target_node :
		print("[JUICY_SET_ACTIVE DEBUG] Play_Exit() - Node: %s, action: %s" % [target_node.name, action])
		if action == state.Active:
			target_node.visible = true
			if also_set_process :
				target_node.process_mode = Node.PROCESS_MODE_INHERIT
			print("[JUICY_SET_ACTIVE DEBUG] Play_Exit() set to ACTIVE - visible: true")
		elif action == state.Inactive:
			target_node.visible = false
			if also_set_process :
				target_node.process_mode = Node.PROCESS_MODE_DISABLED
			print("[JUICY_SET_ACTIVE DEBUG] Play_Exit() set to INACTIVE - visible: false")
		elif action == state.Toggle:
			target_node.visible = !target_node.visible
			if also_set_process :
				target_node.process_mode = Node.PROCESS_MODE_INHERIT if target_node.visible else Node.PROCESS_MODE_DISABLED
			print("[JUICY_SET_ACTIVE DEBUG] Play_Exit() TOGGLED - visible: %s" % target_node.visible)
	pass

