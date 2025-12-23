extends Node

signal line_changed(text: String)

var dialogue_data: Dictionary = {}
var current_id: String = ""
var current_priority: int = 0
var dialogue_start_time: float = 0.0
var interrupt_delay: float = 5.0  # seconds
var interrupt_unlocked := false

func load_dialogue(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	
	if parsed is Dictionary:
		dialogue_data = parsed
	else:
		push_error("Dialogue JSON is not a Dictionary")
		
func start(id: String) -> void:
	if not dialogue_data.has(id):
		return

	var requested_priority = dialogue_data[id].get("priority", 0)

	if _is_active() and not _can_interrupt():
		return

	if _is_active() and requested_priority < current_priority:
		return

	current_priority = requested_priority
	current_id = id
	dialogue_start_time = Time.get_ticks_msec() / 1000.0
	interrupt_unlocked = false 
	_emit_current()

func advance() -> void:
	if current_id == "":
		return

	var line = dialogue_data.get(current_id)
	if line == null:
		return

	var next_id = line.get("next")
	if next_id != null:
		current_id = next_id
		_emit_current()

		
func _reset() -> void:
	current_id = ""
	current_priority = 0
	dialogue_start_time = 0.0
	interrupt_unlocked = false


func can_interrupt() -> bool:
	if current_id == "":
		return false

	if interrupt_unlocked:
		return true

	if _can_interrupt():
		interrupt_unlocked = true
		return true

	return false


func _can_interrupt() -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	return (now - dialogue_start_time) >= interrupt_delay

	
func _is_active() -> bool:
	return current_id != ""


func _emit_current() -> void:
	if not dialogue_data.has(current_id):
		return

	var line: Dictionary = dialogue_data[current_id]
	emit_signal("line_changed", line["text"])
	
func end_conversation() -> void:
	current_id = ""
	current_priority = 0
	dialogue_start_time = 0.0
