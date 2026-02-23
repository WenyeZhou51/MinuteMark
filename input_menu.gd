extends "res://base_inner_menu.gd"

## Input settings menu - keyboard and gamepad rebinding

var rebinding_action = ""
var rebinding_slot = 0
var is_rebinding = false

const ACTIONS = {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
	"run": "Dash",
	"melee_attack": "Attack",
	"rewind": "Rewind"
}

func get_menu_title() -> String:
	return "INPUT SETTINGS"

func _ready():
	super._ready()
	
	if has_node("BackButton"):
		move_child($BackButton, get_child_count() - 1)
		$BackButton.mouse_filter = Control.MOUSE_FILTER_STOP
			
	for action in ACTIONS:
		var base_path = "MenuContainer/ScrollContainer/GridContainer/" + action
		var btn1 = get_node_or_null(base_path + "/RebindButton")
		var btn2 = get_node_or_null(base_path + "/RebindButton2")
		if btn1:
			btn1.pressed.connect(_on_rebind_pressed.bind(action, 0))
		if btn2:
			btn2.pressed.connect(_on_rebind_pressed.bind(action, 1))
	
	update_button_labels()

func _focus_first_control():
	var grid = get_node_or_null("MenuContainer/ScrollContainer/GridContainer")
	if grid:
		for child in grid.get_children():
			if child.has_node("RebindButton"):
				child.get_node("RebindButton").grab_focus()
				return
	
	if has_node("BackButton"):
		var back_btn = $BackButton
		back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		back_btn.grab_focus()

const MAX_BUTTON_FONT_SIZE = 50
const MIN_BUTTON_FONT_SIZE = 12
const BUTTON_PADDING = 20

func update_button_labels():
	for action in ACTIONS:
		var base_path = "MenuContainer/ScrollContainer/GridContainer/" + action
		var btn1 = get_node_or_null(base_path + "/RebindButton")
		var btn2 = get_node_or_null(base_path + "/RebindButton2")
		var events = _get_bindable_events(action)
		if btn1:
			btn1.text = _event_to_text(events[0]) if events.size() > 0 else "None"
			_fit_button_font(btn1)
		if btn2:
			btn2.text = _event_to_text(events[1]) if events.size() > 1 else "None"
			_fit_button_font(btn2)

func _fit_button_font(button: Button):
	var font = button.get_theme_font("font")
	var available_width = button.custom_minimum_size.x - BUTTON_PADDING
	var font_size = MAX_BUTTON_FONT_SIZE
	while font_size > MIN_BUTTON_FONT_SIZE:
		var text_size = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		if text_size.x <= available_width:
			break
		font_size -= 2
	button.add_theme_font_size_override("font_size", font_size)

func _get_bindable_events(action: String) -> Array:
	var result = []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey or e is InputEventJoypadButton or e is InputEventJoypadMotion:
			result.append(e)
			if result.size() >= 2:
				break
	return result

func _event_to_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var keycode = event.physical_keycode if event.physical_keycode else event.keycode
		return OS.get_keycode_string(keycode)
	elif event is InputEventJoypadButton:
		return "Joy Button " + str(event.button_index)
	elif event is InputEventJoypadMotion:
		return "Joy Axis " + str(event.axis) + ("+" if event.axis_value > 0 else "-")
	return event.as_text().replace(" (Physical)", "")

func _input(event):
	if is_rebinding:
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			if (event is InputEventKey and event.pressed) or \
			   (event is InputEventJoypadButton and event.pressed) or \
			   (event is InputEventJoypadMotion and abs(event.axis_value) > 0.5):
				rebind_action(rebinding_action, rebinding_slot, event)
				get_viewport().set_input_as_handled()
				return
	
	if event is InputEventMouseButton and event.pressed:
		pass
		
	super._input(event)

func start_rebind(action: String, slot: int):
	if is_rebinding: return
	
	rebinding_action = action
	rebinding_slot = slot
	is_rebinding = true
	
	var button_name = "RebindButton" if slot == 0 else "RebindButton2"
	var button_node = get_node_or_null("MenuContainer/ScrollContainer/GridContainer/" + action + "/" + button_name)
	if button_node:
		button_node.text = "???"
		_fit_button_font(button_node)

func rebind_action(action: String, slot: int, event: InputEvent):
	var events = _get_bindable_events(action)
	
	if slot < events.size():
		InputMap.action_erase_event(action, events[slot])
	
	InputMap.action_add_event(action, event)
	
	is_rebinding = false
	rebinding_action = ""
	rebinding_slot = 0
	update_button_labels()
	
	var button_name = "RebindButton" if slot == 0 else "RebindButton2"
	var button_node = get_node_or_null("MenuContainer/ScrollContainer/GridContainer/" + action + "/" + button_name)
	if button_node:
		button_node.grab_focus()

func _on_rebind_pressed(action: String, slot: int):
	start_rebind(action, slot)
