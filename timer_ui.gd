extends CanvasLayer

signal time_expired

@onready var timer_label: Label = $Control/TimerContainer/BarContainer/TimerLabel
@onready var timer_bar: Panel = $Control/TimerContainer/BarContainer/TimerBar
@onready var bar_container: Control = $Control/TimerContainer/BarContainer
@onready var rank_indicator: Label = $Control/TimerContainer/RankIndicator

@export_group("Font Settings")
@export var custom_font: Font
@export var font_size: int = 180
@export var outline_color: Color = Color.WHITE
@export var outline_size: int = 10
@export var shadow_color: Color = Color(0, 0, 0, 0.5)
@export var shadow_offset: Vector2 = Vector2(3, 5)

@export_group("Bar Settings")
@export var bar_width: float = 1200.0  ## Total width of the timer bar
@export var bar_height: float = 260.0  ## Height of the timer bar
@export var bar_outline_color: Color = Color.WHITE  ## Color of the bar outline
@export var bar_outline_width: int = 3  ## Width of the bar outline
@export var bar_corner_radius: int = 20  ## Corner radius for rounded corners

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

func _setup_bars() -> void:
	# Read initial sizes from scene file to preserve manual positioning
	# Only override if inspector values are explicitly set
	
	# Bar container - preserve scene file positioning
	if bar_container:
		initial_bar_container_size = bar_container.size
		# Determine max width: prefer scene file, then inspector, then default
		if bar_container.size.x > 0:
			bar_max_width = bar_container.size.x
		elif bar_width > 0:
			bar_max_width = bar_width
			# Inspector value overrides - update container
			bar_container.offset_left = -bar_max_width / 2.0
			bar_container.offset_right = bar_max_width / 2.0
		else:
			bar_max_width = 1200.0
		
		# Only override height if inspector value is different from default
		if bar_height != 260.0:
			bar_container.offset_top = -bar_height / 2.0
			bar_container.offset_bottom = bar_height / 2.0
	
	# Timer bar - preserve scene file positioning, only update width dynamically
	if timer_bar:
		initial_timer_bar_size = Vector2(timer_bar.size.x, timer_bar.size.y)
		# Store the full width from scene file for shrinking animation
		if timer_bar.size.x > 0:
			bar_max_width = timer_bar.size.x
		# Only override if inspector values are explicitly set
		if bar_width > 0:
			bar_max_width = bar_width
			timer_bar.offset_left = 0.0
			timer_bar.offset_right = bar_max_width
		if bar_height != 260.0:
			timer_bar.offset_top = -bar_height / 2.0
			timer_bar.offset_bottom = bar_height / 2.0
	
	# Timer label - preserve scene file positioning completely
	if timer_label:
		initial_timer_label_size = timer_label.size
		# Only override text styling, never position
		timer_label.add_theme_color_override("font_color", Color.WHITE)
		timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
		timer_label.add_theme_constant_override("outline_size", 12)
	
	# Rank indicator - preserve scene file positioning completely
	if rank_indicator:
		initial_rank_indicator_pos = rank_indicator.position
	
	# Initialize bar to full width (timer starts at 0, so bar is full)
	_setup_bar_style(timer_bar)
	_update_bar_sizes(0.0)

func _setup_bar_style(bar: Panel) -> void:
	if not bar:
		return
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.8, 0.2, 1.0)  # Initial green color
	style_box.border_color = bar_outline_color
	style_box.border_width_left = bar_outline_width
	style_box.border_width_right = bar_outline_width
	style_box.border_width_top = bar_outline_width
	style_box.border_width_bottom = bar_outline_width
	
	# Add rounded corners for the single continuous bar
	style_box.corner_radius_top_left = bar_corner_radius
	style_box.corner_radius_bottom_left = bar_corner_radius
	style_box.corner_radius_top_right = bar_corner_radius
	style_box.corner_radius_bottom_right = bar_corner_radius
	
	bar.add_theme_stylebox_override("panel", style_box)

