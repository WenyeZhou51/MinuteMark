extends CanvasLayer

signal time_expired

@onready var timer_label: Label = $Control/TimerContainer/TimerLabel
@onready var rank_indicator: Label = $Control/TimerContainer/RankIndicator
@onready var timer_fill: TextureRect = $Control/TimerContainer/TimerFill
# new_timer is just a visual overlay

@export_group("Font Settings")
@export var custom_font: Font
@export var font_size: int = 75
@export var outline_color: Color = Color.BLACK
@export var outline_size: int = 20
@export var shadow_color: Color = Color(0, 0, 0, 0.5)
@export var shadow_offset: Vector2 = Vector2(3, 5)

# Color stages matching victory UI rank colors
# S: Red (< 60s), A: Gold (60-119s), B: Blue (120-179s), C: Cyan (180-239s), D: Brown (240+s)
var color_stages: Array[Color] = [
	Color(1.0, 0.0, 0.0, 1.0),    # Red (S - < 60s)
	Color(1.0, 0.84, 0.0, 1.0),   # Gold (A - 60-119s)
	Color(0.0, 0.4, 1.0, 1.0),    # Blue (B - 120-179s)
	Color(0.0, 1.0, 1.0, 1.0),    # Cyan (C - 180-239s)
	Color(0.6, 0.3, 0.0, 1.0),    # Brown (D - 240+s)
]

var current_time: float = 0.0
var max_time: float = 300.0
var is_running: bool = false
var dialogue_slow_mode: bool = false
var is_rewinding: bool = false
var last_pulse_second: int = -1  # Track last second for pulse effect
var pulse_tween: Tween  # Store current pulse tween
var rank_pulse_tween: Tween  # Store current rank pulse tween
var last_rank_pulse_second: int = -1  # Track last second for rank pulse
var base_timer_font_color: Color = Color.WHITE  # Will be captured from initial label color

func _ready() -> void:
	# Ensure TimerUI runs even when the game is paused (e.g. during dialogue)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Add to group for LevelState access
	add_to_group("timer_ui")
	
	# Wait for next frame to get proper sizes
	await get_tree().process_frame
	_apply_font_settings()
	
	# Capture the initial timer font color (e.g. red from .tscn) for later restoration
	if timer_label:
		base_timer_font_color = timer_label.get_theme_color("font_color")
	
	# Initial display update
	update_display(current_time)
	_update_rank_indicator()
	
	# Set pivot point to center for scaling effect
	if timer_label:
		timer_label.pivot_offset = timer_label.size / 2.0

func _apply_font_settings() -> void:
	if not timer_label:
		return
		
	if custom_font:
		timer_label.add_theme_font_override("font", custom_font)
	
	timer_label.add_theme_font_size_override("font_size", font_size)
	timer_label.add_theme_color_override("font_outline_color", outline_color)
	timer_label.add_theme_constant_override("outline_size", outline_size)
	timer_label.add_theme_color_override("font_shadow_color", shadow_color)
	timer_label.add_theme_constant_override("shadow_offset_x", int(shadow_offset.x))
	timer_label.add_theme_constant_override("shadow_offset_y", int(shadow_offset.y))

func start_timer() -> void:
	is_running = true

func pause_timer() -> void:
	is_running = false

func setup_timer(time_limit: float) -> void:
	max_time = time_limit
	current_time = 0.0
	update_display(current_time)
	if not is_running:
		is_running = true

func reset_timer() -> void:
	setup_timer(max_time)

func stop_timer() -> void:
	is_running = false

func add_time(amount: float) -> void:
	current_time += amount
	update_display(current_time)

func play_time_delta_feedback(delta_seconds: float) -> void:
	"""Make time changes (like -1s reward) more obvious."""
	if not timer_label:
		return
	
	# Stronger pulse + color flash, independent of the normal per-second pulse.
	if pulse_tween:
		pulse_tween.kill()
	
	var flash_color := Color(0.2, 1.0, 0.6) if delta_seconds < 0 else Color(1.0, 1.0, 0.0)
	timer_label.add_theme_color_override("font_color", flash_color)
	
	pulse_tween = create_tween()
	pulse_tween.set_trans(Tween.TRANS_QUAD)
	pulse_tween.set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(timer_label, "scale", Vector2(1.5, 1.5), 0.08)
	pulse_tween.tween_property(timer_label, "scale", Vector2(1.0, 1.0), 0.22)
	pulse_tween.finished.connect(func():
		timer_label.add_theme_color_override("font_color", base_timer_font_color)
	)

func set_rewind_active(active: bool) -> void:
	"""Set whether rewind is active (timer moves backwards)."""
	is_rewinding = active

func _is_ui_overlay_visible(node_name: String) -> bool:
	var overlay = get_tree().root.find_child(node_name, true, false)
	return overlay is CanvasItem and (overlay as CanvasItem).visible

