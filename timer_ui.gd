extends CanvasLayer

signal time_expired

@onready var timer_label: Label = $Control/TimerContainer/BarContainer/TimerLabel
@onready var timer_bar: Panel = $Control/TimerContainer/BarContainer/TimerBar
@onready var left_bands: ColorRect = $Control/TimerContainer/BarContainer/LeftBands
@onready var right_bands: ColorRect = $Control/TimerContainer/BarContainer/RightBands
@onready var bar_container: Control = $Control/TimerContainer/BarContainer
@onready var rank_indicator: Label = $Control/TimerContainer/RankIndicator
@onready var warning_overlay: ColorRect = $Control/WarningOverlay

@export_group("Font Settings")
@export var custom_font: Font
@export var font_size: int = 180
@export var outline_color: Color = Color.WHITE
@export var outline_size: int = 10
@export var shadow_color: Color = Color(0, 0, 0, 0.5)
@export var shadow_offset: Vector2 = Vector2(3, 5)

@export_group("Bar Settings")
@export var bar_width: float = 1200.0  ## Total width of the timer bar
@export var bar_height: float = 65.0  ## Height of the timer bar
@export var bar_outline_color: Color = Color.WHITE  ## Color of the bar outline
@export var bar_outline_width: int = 3  ## Width of the bar outline
@export var bar_corner_radius: int = 20  ## Corner radius for rounded corners

@export_group("Timer Behavior")
@export var min_bar_length: float = 100.0 ## Minimum length the bar will shrink to
@export var green_threshold: float = 0.6 ## Time percentage above which bar is green
@export var yellow_threshold: float = 0.3 ## Time percentage above which bar is yellow (below green)

@export_group("Warning Overlay")
@export var warning_threshold: float = 60.0  ## Time remaining (seconds) to trigger warning
@export var warning_intensity: float = 0.15  ## Base intensity of warning overlay (0.0-1.0) - reduced since frame is main indicator
@export var warning_pulse_speed: float = 3.0  ## Speed of warning pulse animation
@export var warning_frame_thickness: float = 0.02  ## Thickness of warning frame (0.0-0.1)
@export var warning_frame_intensity: float = 0.6  ## Intensity of warning frame (0.0-2.0) - reduced for subtler effect

# Color stages matching victory UI rank colors
# S: Cyan (< 60s), A: Green (60-119s), B: Yellow (120-179s), C: Orange (180-239s), D: Red (240+s)
var color_stages: Array[Color] = [
	Color(0.0, 1.0, 1.0, 1.0),    # Cyan (S - < 60s)
	Color(0.0, 1.0, 0.0, 1.0),    # Green (A - 60-119s)
	Color(1.0, 1.0, 0.0, 1.0),    # Yellow (B - 120-179s)
	Color(1.0, 0.65, 0.0, 1.0),   # Orange (C - 180-239s)
	Color(1.0, 0.0, 0.0, 1.0),    # Red (D - 240+s)
]

var current_time: float = 0.0
var max_time: float = 300.0
var is_running: bool = false
var dialogue_slow_mode: bool = false
var is_rewinding: bool = false  # Is player currently rewinding (clock moves backwards)
var bar_max_width: float = 0.0

# Store initial positions from scene file so we don't override manual positioning
var initial_bar_container_size: Vector2 = Vector2.ZERO
var initial_timer_bar_size: Vector2 = Vector2.ZERO
var initial_timer_label_size: Vector2 = Vector2.ZERO
var initial_rank_indicator_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Ensure TimerUI runs even when the game is paused (e.g. during dialogue)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Add to group for LevelState access
	add_to_group("timer_ui")
	
	# Wait for next frame to get proper sizes
	await get_tree().process_frame
	_setup_bars()
	_apply_font_settings()
	
	# Initial display update
	update_display(current_time)
	_update_rank_indicator()
	
	# Initialize warning overlay (hidden by default)
	if warning_overlay:
		warning_overlay.modulate.a = 0.0
		# Ensure shader material is set up (scene file may already have it)
		if warning_overlay.material == null:
			var shader_mat = ShaderMaterial.new()
			shader_mat.shader = preload("res://shaders/time_warning_overlay.gdshader")
			warning_overlay.material = shader_mat
		# Set initial shader parameters (update even if material exists)
		if warning_overlay.material is ShaderMaterial:
			var shader_mat = warning_overlay.material as ShaderMaterial
			shader_mat.set_shader_parameter("intensity", warning_intensity)
			shader_mat.set_shader_parameter("pulse_speed", warning_pulse_speed)
			shader_mat.set_shader_parameter("frame_thickness", warning_frame_thickness)
			shader_mat.set_shader_parameter("frame_intensity", warning_frame_intensity)
			
	# Setup edge fade for TimerBar and Bands
	_setup_edge_fades()
	
	# Auto-start timer if max_time is set and timer hasn't been started yet
	# This ensures the timer runs even if setup_timer wasn't called explicitly
	if max_time > 0:
		if not is_running:
			is_running = true
			current_time = 0.0
	
	# Listen for dialogue events to handle slow-down logic
	if DialogueManager:
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
		DialogueManager.dialogue_finished.connect(_on_dialogue_finished)

