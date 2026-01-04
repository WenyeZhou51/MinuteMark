extends Control

@onready var label: RichTextLabel = $DialoguePanel/HBoxContainer/VBoxContainer/DialogueLabel
@onready var speaker_label: Label = $DialoguePanel/HBoxContainer/VBoxContainer/SpeakerLabel
@onready var portrait: TextureRect = $DialoguePanel/HBoxContainer/PortraitContainer/Portrait
@onready var interrupt_indicator: Button = $InterruptIndicator

@export var style_red: StyleBoxFlat
@export var style_green: StyleBoxFlat

var indicator_faded_in := false
var was_interruptable := false
var typewriter_tween: Tween
var portrait_tween: Tween
var indicator_tween: Tween

# Map speaker names to textures
# In a real game, you'd have different images for each character
var portraits = {
	"Boss": preload("res://Sprites/New bob.png"),
	"Player": preload("res://Sprites/New bob.png"), 
	"Stranger": preload("res://Sprites/New bob.png"),
	"???": preload("res://Sprites/New bob.png")
}

func _ready():
	DialogueManager.load_dialogue("res://dialogue/dialogue.json")
	DialogueManager.line_changed.connect(_on_line_changed)
	interrupt_indicator.pressed.connect(_on_interrupt_indicator_pressed)
	
	# Initial hide
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

	DialogueManager.start("intro")

func _on_line_changed(line: Dictionary) -> void:
	label.text = line.get("text", "")
	var speaker = line.get("speaker", "???")
	
	if speaker_label:
		speaker_label.text = speaker
		
	# Update portrait
	if portrait:
		if portraits.has(speaker):
			portrait.texture = portraits[speaker]
		else:
			portrait.texture = portraits["???"]
			
		_animate_portrait()
	
	# _reset_indicator() # Don't reset, we want it to stay for the new line or transition

	# Typewriter effect
	label.visible_ratio = 0.0
	label.modulate.a = 1.0
	
	if typewriter_tween:
		typewriter_tween.kill()
	
	typewriter_tween = create_tween()
	var duration = label.get_total_character_count() * 0.05
	
	# Force show interrupt button immediately for new line
	
	if speaker == "Boss":
		interrupt_indicator.visible = true
		# If it was hidden or fading out, bring it back
		if interrupt_indicator.modulate.a < 1.0:
			var fade_in = create_tween()
			fade_in.tween_property(interrupt_indicator, "modulate:a", 1.0, 0.2)
		
		interrupt_indicator.text = "F OFF"
		interrupt_indicator.add_theme_stylebox_override("normal", style_red)
		interrupt_indicator.add_theme_stylebox_override("hover", style_red) # Keep red on hover while in F OFF
		
		indicator_faded_in = true # Mark as visible so pulse can start if needed
	else:
		interrupt_indicator.visible = false
		indicator_faded_in = false

	typewriter_tween.tween_property(
		label,
		"visible_ratio",
		1.0,
		duration
	)
	
	# Update button text when typing finishes
	typewriter_tween.finished.connect(func(): 
		if speaker == "Boss":
			interrupt_indicator.text = "THANK YOU"
			interrupt_indicator.add_theme_stylebox_override("normal", style_green)
			interrupt_indicator.add_theme_stylebox_override("hover", style_green)
	)

func _animate_portrait():
	if portrait_tween:
		portrait_tween.kill()
	
	# Center pivot for scaling
	portrait.pivot_offset = portrait.size / 2
	
	portrait.scale = Vector2(0.9, 0.9)
	portrait.modulate = Color(0.8, 0.8, 0.8, 1.0)
	
	portrait_tween = create_tween()
	portrait_tween.set_parallel(true)
	portrait_tween.tween_property(portrait, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	portrait_tween.tween_property(portrait, "modulate", Color(1, 1, 1, 1), 0.3)

func _process(_delta):
	# Removed interrupt check here to manually control visibility
	pass
		
func _fade_in_indicator():
	if indicator_faded_in:
		return

	indicator_faded_in = true
	interrupt_indicator.visible = true
	# Don't reset alpha if it's already visible, just ensure it fades in
	if interrupt_indicator.modulate.a < 0.1:
		interrupt_indicator.modulate.a = 0.0

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


func _unhandled_input(event):
	if event.is_action_pressed("ui_accept"):
		if label.visible_ratio < 1.0:
			# Skip typewriter if pressed while typing
			if typewriter_tween:
				typewriter_tween.kill()
			label.visible_ratio = 1.0
			
			if speaker_label.text == "Boss":
				interrupt_indicator.text = "THANK YOU" # Ensure text updates on skip
				interrupt_indicator.add_theme_stylebox_override("normal", style_green)
				interrupt_indicator.add_theme_stylebox_override("hover", style_green)
		else:
			_reset_indicator()
			DialogueManager.advance()

func _on_interrupt_indicator_pressed() -> void:
	# "F OFF" state (typing not done) -> Interrupt
	if label.visible_ratio < 1.0:
		_reset_indicator()
		DialogueManager.do_interrupt()
	# "THANK YOU" state (typing done) -> Interrupt (also)
	else:
		_reset_indicator()
		DialogueManager.do_interrupt()

func _start_indicator_pulse():
	if indicator_tween:
		indicator_tween.kill()

	indicator_tween = create_tween()
	indicator_tween.set_loops()

	indicator_tween.tween_property(
		interrupt_indicator,
		"modulate:a",
		0.5, # Don't fade out completely
		0.6
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	indicator_tween.tween_property(
		interrupt_indicator,
		"modulate:a",
		1.0,
		0.6
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
