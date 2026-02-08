extends CanvasLayer

const MAX_DISPLAY_ENTRIES: int = 20

@onready var title_label: Label = $Control/Panel/TitleLabel
@onready var scroll_container: ScrollContainer = $Control/Panel/ScrollContainer
@onready var entries_container: VBoxContainer = $Control/Panel/ScrollContainer/EntriesContainer
@onready var back_button: Button = $Control/Panel/BackButton
@onready var loading_label: Label = $Control/Panel/LoadingLabel

var entry_labels: Array[Label] = []
var current_level: int = 0
var player_name: String = ""
var player_time: float = 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 130
	
	# Get player info from LeaderboardManager
	if LeaderboardManager:
		current_level = LeaderboardManager.last_submitted_level
		player_name = LeaderboardManager.get_player_name()
		player_time = LeaderboardManager.last_submitted_time
		
		# Connect to leaderboard update signal
		if not LeaderboardManager.global_leaderboard_updated.is_connected(_on_global_leaderboard_updated):
			LeaderboardManager.global_leaderboard_updated.connect(_on_global_leaderboard_updated)
	
	# Setup UI
	title_label.text = "GLOBAL LEADERBOARD"
	
	# Setup back button
	back_button.pressed.connect(_on_back_button_pressed)
	back_button.process_mode = Node.PROCESS_MODE_ALWAYS
	back_button.focus_mode = Control.FOCUS_ALL
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Ensure mouse is visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Create entry labels for 20 slots
	_create_entry_labels()
	
	# Show loading state
	loading_label.text = "Loading..."
	loading_label.visible = true
	
	# Try to display existing data first, then fetch fresh data
	var existing_scores = LeaderboardManager.get_top_scores(MAX_DISPLAY_ENTRIES, true)
	if existing_scores.size() > 0:
		_display_scores(existing_scores)
		loading_label.visible = false
	
	# Fetch fresh data from Supabase
	if LeaderboardManager and LeaderboardManager.api_enabled:
		LeaderboardManager.fetch_global_leaderboard(current_level)

func _create_entry_labels():
	"""Create 20 label entries in the scroll container."""
	# Clear existing
	for child in entries_container.get_children():
		child.queue_free()
	entry_labels.clear()
	
	for i in range(MAX_DISPLAY_ENTRIES):
		var entry = _create_entry_row(i)
		entries_container.add_child(entry)
		entry_labels.append(entry)

func _create_entry_row(index: int) -> Label:
	"""Create a single leaderboard entry row."""
	var label = Label.new()
	label.name = "Entry_%d" % index
	label.text = "#%d  ---" % (index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Style the label
	var font = load("res://Fonts/Funkrocker.otf")
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 8)
	
	# Set minimum height for each row
	label.custom_minimum_size = Vector2(0, 55)
	
	return label

func _display_scores(scores: Array[Dictionary]):
	"""Display scores in the leaderboard entries."""
	loading_label.visible = false
	
	for i in range(MAX_DISPLAY_ENTRIES):
		if i >= entry_labels.size():
			break
		
		var label = entry_labels[i]
		
		if i < scores.size():
			var score_data = scores[i]
			var time_val = score_data["time"]
			var name_val = score_data.get("player_name", "Player")
			
			var minutes = int(time_val) / 60
			var seconds = int(time_val) % 60
			var centiseconds = int((time_val - int(time_val)) * 100)
			
			# Format: #1  PLAYER - 01:23.45
			label.text = "#%d  %s - %02d:%02d.%02d" % [i + 1, name_val, minutes, seconds, centiseconds]
			label.modulate.a = 1.0
			
			# Check if this is the current player's entry - highlight in yellow
			var is_player_entry = _is_player_entry(score_data)
			if is_player_entry:
				label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0, 1.0))  # Bright yellow
				label.add_theme_font_size_override("font_size", 46)  # Slightly bigger
			else:
				# Rank-based coloring
				if i == 0:
					label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))  # Gold
				elif i == 1:
					label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1.0))  # Silver
				elif i == 2:
					label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2, 1.0))  # Bronze
				else:
					label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))  # White
				label.add_theme_font_size_override("font_size", 42)
		else:
			label.text = "#%d  ---" % (i + 1)
			label.modulate.a = 0.4
			label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
			label.add_theme_font_size_override("font_size", 42)

func _is_player_entry(score_data: Dictionary) -> bool:
	"""Check if a score entry belongs to the current player."""
	var entry_name = score_data.get("player_name", "")
	var entry_time = score_data.get("time", -1.0)
	
	# Match by player name AND approximate time (within 0.01s)
	if entry_name == player_name and abs(entry_time - player_time) < 0.01:
		return true
	
	# Also check by player name only if the time is very close to our submitted time
	# This handles cases where time rounding might differ slightly
	if entry_name == player_name and player_time > 0.0 and abs(entry_time - player_time) < 0.05:
		return true
	
	return false

func _on_global_leaderboard_updated():
	"""Called when the global leaderboard is updated from the API."""
	if LeaderboardManager:
		var scores = LeaderboardManager.get_top_scores(MAX_DISPLAY_ENTRIES, true)
		_display_scores(scores)

func _on_back_button_pressed():
	print("LeaderboardScene: Back button pressed")
	# Go back to level select menu
	if ResourceLoader.exists("res://level_select_menu.tscn"):
		get_tree().change_scene_to_file("res://level_select_menu.tscn")
	else:
		push_error("LeaderboardScene: level_select_menu.tscn not found!")

func _input(event):
	# Allow ESC to go back
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_button_pressed()
