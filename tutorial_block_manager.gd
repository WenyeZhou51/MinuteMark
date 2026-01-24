extends Node

## Singleton for managing tutorial block state and completion tracking

var tutorial_ui_scene = preload("res://TutorialBlockUI.tscn")
var tutorial_ui_instance: Control

# Track completed tutorial block IDs
var completed_blocks: Dictionary = {}

# Current tutorial state
var is_tutorial_active: bool = false
var current_allowed_action: String = ""
var current_block_id: String = ""

# Map block IDs to TutorialBlock instances for chaining
var registered_blocks: Dictionary = {}

signal tutorial_started(block_id: String, action: String, message: String)
signal tutorial_ended(block_id: String)

func register_block(block_id: String, node: Node) -> void:
	registered_blocks[block_id] = node

func _ready() -> void:
	# Create a CanvasLayer to hold the tutorial UI
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 101 # Higher than TutorialUI (100) to be on top
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS # Allow UI to work while paused
	add_child(canvas_layer)
	
	tutorial_ui_instance = tutorial_ui_scene.instantiate()
	tutorial_ui_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas_layer.add_child(tutorial_ui_instance)
	
	# Set process mode so we can process input during tutorial pause
	process_mode = Node.PROCESS_MODE_ALWAYS

func is_block_completed(block_id: String) -> bool:
	"""Check if a tutorial block has been completed."""
	return completed_blocks.has(block_id) and completed_blocks[block_id] == true

func get_is_tutorial_active() -> bool:
	"""Get whether a tutorial is currently active."""
	return is_tutorial_active

func complete_block(block_id: String) -> void:
	"""Mark a tutorial block as completed."""
	completed_blocks[block_id] = true

func reset_tutorials() -> void:
	"""Reset all tutorial state - clears completed blocks and current tutorial."""
	completed_blocks.clear()
	
	# If a tutorial is currently active, end it
	if is_tutorial_active:
		# Hide tutorial UI
		if tutorial_ui_instance:
			tutorial_ui_instance.hide_message()
		
		# Get player reference and unlock actions
		var player = get_tree().get_first_node_in_group("player")
		if player:
			# Unlock actions
			if player.has_method("set_tutorial_lock"):
				player.set_tutorial_lock(false, "")
		
		# Reset state variables
		is_tutorial_active = false
		current_allowed_action = ""
		current_block_id = ""
	
	print("TutorialBlockManager: All tutorials reset")

func start_tutorial(block_id: String, allowed_action: String, message: String) -> void:
	"""Start a tutorial block - freeze player position, lock actions, freeze timer, show UI."""
	print("TutorialBlockManager: start_tutorial called for block: ", block_id)
	
	if is_tutorial_active:
		push_warning("TutorialBlockManager: Attempted to start tutorial while one is already active")
		return
	
	is_tutorial_active = true
	current_allowed_action = allowed_action
	current_block_id = block_id
	
	# Get player reference
	var player = get_tree().get_first_node_in_group("player")
	print("TutorialBlockManager: Player found: ", player != null)
	
	# Check if player is in rewind before canceling (to know if we need to fix time scale)
	var was_in_rewind = false
	if player and "is_rewind_holding" in player:
		was_in_rewind = player.is_rewind_holding or player.is_rewind_tracing
	
	print("TutorialBlockManager: Was in rewind: ", was_in_rewind)
	
	# Cancel rewind FIRST if player is in rewind state
	# This ensures rewind is fully cleaned up
	if player and player.has_method("cancel_rewind_and_set_cooldown"):
		player.cancel_rewind_and_set_cooldown()
	
	# Only reset time scale if rewind was active (to avoid interfering with other systems)
	if was_in_rewind:
		Engine.time_scale = 1.0
	
	# Freeze player position by setting velocity to zero
	if player and "velocity" in player:
		player.velocity = Vector2.ZERO
		print("TutorialBlockManager: Frozen player position")
	
	# Show tutorial UI
	if tutorial_ui_instance:
		tutorial_ui_instance.show_message(message)
		print("TutorialBlockManager: Showed tutorial UI")
	
	# Notify player to lock actions
	if player and player.has_method("set_tutorial_lock"):
		player.set_tutorial_lock(true, allowed_action)
		print("TutorialBlockManager: Set tutorial lock on player")
	
	tutorial_started.emit(block_id, allowed_action, message)
	print("TutorialBlockManager: Tutorial started successfully")