func _process(delta: float) -> void:
	# Freeze timer while pause or victory overlays are visible.
	if _is_ui_overlay_visible("VictoryUI") or _is_ui_overlay_visible("PauseMenu"):
		return
	
	if not is_running:
		return
		
	# Check for tutorial freeze first
	if has_node("/root/TutorialBlockManager"):
		var tutorial_manager = get_node("/root/TutorialBlockManager")
		if tutorial_manager.has_method("get_is_tutorial_active"):
			if tutorial_manager.get_is_tutorial_active():
				return

	var dt = delta
	
	# Since we use PROCESS_MODE_ALWAYS, we should run even when paused
	# But we need to check if it's a pause menu vs dialogue
	if get_tree().paused:
		if dialogue_slow_mode:
			# If paused due to dialogue, timer proceeds at 1/2 speed
			dt *= 0.5
		# Otherwise, continue running (timer should run even when game is paused for other reasons)
	
	# During rewind, timer moves backwards at 0.5x speed
	if is_rewinding:
		current_time -= dt * 0.5
		# Clamp to 0 to prevent going negative
		current_time = max(current_time, 0.0)
	else:
		current_time += dt
	
	if current_time >= max_time:
		current_time = max_time
		is_running = false
		time_expired.emit()
	
	update_display(current_time)
	_update_rank_indicator()

func update_display(display_time: float) -> void:
	var total_seconds = max(0, display_time)
	var minutes = int(total_seconds / 60.0)
	var seconds = int(total_seconds) % 60
	
	# Update label text with clean formatting
	if timer_label:
		# Format as MM:SS - clean and readable
		timer_label.text = "%02d:%02d" % [minutes, seconds]
		
		# Pulse effect on each second pass
		var current_second = int(total_seconds)
		if current_second != last_pulse_second:
			last_pulse_second = current_second
			_pulse_timer_label()
	
	# Calculate progress (0.0 = start, 1.0 = time limit reached)
	var progress = display_time / max_time
	progress = clamp(progress, 0.0, 1.0)
	
	# Update shader mask on TimerFill
	if timer_fill and timer_fill.material is ShaderMaterial:
		var mat = timer_fill.material as ShaderMaterial
		mat.set_shader_parameter("progress", progress)

func calculate_rank(time: float) -> String:
	"""Calculate rank based on time taken."""
	# S: within 1 minute (< 60 seconds)
	if time < 60.0:
		return "S"  # Sonic
	elif time < 120.0:
		return "A"  # Agile
	elif time < 180.0:
		return "B"  # Brisks
	elif time < 240.0:
		return "C"  # Casual
	else:
		return "D"  # Delayed

func _get_rank_color(rank: String) -> Color:
	"""Get the color for a given rank letter."""
	match rank:
		"S": return Color(1.0, 0.0, 0.0, 1.0)       # Red
		"A": return Color(1.0, 0.84, 0.0, 1.0)       # Gold
		"B": return Color(0.0, 0.4, 1.0, 1.0)        # Blue
		"C": return Color(0.0, 1.0, 1.0, 1.0)        # Cyan
		"D": return Color(0.6, 0.3, 0.0, 1.0)        # Brown
		_: return Color(1.0, 1.0, 1.0, 1.0)          # White fallback

func _update_rank_indicator() -> void:
	"""Update the rank indicator to the right of the timer bar based on current time."""
	if not rank_indicator:
		return
	
	# Calculate rank using same thresholds as victory UI
	var rank = calculate_rank(current_time)
	
	# Always update text
	rank_indicator.text = rank
	
	# Apply rank-specific color
	var rank_color = _get_rank_color(rank)
	rank_indicator.add_theme_color_override("font_color", rank_color)
	
	# Always ensure it's visible
	rank_indicator.visible = true
	rank_indicator.modulate = Color(1, 1, 1, 1)
	
	# Pulse rank indicator each second
	var current_second = int(current_time)
	if current_second != last_rank_pulse_second:
		last_rank_pulse_second = current_second
		_pulse_rank_indicator()

func _pulse_timer_label() -> void:
	if not timer_label:
		return
		
	if pulse_tween:
		pulse_tween.kill()
		
	pulse_tween = create_tween()
	pulse_tween.set_trans(Tween.TRANS_QUAD)
	pulse_tween.set_ease(Tween.EASE_OUT)
	
	# Enlarge
	pulse_tween.tween_property(timer_label, "scale", Vector2(1.2, 1.2), 0.1)
	# Shrink back
	pulse_tween.tween_property(timer_label, "scale", Vector2(1.0, 1.0), 0.2)

func _pulse_rank_indicator() -> void:
	if not rank_indicator:
		return
	
	# Set pivot for scaling from center
	rank_indicator.pivot_offset = rank_indicator.size / 2.0
	
	if rank_pulse_tween:
		rank_pulse_tween.kill()
	
	rank_pulse_tween = create_tween()
	rank_pulse_tween.set_trans(Tween.TRANS_QUAD)
	rank_pulse_tween.set_ease(Tween.EASE_OUT)
	
	# Store original scale
	var base_scale = Vector2(0.958932, 0.883081)  # Original scale from .tscn
	
	# Enlarge
	rank_pulse_tween.tween_property(rank_indicator, "scale", base_scale * 1.25, 0.12)
	# Shrink back
	rank_pulse_tween.tween_property(rank_indicator, "scale", base_scale, 0.25)

func _on_dialogue_started(_id: String) -> void:
	dialogue_slow_mode = true

func _on_dialogue_finished() -> void:
	dialogue_slow_mode = false
