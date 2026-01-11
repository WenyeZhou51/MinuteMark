extends Control

@onready var label: RichTextLabel = $MainLayout/ContentHBox/DialoguePanel/TextMargin/VBoxContainer/DialogueLabel
@onready var speaker_label: Label = $MainLayout/ContentHBox/DialoguePanel/SpeakerContainer/SpeakerBox/SpeakerLabel
@onready var portrait: TextureRect = $MainLayout/ContentHBox/PortraitContainer/Portrait
@onready var interrupt_indicator: Button = $InterruptIndicator

@export var style_red: StyleBoxFlat
@export var style_green: StyleBoxFlat

var indicator_faded_in := false
var was_interruptable := false
var typewriter_tween: Tween
var portrait_tween: Tween
var indicator_tween: Tween
var current_line: Dictionary = {}

# Map speaker names to textures
# In a real game, you'd have different images for each character
var portraits = {
	"Boss": preload("res://dialogue/protag.png"),
	"Player": preload("res://dialogue/protag.png"), 
	"Stranger": preload("res://dialogue/protag.png"),
	"???": preload("res://dialogue/protag.png")
}

func _ready():
	DialogueManager.load_dialogue("res://dialogue/dialogue.json")
	DialogueManager.line_changed.connect(_on_line_changed)
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	interrupt_indicator.pressed.connect(_on_interrupt_indicator_pressed)
	
	# Initial hide
	modulate.a = 0.0

func _on_dialogue_started(_id: String) -> void:
	visible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

func _on_dialogue_finished() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	# tween.finished.connect(queue_free) # Don't free, we might need it again

func _on_line_changed(line: Dictionary) -> void:
	if not line:
		return
		
	current_line = line
	var text = line.get("text", "")
	var speaker = line.get("speaker", "???")
	
	# Determine if speaker changed
	var speaker_changed = (speaker != speaker_label.text)
	
	# Update text content immediately (it's hidden by visible_ratio anyway)
	label.text = text
	if speaker_label:
		speaker_label.text = speaker
		
	# Update portrait with transition
	if portrait:
		var target_texture = portraits["???"]
		if portraits.has(speaker):
			target_texture = portraits[speaker]
			
		if speaker_changed:
			_animate_portrait_switch(target_texture)
		else:
			# Same speaker, maybe just ensure texture is right and small bounce
			if portrait.texture != target_texture:
				portrait.texture = target_texture
			_animate_portrait_pop() # Just the pop
	
	# _reset_indicator() # Don't reset, we want it to stay for the new line or transition

	# Typewriter effect
	label.visible_ratio = 0.0
	label.modulate.a = 1.0
	
	if typewriter_tween:
		typewriter_tween.kill()
	
	typewriter_tween = create_tween()
	var duration = label.get_total_character_count() * 0.05
	
	# Force show interrupt button immediately for new line
	interrupt_indicator.visible = true
	# If it was hidden or fading out, bring it back
	if interrupt_indicator.modulate.a < 1.0:
		var fade_in = create_tween()
		fade_in.tween_property(interrupt_indicator, "modulate:a", 1.0, 0.2)
	
	if speaker == "Boss":
		interrupt_indicator.text = "F OFF [Enter]"
		interrupt_indicator.add_theme_stylebox_override("normal", style_red)
		interrupt_indicator.add_theme_stylebox_override("hover", style_red) # Keep red on hover while in F OFF
		indicator_faded_in = true # Mark as visible so pulse can start if needed
	else:
		interrupt_indicator.text = "..."
		interrupt_indicator.add_theme_stylebox_override("normal", style_red) # Use red for "busy/typing"
		interrupt_indicator.add_theme_stylebox_override("hover", style_red)
		indicator_faded_in = true

	# Slight delay before typing starts if speaker changed, for clarity
	if speaker_changed:
		typewriter_tween.tween_interval(0.15)

	typewriter_tween.tween_property(
		label,
		"visible_ratio",
		1.0,
		duration
	)
	
	# Update button text when typing finishes
	typewriter_tween.finished.connect(_on_typing_finished)

func _on_typing_finished() -> void:
	var speaker = current_line.get("speaker", "???")
	var next_id = current_line.get("next")
	
	interrupt_indicator.add_theme_stylebox_override("normal", style_green)
	interrupt_indicator.add_theme_stylebox_override("hover", style_green)
	
	if speaker == "Boss":
		interrupt_indicator.text = "THANK YOU [Enter]"
	else:
		if next_id == null:
			interrupt_indicator.text = "LEAVE [Enter]"
		else:
			interrupt_indicator.text = "NEXT [Enter]"

func _animate_portrait_switch(new_texture: Texture2D):
	if portrait_tween:
		portrait_tween.kill()
		
	# Center pivot for scaling
	portrait.pivot_offset = portrait.size / 2
	
	portrait_tween = create_tween()
	
	# Fade out
	portrait_tween.tween_property(portrait, "modulate:a", 0.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Swap texture
	portrait_tween.tween_callback(func(): portrait.texture = new_texture)
	
	# Fade in and pop
	portrait.scale = Vector2(0.9, 0.9)
	portrait_tween.parallel().tween_property(portrait, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	portrait_tween.parallel().tween_property(portrait, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_portrait_pop():
	if portrait_tween:
		portrait_tween.kill()
	
	portrait.pivot_offset = portrait.size / 2
	portrait.scale = Vector2(0.95, 0.95)
	
	portrait_tween = create_tween()
	portrait_tween.tween_property(portrait, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Removed old _animate_portrait

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
	# Allow keyboard interaction same as clicking the button (Enter only)
	if visible and indicator_faded_in and interrupt_indicator.visible:
		if event.is_action_pressed("ui_accept"):
			_on_interrupt_indicator_pressed()
			get_viewport().set_input_as_handled()

func _on_interrupt_indicator_pressed() -> void:
	# "F OFF" state (typing not done) -> Interrupt
	if label.visible_ratio < 1.0:
		if speaker_label.text == "Boss":
			_reset_indicator()
			DialogueManager.do_interrupt()
		else:
			# Skip typing for non-boss
			if typewriter_tween:
				typewriter_tween.kill()
			label.visible_ratio = 1.0
			_on_typing_finished()
			
	# "THANK YOU" / "NEXT" / "LEAVE" state (typing done) -> Advance normally
	else:
		_reset_indicator()
		DialogueManager.advance()

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
