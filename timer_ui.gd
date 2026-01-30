extends CanvasLayer

signal time_expired

@onready var timer_label: Label = $Control/TimerBackground/TimerLabel

@export_group("Font Settings")
@export var custom_font: Font
@export var font_size: int = 180
@export var font_color: Color = Color.WHITE
@export var outline_color: Color = Color.BLACK
@export var outline_size: int = 8
@export var shadow_color: Color = Color(1, 0, 1, 1)
@export var shadow_offset: Vector2 = Vector2(5, 10)

var current_time: float = 0.0
var max_time: float = 300.0
var is_running: bool = false
var dialogue_slow_mode: bool = false

func _ready() -> void:
	# Ensure TimerUI runs even when the game is paused (e.g. during dialogue)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Add to group for LevelState access
	add_to_group("timer_ui")
	
	_apply_font_settings()
	
	# Listen for dialogue events to handle slow-down logic
	if DialogueManager:
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
		DialogueManager.dialogue_finished.connect(_on_dialogue_finished)

func _apply_font_settings() -> void:
	if not timer_label:
		return
	
	if custom_font:
		timer_label.add_theme_font_override("font", custom_font)
	
	if font_size > 0:
		timer_label.add_theme_font_size_override("font_size", font_size)
		
	timer_label.add_theme_color_override("font_color", font_color)
	timer_label.add_theme_color_override("font_outline_color", outline_color)
	timer_label.add_theme_constant_override("outline_size", outline_size)
	timer_label.add_theme_color_override("font_shadow_color", shadow_color)
	timer_label.add_theme_constant_override("shadow_offset_x", int(shadow_offset.x))
	timer_label.add_theme_constant_override("shadow_offset_y", int(shadow_offset.y))

func setup_timer(duration: float) -> void:
	max_time = duration
	current_time = duration
	is_running = true
	update_display(current_time)

func reset_timer() -> void:
	setup_timer(max_time)

func stop_timer() -> void:
	is_running = false

func add_time(amount: float) -> void:
	current_time += amount
	update_display(current_time)

func _process(delta: float) -> void:
	if not is_running:
		return
		
	# Check for tutorial freeze first
	if TutorialBlockManager and TutorialBlockManager.has_method("get_is_tutorial_active"):
		if TutorialBlockManager.get_is_tutorial_active():
			return

	var dt = delta
	
	if get_tree().paused:
		if dialogue_slow_mode:
			# If paused due to dialogue, timer proceeds at 1/2 speed
			dt *= 0.5
		else:
			# Paused for other reasons (e.g. pause menu) -> Stop timer
			return
			
	current_time -= dt
	
	if current_time <= 0:
		current_time = 0
		is_running = false
		time_expired.emit()
	
	update_display(current_time)

func update_display(display_time: float) -> void:
	if not timer_label:
		return
	
	var total_seconds = max(0, display_time)
	var seconds = int(total_seconds)
	var centiseconds = int((total_seconds - seconds) * 100)
	
	timer_label.text = "%02d:%02d" % [seconds, centiseconds]

func _on_dialogue_started(_id: String) -> void:
	dialogue_slow_mode = true

func _on_dialogue_finished() -> void:
	dialogue_slow_mode = false