func _setup_edge_fades() -> void:
	# 1. Setup TimerBar background fade (linear fade on first and last 30%)
	if timer_bar:
		var bar_mat = ShaderMaterial.new()
		bar_mat.shader = preload("res://shaders/edge_fade.gdshader")
		# Fade 30% of the total width at both ends
		bar_mat.set_shader_parameter("left_fade_width", 0.3)
		bar_mat.set_shader_parameter("right_fade_width", 0.3)
		timer_bar.material = bar_mat
		
	# 2. Setup Bands fade
	# LeftBands covers left half of bar. To fade left 30% of TOTAL bar,
	# we need to fade left 60% of the LeftBands (since it's half width).
	if left_bands and left_bands.material is ShaderMaterial:
		left_bands.material.set_shader_parameter("left_fade_width", 0.6)
		left_bands.material.set_shader_parameter("right_fade_width", 0.0)
		# Slower speed by 30% (from 0.5 to 0.35)
		left_bands.material.set_shader_parameter("speed", 0.35)
		# Wider by 50% (from 0.1 to 0.15)
		left_bands.material.set_shader_parameter("thickness", 0.15)
		
	# RightBands covers right half of bar. To fade right 30% of TOTAL bar,
	# we need to fade right 60% of the RightBands.
	if right_bands and right_bands.material is ShaderMaterial:
		right_bands.material.set_shader_parameter("left_fade_width", 0.0)
		right_bands.material.set_shader_parameter("right_fade_width", 0.6)
		# Slower speed by 30% (from 0.5 to 0.35)
		right_bands.material.set_shader_parameter("speed", 0.35)
		# Wider by 50% (from 0.1 to 0.15)
		right_bands.material.set_shader_parameter("thickness", 0.15)

func _setup_bars() -> void:
	if bar_container:
		# Ensure container is full width and has height
		bar_container.anchor_left = 0.0
		bar_container.anchor_right = 1.0
		bar_container.offset_left = 0.0
		bar_container.offset_right = 0.0
		bar_container.offset_top = 0.0
		bar_container.offset_bottom = bar_height
		
		# Now that container is set, get its actual width
		bar_max_width = bar_container.size.x
		if bar_max_width <= 0:
			bar_max_width = get_viewport().get_visible_rect().size.x
	
	if timer_bar:
		timer_bar.anchor_left = 0.0
		timer_bar.anchor_right = 1.0
		timer_bar.offset_left = 0.0
		timer_bar.offset_right = 0.0
		timer_bar.offset_top = 0.0
		timer_bar.offset_bottom = 0.0 # Full height of container
	
	_update_bar_sizes(0.0)

func _setup_bar_style(bar: Panel) -> void:
	pass # Respect editor stylebox settings

func _update_bar_sizes(progress: float) -> void:
	# progress: 0.0 = full bar, 1.0 = empty bar (meets at center)
	
	if bar_max_width <= 0:
		bar_max_width = get_viewport().get_visible_rect().size.x
	
	if bar_max_width <= 0:
		return
	
	if timer_bar:
		var full_width = bar_max_width
		var target_width = lerp(full_width, min_bar_length, progress)
		var shrink_amount = (full_width - target_width) / 2.0
		
		# Symmetrically adjust offsets from the edges
		timer_bar.offset_left = shrink_amount
		timer_bar.offset_right = -shrink_amount
		
		# Update band overlay logic
		# LeftBands covers the left half (0.0 to 0.5)
		# RightBands covers the right half (0.5 to 1.0)
		if left_bands:
			left_bands.anchor_left = 0.0
			left_bands.anchor_right = 0.5
			left_bands.offset_left = 0
			left_bands.offset_right = 0
			left_bands.offset_top = 0
			left_bands.offset_bottom = 0
		if right_bands:
			right_bands.anchor_left = 0.5
			right_bands.anchor_right = 1.0
			right_bands.offset_left = 0
			right_bands.offset_right = 0
			right_bands.offset_top = 0
			right_bands.offset_bottom = 0

func _apply_font_settings() -> void:
	pass # Respect editor font settings

func setup_timer(duration: float) -> void:
	var was_running = is_running
	var old_max_time = max_time
	max_time = duration
	# Only reset current_time if timer wasn't running or if max_time changed significantly
	# This prevents resetting the timer if it's already counting and just being reconfigured
	if not was_running or abs(old_max_time - duration) > 1.0:
		current_time = 0.0
	is_running = true
	
	# Ensure bars are set up if they weren't ready before
	if bar_max_width == 0.0:
		_setup_bars()
	
	update_display(current_time)
	
	# Force start the timer to ensure it's running
	if not is_running:
		is_running = true

func reset_timer() -> void:
	setup_timer(max_time)

func stop_timer() -> void:
	is_running = false

func add_time(amount: float) -> void:
	current_time += amount
	update_display(current_time)

func set_rewind_active(active: bool) -> void:
	"""Set whether rewind is active (timer moves backwards)."""
	is_rewinding = active

