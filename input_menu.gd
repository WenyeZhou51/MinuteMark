extends "res://base_inner_menu.gd"

## Input settings menu - keyboard and gamepad rebinding

var rebinding_action = ""
var is_rebinding = false

const ACTIONS = {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"move_up": "Move Up",
	"move_down": "Move Down",
	"jump": "Jump",
	"run": "Dash",
	"melee_attack": "Attack",
	"rewind": "Rewind"
}

func get_menu_title() -> String:
	return "INPUT SETTINGS"

func _ready():
	super._ready()
	
	# Ensure BackButton is on top of MenuContainer so it receives input and hover events
	if has_node("BackButton"):
		# Move to end of child list (draw on top)
		move_child($BackButton, get_child_count() - 1)
		# Explicitly set mouse filter to STOP just in case
		$BackButton.mouse_filter = Control.MOUSE_FILTER_STOP
			
	# Setup button labels and signals
	for action in ACTIONS:
		var button_node = get_node_or_null("MenuContainer/ScrollContainer/GridContainer/" + action + "/RebindButton")
		if button_node:
			button_node.pressed.connect(_on_rebind_pressed.bind(action))
	
	update_button_labels()

func _focus_first_control():
	"""Focus the first focusable control in the menu"""
	# In input menu, the first rebind button is deep inside the grid
	var grid = get_node_or_null("MenuContainer/ScrollContainer/GridContainer")
	if grid:
		for child in grid.get_children():
			if child.has_node("RebindButton"):
				child.get_node("RebindButton").grab_focus()
				return
	
	# Fallback to back button
	if has_node("BackButton"):
		# Ensure Back button is focusable
		var back_btn = $BackButton
		back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		back_btn.grab_focus()

func update_button_labels():
	for action in ACTIONS:
		var button_node = get_node_or_null("MenuContainer/ScrollContainer/GridContainer/" + action + "/RebindButton")
		if button_node:
			button_node.text = get_action_text(action)

func get_action_text(action: String) -> String:
	var events = InputMap.action_get_events(action)
	if events.size() > 0:
		# Find the first key event for display, or first joypad event if no key
		var display_event = events[0]
		for e in events:
			if e is InputEventKey:
				display_event = e
				break
		
		if display_event is InputEventKey:
			var keycode = display_event.physical_keycode if display_event.physical_keycode else display_event.keycode
			return OS.get_keycode_string(keycode)
		elif display_event is InputEventJoypadButton:
			return "Joy Button " + str(display_event.button_index)
		elif display_event is InputEventJoypadMotion:
			return "Joy Axis " + str(display_event.axis) + ("+" if display_event.axis_value > 0 else "-")
		
		return display_event.as_text().replace(" (Physical)", "")
	return "None"

func _input(event):
	if is_rebinding:
		if event is InputEventKey or (event is InputEventJoypadButton) or (event is InputEventJoypadMotion):
			# Handle key release or motion
			if (event is InputEventKey and event.pressed) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.5):
				
				# Ignore Esc for rebinding to allow it as a "Cancel" action if needed?
				# But for now, allow binding anything.
				# If user clicks mouse, we should probably ignore it for rebind unless we support mouse buttons.
				
				rebind_action(rebinding_action, event)
				get_viewport().set_input_as_handled()
				return
	
	# Explicitly handle mouse click on Back button if focusing is weird
	if event is InputEventMouseButton and event.pressed:
		# Just let standard GUI handling work first by NOT consuming it here
		# unless it's a rebind action.
		# The parent's _input might consume it though?
		# No, base_inner_menu only consumes "ui_cancel".
		pass
		
	super._input(event)

func start_rebind(action: String):
	if is_rebinding: return
	
	rebinding_action = action
	is_rebinding = true
	
	# Update button text to show we are waiting for input
	var button_node = get_node_or_null("MenuContainer/ScrollContainer/GridContainer/" + action + "/RebindButton")
	if button_node:
		button_node.text = "???"

func rebind_action(action: String, event: InputEvent):
	# Clear existing events for this action type
	var events = InputMap.action_get_events(action)
	for e in events:
		if (e is InputEventKey and event is InputEventKey) or \
		   (e is InputEventJoypadButton and event is InputEventJoypadButton) or \
		   (e is InputEventJoypadMotion and event is InputEventJoypadMotion):
			InputMap.action_erase_event(action, e)
	
	InputMap.action_add_event(action, event)
	
	is_rebinding = false
	rebinding_action = ""
	update_button_labels()
	
	# Focus the button back
	var button_node = get_node_or_null("MenuContainer/ScrollContainer/GridContainer/" + action + "/RebindButton")
	if button_node:
		button_node.grab_focus()

func _on_rebind_pressed(action: String):
	start_rebind(action)

