extends Node

signal line_changed(line: Dictionary)
signal dialogue_started(id: String)
signal dialogue_finished
signal interrupt_triggered
signal action_triggered(action_name: String)

var dialogue_data: Dictionary = {}
var current_id: String = ""
var current_priority: int = 0
var dialogue_start_time: float = 0.0
var interrupt_delay: float = 5.0  # seconds
var interrupt_unlocked := false
var interrupt_consumed := false

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

	# If we are starting a fresh non-interrupt line, allow interrupt again.
	# (Adjust this rule later if you want stricter behavior.)
	if id != "interrupt":
		interrupt_consumed = false

	var requested_priority = dialogue_data[id].get("priority", 0)

	if _is_active() and not _can_interrupt():
		return
	if _is_active() and requested_priority < current_priority:
		return

	current_priority = requested_priority
	current_id = id
	dialogue_start_time = Time.get_ticks_msec() / 1000.0
	interrupt_unlocked = false
	emit_signal("dialogue_started", id)
	_emit_current()


func advance() -> void:
	if current_id == "":
		return

	var line = dialogue_data.get(current_id)
	if line == null:
		return

	# If there are choices, don't advance automatically
	if line.has("choices") and line["choices"].size() > 0:
		return

	var next_id = line.get("next")
	if next_id != null:
		current_id = next_id
		_emit_current()
	else:
		end_conversation()

func select_choice(index: int) -> void:
	if current_id == "":
		return

	var line = dialogue_data.get(current_id)
	if line == null or not line.has("choices"):
		return

	var choices = line["choices"]
	if index < 0 or index >= choices.size():
		return

	var choice = choices[index]
	
	# Trigger action if defined
	if choice.has("action"):
		emit_signal("action_triggered", choice["action"])
	
	var next_id = choice.get("next")
	if next_id != null:
		current_id = next_id
		_emit_current()
	else:
		end_conversation()

		
func _reset() -> void:
	current_id = ""
	current_priority = 0
	dialogue_start_time = 0.0
	interrupt_unlocked = false


func can_interrupt() -> bool:
	if current_id == "":
		return false

	if interrupt_consumed:
		return false

	if interrupt_unlocked:
		return true

	if _can_interrupt():
		interrupt_unlocked = true
		return true

	return false

func do_interrupt(_id: String = "interrupt") -> void:
	# Force interrupt without checking time delay
	interrupt_consumed = true
	
	emit_signal("interrupt_triggered")
	end_conversation()
	
	# The rest of the old logic is skipped because we want to kick immediately
	# and end the text flow.
	return

#	if not dialogue_data.has(id):
#		return
#		
#	var requested_priority = dialogue_data[id].get("priority", 0)
#	
#	# Still respect priority? Usually interrupt has higher priority anyway
#	if _is_active() and requested_priority < current_priority:
#		return
#
#	current_priority = requested_priority
#	current_id = id
#	dialogue_start_time = Time.get_ticks_msec() / 1000.0
#	interrupt_unlocked = false
#	_emit_current()

func _can_interrupt() -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	return (now - dialogue_start_time) >= interrupt_delay

	
func _is_active() -> bool:
	return current_id != ""


func _emit_current() -> void:
	if not dialogue_data.has(current_id):
		return

	var line: Dictionary = dialogue_data[current_id]
	emit_signal("line_changed", line)
	
func end_conversation() -> void:
	current_id = ""
	current_priority = 0
	dialogue_start_time = 0.0
	interrupt_unlocked = false
	interrupt_consumed = false
	emit_signal("dialogue_finished")