func end_tutorial() -> void:
	"""End the current tutorial - unfreeze player position, unlock actions, unfreeze timer, hide UI."""
	if not is_tutorial_active:
		return
	
	var block_id = current_block_id
	
	# Mark block as completed
	if block_id != "":
		complete_block(block_id)
	
	# Hide tutorial UI
	if tutorial_ui_instance:
		tutorial_ui_instance.hide_message()
	
	# Get player reference
	var player = get_tree().get_first_node_in_group("player")
	
	# Notify player to unlock actions
	if player and player.has_method("set_tutorial_lock"):
		player.set_tutorial_lock(false, "")
	
	# Reset state
	is_tutorial_active = false
	current_allowed_action = ""
	current_block_id = ""
	
	tutorial_ended.emit(block_id)

func switch_to_tutorial(target_block_id: String) -> void:
	"""Switch directly to another tutorial block without unpausing."""
	if not registered_blocks.has(target_block_id):
		push_error("TutorialBlockManager: Cannot switch to unknown block " + target_block_id)
		end_tutorial()
		return
		
	var target_block = registered_blocks[target_block_id]
	if not target_block:
		end_tutorial()
		return
		
	# Complete current block
	if current_block_id != "":
		complete_block(current_block_id)
		tutorial_ended.emit(current_block_id)
	
	# Start new block
	current_block_id = target_block_id
	current_allowed_action = target_block.allowed_action
	
	# Show new message
	if tutorial_ui_instance:
		tutorial_ui_instance.show_message(target_block.instruction_message)
	
	# Update player lock
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_tutorial_lock"):
		player.set_tutorial_lock(true, current_allowed_action)
		
	print("TutorialBlockManager: Switched to block: ", current_block_id)
	tutorial_started.emit(current_block_id, current_allowed_action, target_block.instruction_message)

func _process(_delta: float) -> void:
	"""Process input during tutorial to detect allowed actions."""
	if not is_tutorial_active:
		return
	
	# Check for allowed action input
	match current_allowed_action:
		"rewind":
			if Input.is_action_just_pressed("rewind"):
				check_action_performed("rewind")
		"dash":
			if Input.is_action_just_pressed("run"):
				check_action_performed("dash")
		"jump":
			if Input.is_action_just_pressed("jump"):
				check_action_performed("jump")
		"kick":
			if Input.is_action_just_pressed("melee_attack"):
				check_action_performed("kick")
		"slam":
			if Input.is_action_just_pressed("move_down"):
				check_action_performed("slam")
		"move":
			var input_vec = Vector2(
				Input.get_axis("move_left", "move_right"),
				Input.get_axis("move_up", "move_down")
			)
			if input_vec.length() > 0.1:  # Dead zone check
				check_action_performed("move")
		"turn_left":
			if Input.is_action_pressed("move_left"):
				# Manually flip player
				var player = get_tree().get_first_node_in_group("player")
				if player and "facing_direction" in player:
					player.facing_direction = -1
					if player.has_method("_update_animations"):
						player._update_animations()
				check_action_performed("turn_left")
		"turn_right":
			if Input.is_action_pressed("move_right"):
				# Manually flip player
				var player = get_tree().get_first_node_in_group("player")
				if player and "facing_direction" in player:
					player.facing_direction = 1
					if player.has_method("_update_animations"):
						player._update_animations()
				check_action_performed("turn_right")

func check_action_performed(action: String) -> bool:
	"""Check if the allowed action was performed. Called by player or _process."""
	if not is_tutorial_active:
		return false
	
	# If this is the expected action
	if action == current_allowed_action or (current_allowed_action == "move" and action in ["move_left", "move_right", "move_up", "move_down"]):
		print("TutorialBlockManager: Action performed: ", action)
		
		# Check if current block has a next block
		var current_block = registered_blocks.get(current_block_id)
		if current_block and "next_tutorial_block_id" in current_block and current_block.next_tutorial_block_id != "":
			switch_to_tutorial(current_block.next_tutorial_block_id)
		else:
			end_tutorial()
		return true
		
	return false
