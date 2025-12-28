extends Control

@onready var label: RichTextLabel = $DialoguePanel/DialogueLabel
@onready var interrupt_indicator: Label = $DialoguePanel/InterruptIndicator
@onready var speaker_label: Label = $SpeakerLabel


var indicator_faded_in := false
var was_interruptable := false


func _ready():
	DialogueManager.load_dialogue("res://dialogue/dialogue.json")
	DialogueManager.line_changed.connect(_on_line_changed)
	DialogueManager.start("intro")

	interrupt_indicator.visible = false

func _on_line_changed(line: Dictionary) -> void:
	label.text = line.get("text", "")
	if speaker_label:
		speaker_label.text = line.get("speaker", "???")
	
	_reset_indicator()

	# Fade-in animation for new line
	label.modulate.a = 0.0
	create_tween().tween_property(
		label,
		"modulate:a",
		1.0,
		0.15
	)

func _process(_delta):
	if DialogueManager.can_interrupt():
		_fade_in_indicator()
		label.modulate = Color(1, 1, 1, 1.0)
	else:
		_reset_indicator()
		label.modulate = Color(1, 1, 1, 0.95)

		
func _fade_in_indicator():
	if indicator_faded_in:
		return

	#print("FADE IN")

	indicator_faded_in = true
	interrupt_indicator.visible = true
	# interrupt_indicator.text = "..." # Use text from scene
	interrupt_indicator.modulate = Color(1, 1, 1, 0)

	var tween := create_tween()
	tween.tween_property(
		interrupt_indicator,
		"modulate:a",
		1.0,
		0.4
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.finished.connect(_start_indicator_pulse)

func _reset_indicator():
	if indicator_tween:
		indicator_tween.kill()
		indicator_tween = null

	indicator_faded_in = false
	interrupt_indicator.visible = false
	interrupt_indicator.modulate.a = 0.0


func _input(event):
	if event.is_action_pressed("dialogue_interrupt"):
		if DialogueManager.can_interrupt():
			_reset_indicator()
			DialogueManager.do_interrupt("interrupt")
			return

	if event.is_action_pressed("ui_accept"):
		_reset_indicator()
		DialogueManager.advance()

		
var indicator_tween: Tween

func _start_indicator_pulse():
	if indicator_tween:
		indicator_tween.kill()

	indicator_tween = create_tween()
	indicator_tween.set_loops()

	indicator_tween.tween_property(
		interrupt_indicator,
		"modulate:a",
		0.3,
		0.6
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	indicator_tween.tween_property(
		interrupt_indicator,
		"modulate:a",
		1.0,
		0.6
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
