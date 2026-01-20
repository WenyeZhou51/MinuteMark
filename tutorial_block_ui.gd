extends Control

## UI component for displaying tutorial block instructions

@onready var label: Label = $Label

var fade_tween: Tween

func _ready() -> void:
	# Hide initially
	modulate.a = 0.0
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_message(message: String) -> void:
	label.text = message
	_fade_in()

func hide_message() -> void:
	_fade_out()

func _fade_in() -> void:
	visible = true
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # Allow tweening while paused
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _fade_out() -> void:
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # Allow tweening while paused
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade_tween.finished.connect(func(): visible = false)
