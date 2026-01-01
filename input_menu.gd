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
	
	# Setup button labels and signals
	for action in ACTIONS:
		var button_node = get_node_or_null("MenuContainer/ScrollContainer/GridContainer/" + action + "/RebindButton")
		if button_node:
			button_node.pressed.connect(_on_rebind_pressed.bind(action))
	
	update_button_labels()

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
				# Actually, let's just let them rebind anything. 
				
				rebind_action(rebinding_action, event)
				get_viewport().set_input_as_handled()
				return
	
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