func _update_bar_sizes(progress: float) -> void:
	# Single continuous bar shrinks from both ends toward center as time progresses
	# progress: 0.0 = full bar, 1.0 = empty bar (meets at center)
	# Only update the bar width dynamically - preserve all other positioning from scene file
	
	if bar_max_width <= 0:
		# Recalculate if needed
		if bar_width > 0:
			bar_max_width = bar_width
		elif bar_container and bar_container.size.x > 0:
			bar_max_width = bar_container.size.x
		elif timer_bar:
			bar_max_width = timer_bar.size.x
		else:
			bar_max_width = 1200.0
	
	if bar_max_width <= 0:
		return  # Can't update if we don't have a valid width
	
	# Update the bar to shrink from both ends toward center
	if timer_bar:
		# Get the initial full width from scene file or stored value
		var full_width = bar_max_width
		# Calculate how much to shrink from each side
		# When progress = 0.0: shrink_amount = 0 (full bar)
		# When progress = 0.5: shrink_amount = full_width/2 (half from each side)
		# When progress = 1.0: shrink_amount = full_width/2 (meets at center)
		var shrink_amount = (full_width * progress) / 2.0
		
		# Preserve original top and bottom from scene file
		var original_top = timer_bar.offset_top
		var original_bottom = timer_bar.offset_bottom
		
		# Shrink from both ends: left edge moves right, right edge moves left
		timer_bar.offset_left = shrink_amount
		timer_bar.offset_right = full_width - shrink_amount
		timer_bar.offset_top = original_top  # Preserve from scene file
		timer_bar.offset_bottom = original_bottom  # Preserve from scene file

func _apply_font_settings() -> void:
	if not timer_label:
		return
	
	if custom_font:
		timer_label.add_theme_font_override("font", custom_font)
	
	if font_size > 0:
		timer_label.add_theme_font_size_override("font_size", font_size)
		
	timer_label.add_theme_color_override("font_outline_color", outline_color)
	timer_label.add_theme_constant_override("outline_size", outline_size)
	timer_label.add_theme_color_override("font_shadow_color", shadow_color)
	timer_label.add_theme_constant_override("shadow_offset_x", int(shadow_offset.x))
	timer_label.add_theme_constant_override("shadow_offset_y", int(shadow_offset.y))

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
	
	# Determine which color stage we're in based on rank thresholds
	# S: < 60s, A: 60-119s, B: 120-179s, C: 180-239s, D: 240+s
	var color_index = 0
	if display_time < 60.0:
		color_index = 0  # Cyan (S)
	elif display_time < 120.0:
		color_index = 1  # Green (A)
	elif display_time < 180.0:
		color_index = 2  # Yellow (B)
	elif display_time < 240.0:
		color_index = 3  # Orange (C)
	else:
		color_index = 4  # Red (D)
	
	var current_color = color_stages[color_index]
	
	# Update bar color
	_update_bar_color(timer_bar, current_color)
	
	# Update font color - always use white text with black outline for maximum visibility
	if timer_label:
		timer_label.add_theme_color_override("font_color", Color.WHITE)
		timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
		timer_label.add_theme_constant_override("outline_size", 12)
	
	# Update bar sizes - bars shrink from outer edges, always meeting in center
	_update_bar_sizes(progress)

func _update_bar_color(bar: Panel, color: Color) -> void:
	if not bar:
		return
	
	var style_box = bar.get_theme_stylebox("panel")
	if style_box and style_box is StyleBoxFlat:
		style_box.bg_color = color

func _get_contrasting_color(base_color: Color) -> Color:
	# Calculate luminance to determine if we should use light or dark text
	var luminance = 0.299 * base_color.r + 0.587 * base_color.g + 0.114 * base_color.b
	# Use white for dark colors, black for light colors, but with high contrast
	if luminance < 0.5:
		return Color.WHITE
	else:
		return Color(0.1, 0.1, 0.1, 1.0)  # Very dark gray/black

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
	
	# Always update text and color
	rank_indicator.text = rank
	
	# Set color based on rank (matching victory UI colors)
	match rank:
		"S":
			rank_indicator.add_theme_color_override("font_color", Color.CYAN)
		"A":
			rank_indicator.add_theme_color_override("font_color", Color.GREEN)
		"B":
			rank_indicator.add_theme_color_override("font_color", Color.YELLOW)
		"C":
			rank_indicator.add_theme_color_override("font_color", Color.ORANGE)
		"D":
			rank_indicator.add_theme_color_override("font_color", Color.RED)
	
	# Always ensure it's visible
	rank_indicator.visible = true
	rank_indicator.modulate = Color(1, 1, 1, 1)

func _on_dialogue_started(_id: String) -> void:
	dialogue_slow_mode = true

func _on_dialogue_finished() -> void:
	dialogue_slow_mode = false