func _process(delta: float) -> void:
	# Ensure timer is running if max_time is set
	if max_time > 0 and not is_running:
		is_running = true
		current_time = 0.0
	
	if not is_running:
		return
		
	# Check for tutorial freeze first
	if TutorialBlockManager and TutorialBlockManager.has_method("get_is_tutorial_active"):
		if TutorialBlockManager.get_is_tutorial_active():
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
	
	# Calculate progress (0.0 = no time elapsed, 1.0 = time limit reached)
	var progress = display_time / max_time
	progress = clamp(progress, 0.0, 1.0)
	
	# Determine color based on remaining time percentage (1.0 - progress)
	var time_left_percent = 1.0 - progress
	var current_color = Color.GREEN
	if time_left_percent > green_threshold:
		current_color = Color.GREEN
	elif time_left_percent > yellow_threshold:
		current_color = Color.YELLOW
	else:
		current_color = Color.RED
	
	# Update bar color
	_update_bar_color(timer_bar, current_color)
	
	# Update bar sizes - bars shrink from outer edges, always meeting in center
	_update_bar_sizes(progress)
	
	# Update warning overlay - show when time remaining is <= warning_threshold
	_update_warning_overlay(display_time)

func _update_bar_color(bar: Panel, color: Color) -> void:
	if not bar:
		return
	
	# Try to update the stylebox if it exists
	var style_box = bar.get_theme_stylebox("panel")
	if style_box and style_box is StyleBoxFlat:
		style_box.bg_color = color
	else:
		# Fallback to modulate if stylebox isn't a FlatStyleBox or doesn't exist
		bar.modulate = color

func _get_contrasting_color(base_color: Color) -> Color:
	# Calculate luminance to determine if we should use light or dark text
	var luminance = 0.299 * base_color.r + 0.587 * base_color.g + 0.114 * base_color.b
	# Use white for dark colors, black for light colors, but with high contrast
	if luminance < 0.5:
		return Color.WHITE
	else:
		return Color(0.1, 0.1, 0.1, 1.0)  # Very dark gray/black

func _update_warning_overlay(display_time: float) -> void:
	# Show warning overlay when remaining time is <= warning_threshold (last minute)
	var remaining_time = max_time - display_time
	var is_warning_active = false
	var urgency = 0.0
	
	if remaining_time <= warning_threshold and remaining_time > 0:
		is_warning_active = true
		# Calculate urgency based on how close to zero (more intense as time runs out)
		urgency = 1.0 - (remaining_time / warning_threshold)
	
	if warning_overlay:
		if is_warning_active:
			# Subtle overlay - frame is the main indicator, overlay just adds atmosphere
			var target_alpha = 0.2 + (urgency * 0.15)  # Range from 0.2 to 0.35 (much more subtle)
			
			# Smoothly fade in/out
			var current_alpha = warning_overlay.modulate.a
			var new_alpha = lerp(current_alpha, target_alpha, 0.15)
			warning_overlay.modulate.a = new_alpha
			
			# Update shader parameters for pulsing effect
			if warning_overlay.material and warning_overlay.material is ShaderMaterial:
				var shader_mat = warning_overlay.material as ShaderMaterial
				# Keep overlay subtle - frame does the heavy lifting
				shader_mat.set_shader_parameter("intensity", warning_intensity * (0.8 + urgency * 0.2))
				shader_mat.set_shader_parameter("pulse_speed", warning_pulse_speed * (1.0 + urgency * 0.8))
				shader_mat.set_shader_parameter("frame_thickness", warning_frame_thickness)
				# Frame intensity increases subtly with urgency
				shader_mat.set_shader_parameter("frame_intensity", warning_frame_intensity * (1.0 + urgency * 0.3))
				# Subtle overlay color - frame is bright red
				var color_intensity = 0.2 + urgency * 0.15
				shader_mat.set_shader_parameter("warning_color", Color(1.0, 0.05 * (1.0 - urgency), 0.05 * (1.0 - urgency), color_intensity))
		else:
			# Fade out when not in warning state
			var current_alpha = warning_overlay.modulate.a
			warning_overlay.modulate.a = lerp(current_alpha, 0.0, 0.2)
			if warning_overlay.modulate.a < 0.01:
				warning_overlay.modulate.a = 0.0

func calculate_rank(time: float) -> String:
	"""Calculate rank based on time taken."""
	# S: within 1 minute (< 60 seconds)
	# A: within 2 minutes (60-119 seconds)
	# B: within 3 minutes (120-179 seconds)
	# C: within 4 minutes (180-239 seconds)
	# D: 4+ minutes (240+ seconds)
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

func _update_rank_indicator() -> void:
	"""Update the rank indicator to the right of the timer bar based on current time."""
	if not rank_indicator:
		return
	
	# Calculate rank using same thresholds as victory UI
	var rank = calculate_rank(current_time)
	
	# Always update text
	rank_indicator.text = rank
	
	# Always ensure it's visible
	rank_indicator.visible = true
	rank_indicator.modulate = Color(1, 1, 1, 1)

func _on_dialogue_started(_id: String) -> void:
	dialogue_slow_mode = true

func _on_dialogue_finished() -> void:
	dialogue_slow_mode = false
