extends CanvasLayer

@onready var time_label = $Control/Panel/TimeLabel
@onready var rank_container = $Control/Panel/RankContainer
@onready var rank_first_letter = $Control/Panel/RankContainer/RankFirstLetter
@onready var rank_label = $Control/Panel/RankContainer/RankLabel
@onready var rank_impact_container = $Control/Panel/RankImpactContainer
@onready var rank_impact_first_letter = $Control/Panel/RankImpactContainer/RankImpactFirstLetter
@onready var rank_impact_label = $Control/Panel/RankImpactContainer/RankImpactLabel
@onready var animation_player = $AnimationPlayer
@onready var control_node = $Control
@onready var leaderboard_container = $Control/Panel/LeaderboardContainer
@onready var leaderboard_title = $Control/Panel/LeaderboardContainer/LeaderboardTitle
@onready var leaderboard_entry_1 = $Control/Panel/LeaderboardContainer/Entry1
@onready var leaderboard_entry_2 = $Control/Panel/LeaderboardContainer/Entry2
@onready var leaderboard_entry_3 = $Control/Panel/LeaderboardContainer/Entry3
@onready var name_entry_container = $Control/Panel/NameEntryContainer
@onready var name_input: LineEdit = $Control/Panel/NameEntryContainer/NameInputRow/NameInput
@onready var name_submit_btn: Button = $Control/Panel/NameEntryContainer/NameInputRow/SubmitButton
@onready var name_cancel_btn: Button = $Control/Panel/NameEntryContainer/NameInputRow/CancelButton

var restart_btn: Button
var leaderboard_btn: Button
var menu_btn: Button
var action_buttons: Array[Button] = []
var action_buttons_ready: bool = false
var _action_button_index: int = 0
var _using_keyboard_nav: bool = false

# Victory action row: loud keyboard/mouse selection styling (theme default focus is too subtle).
var _vab_style_idle: StyleBoxFlat
var _vab_style_idle_hover: StyleBoxFlat
var _vab_style_idle_pressed: StyleBoxFlat
var _vab_style_selected: StyleBoxFlat
var _vab_style_selected_hover: StyleBoxFlat
var _vab_style_selected_pressed: StyleBoxFlat

var current_shake_intensity: float = 0.0
var shake_timer: float = 0.0
var original_control_pos: Vector2

# Name entry state
var made_leaderboard: bool = false
var pending_time_taken: float = 0.0
var name_submitted: bool = false

# Audio
var sfx_player: AudioStreamPlayer
var climbing_player: AudioStreamPlayer
var score_climbing_sfx: AudioStream
var score_peak_sfx: AudioStream

func _ready():
	# Make sure the UI is visible and top-most
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	original_control_pos = control_node.position
	
	# Setup pivots for scaling effects
	time_label.pivot_offset = time_label.size / 2
	if rank_container:
		rank_container.pivot_offset = rank_container.size / 2
	if rank_first_letter:
		rank_first_letter.pivot_offset = rank_first_letter.size / 2
	if rank_label:
		rank_label.pivot_offset = rank_label.size / 2
	if rank_impact_container:
		rank_impact_container.pivot_offset = rank_impact_container.size / 2
	if rank_impact_first_letter:
		rank_impact_first_letter.pivot_offset = rank_impact_first_letter.size / 2
	if rank_impact_label:
		rank_impact_label.pivot_offset = rank_impact_label.size / 2
	
	# Initialize leaderboard display (hide initially)
	if leaderboard_container:
		leaderboard_container.modulate.a = 0
	
	# Initialize name entry container (hide initially)
	if name_entry_container:
		name_entry_container.modulate.a = 0
	
	# Setup name entry controls
	if name_input:
		name_input.process_mode = Node.PROCESS_MODE_ALWAYS
		name_input.mouse_filter = Control.MOUSE_FILTER_STOP
	if name_submit_btn:
		name_submit_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		name_submit_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		name_submit_btn.focus_mode = Control.FOCUS_ALL
		if not name_submit_btn.pressed.is_connected(_on_name_submit_pressed):
			name_submit_btn.pressed.connect(_on_name_submit_pressed)
	if name_cancel_btn:
		name_cancel_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		name_cancel_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		name_cancel_btn.focus_mode = Control.FOCUS_ALL
		if not name_cancel_btn.pressed.is_connected(_on_name_cancel_pressed):
			name_cancel_btn.pressed.connect(_on_name_cancel_pressed)
	if name_input:
		if not name_input.text_submitted.is_connected(_on_name_text_submitted):
			name_input.text_submitted.connect(_on_name_text_submitted)
		# Auto-capitalize input as the player types
		if not name_input.text_changed.is_connected(_on_name_input_text_changed):
			name_input.text_changed.connect(_on_name_input_text_changed)
	
	# Ensure buttons are clickable even when paused
	restart_btn = $Control/Panel/HBoxContainer/RestartButton
	leaderboard_btn = $Control/Panel/HBoxContainer/LeaderboardButton
	menu_btn = $Control/Panel/HBoxContainer/MenuButton
	action_buttons = [restart_btn, leaderboard_btn, menu_btn]
	
	restart_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	leaderboard_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Explicitly set focus mode to allow interaction
	restart_btn.focus_mode = Control.FOCUS_ALL
	leaderboard_btn.focus_mode = Control.FOCUS_ALL
	menu_btn.focus_mode = Control.FOCUS_ALL
	
	# Ensure buttons are on top and not blocked
	restart_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	leaderboard_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Grab focus on restart button for gamepad/keyboard support
	restart_btn.grab_focus()
	
	# Ensure background elements don't block input
	$Control/YellowBackground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Control/SpeedLines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Control/Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Control/Panel/HBoxContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Connect signals manually to be sure
	if not restart_btn.pressed.is_connected(_on_restart_button_pressed):
		restart_btn.pressed.connect(_on_restart_button_pressed)
	if not leaderboard_btn.pressed.is_connected(_on_leaderboard_button_pressed):
		leaderboard_btn.pressed.connect(_on_leaderboard_button_pressed)
	if not menu_btn.pressed.is_connected(_on_menu_button_pressed):
		menu_btn.pressed.connect(_on_menu_button_pressed)
		
	# Setup audio
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	sfx_player.bus = "Master"
	add_child(sfx_player)
	
	climbing_player = AudioStreamPlayer.new()
	climbing_player.name = "ClimbingPlayer"
	climbing_player.bus = "Master"
	add_child(climbing_player)
	
	# Load audio files
	if ResourceLoader.exists("res://audio/scoreClimbing.ogg"):
		score_climbing_sfx = load("res://audio/scoreClimbing.ogg")
	elif ResourceLoader.exists("res://audio/scoreClimbing.mp3"):
		score_climbing_sfx = load("res://audio/scoreClimbing.mp3")
		
	if not score_climbing_sfx:
		pass
		
	if ResourceLoader.exists("res://audio/scorePeak.ogg"):
		score_peak_sfx = load("res://audio/scorePeak.ogg")
	elif ResourceLoader.exists("res://audio/scorePeak.mp3"):
		score_peak_sfx = load("res://audio/scorePeak.mp3")
		
	if not score_peak_sfx:
		pass

func _ensure_victory_action_button_highlight_styles() -> void:
	if _vab_style_idle != null:
		return
	var corner := 8
	var m := 6
	_vab_style_idle = StyleBoxFlat.new()
	_vab_style_idle.set_corner_radius_all(corner)
	_vab_style_idle.set_border_width_all(2)
	_vab_style_idle.border_color = Color(0.12, 0.09, 0.07, 1)
	_vab_style_idle.bg_color = Color(0.30, 0.24, 0.20, 1)
	_vab_style_idle.set_content_margin_all(m)

	_vab_style_idle_hover = StyleBoxFlat.new()
	_vab_style_idle_hover.set_corner_radius_all(corner)
	_vab_style_idle_hover.set_border_width_all(2)
	_vab_style_idle_hover.border_color = Color(0.18, 0.14, 0.11, 1)
	_vab_style_idle_hover.bg_color = Color(0.38, 0.30, 0.25, 1)
	_vab_style_idle_hover.set_content_margin_all(m)

	_vab_style_idle_pressed = StyleBoxFlat.new()
	_vab_style_idle_pressed.set_corner_radius_all(corner)
	_vab_style_idle_pressed.set_border_width_all(2)
	_vab_style_idle_pressed.border_color = Color(0.08, 0.06, 0.05, 1)
	_vab_style_idle_pressed.bg_color = Color(0.22, 0.18, 0.14, 1)
	_vab_style_idle_pressed.set_content_margin_all(m)

	_vab_style_selected = StyleBoxFlat.new()
	_vab_style_selected.set_corner_radius_all(10)
	_vab_style_selected.set_border_width_all(5)
	_vab_style_selected.border_color = Color(1, 0.96, 0.82, 1)
	_vab_style_selected.bg_color = Color(0.55, 0.46, 0.30, 1)
	_vab_style_selected.shadow_color = Color(0, 0, 0, 0.45)
	_vab_style_selected.shadow_size = 12
	_vab_style_selected.shadow_offset = Vector2(0, 3)
	_vab_style_selected.set_content_margin_all(m)

	_vab_style_selected_hover = StyleBoxFlat.new()
	_vab_style_selected_hover.set_corner_radius_all(10)
	_vab_style_selected_hover.set_border_width_all(5)
	_vab_style_selected_hover.border_color = Color(1, 1, 1, 1)
	_vab_style_selected_hover.bg_color = Color(0.62, 0.54, 0.36, 1)
	_vab_style_selected_hover.shadow_color = Color(0, 0, 0, 0.45)
	_vab_style_selected_hover.shadow_size = 12
	_vab_style_selected_hover.shadow_offset = Vector2(0, 3)
	_vab_style_selected_hover.set_content_margin_all(m)

	_vab_style_selected_pressed = StyleBoxFlat.new()
	_vab_style_selected_pressed.set_corner_radius_all(10)
	_vab_style_selected_pressed.set_border_width_all(5)
	_vab_style_selected_pressed.border_color = Color(0.85, 0.78, 0.55, 1)
	_vab_style_selected_pressed.bg_color = Color(0.42, 0.36, 0.24, 1)
	_vab_style_selected_pressed.shadow_color = Color(0, 0, 0, 0.35)
	_vab_style_selected_pressed.shadow_size = 6
	_vab_style_selected_pressed.shadow_offset = Vector2(0, 2)
	_vab_style_selected_pressed.set_content_margin_all(m)


func _get_effective_victory_action_button_index() -> int:
	if _using_keyboard_nav:
		return _action_button_index
	for i in range(action_buttons.size()):
		if action_buttons[i].is_hovered():
			return i
	return _action_button_index


func _apply_victory_action_button_highlight() -> void:
	if not action_buttons_ready or action_buttons.is_empty():
		return
	_ensure_victory_action_button_highlight_styles()
	var sel := _get_effective_victory_action_button_index()
	sel = clampi(sel, 0, action_buttons.size() - 1)
	for i in range(action_buttons.size()):
		var b: Button = action_buttons[i]
		if not is_instance_valid(b):
			continue
		b.pivot_offset = b.size * 0.5
		if i == sel:
			b.scale = Vector2(1.07, 1.07)
			b.add_theme_stylebox_override("normal", _vab_style_selected)
			b.add_theme_stylebox_override("hover", _vab_style_selected_hover)
			b.add_theme_stylebox_override("pressed", _vab_style_selected_pressed)
			b.add_theme_stylebox_override("focus", _vab_style_selected)
			b.add_theme_color_override("font_color", Color(1.0, 0.98, 0.75))
			b.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02, 1))
			b.add_theme_constant_override("outline_size", 14)
		else:
			b.scale = Vector2.ONE
			b.add_theme_stylebox_override("normal", _vab_style_idle)
			b.add_theme_stylebox_override("hover", _vab_style_idle_hover)
			b.add_theme_stylebox_override("pressed", _vab_style_idle_pressed)
			b.add_theme_stylebox_override("focus", _vab_style_idle)
			b.remove_theme_color_override("font_color")
			b.remove_theme_color_override("font_outline_color")
			b.remove_theme_constant_override("outline_size")


func _process(delta):
	# Ensure mouse is visible (sometimes it gets hidden by other scripts)
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	# DEBUG: Check if buttons are valid
	# if $Control/Panel/HBoxContainer/RestartButton.is_hovered():
	#	 print("Hovering Restart")
		
	if shake_timer > 0:
		shake_timer -= delta
		var offset = Vector2(
			randf_range(-current_shake_intensity, current_shake_intensity),
			randf_range(-current_shake_intensity, current_shake_intensity)
		)
		control_node.position = original_control_pos + offset
	else:
		control_node.position = original_control_pos
	
	if action_buttons_ready and action_buttons.size() > 0:
		if _using_keyboard_nav:
			var kb_btn: Button = action_buttons[_action_button_index]
			var vp := get_viewport()
			if vp != null and vp.gui_get_focus_owner() != kb_btn:
				kb_btn.grab_focus()
		else:
			for i in range(action_buttons.size()):
				if action_buttons[i].is_hovered():
					_action_button_index = i
					break

	_apply_victory_action_button_highlight()

func setup(time_taken: float):
	# Stop all game logic and timer
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Stop background music if AudioManager exists
	# Use global AudioManager if available, otherwise try node path
	if AudioManager and AudioManager.has_method("stop_music"):
		AudioManager.stop_music()
	else:
		var audio_manager = get_node_or_null("/root/AudioManager")
		if audio_manager and audio_manager.has_method("stop_music"):
			audio_manager.stop_music()
		elif audio_manager:
			# Fallback if method name is different, trying to find common names
			for method in ["stop", "stop_all", "mute"]:
				if audio_manager.has_method(method):
					audio_manager.call(method)
					break

	# Ensure the SpeedLines are updating even when paused
	var speed_lines = $Control/SpeedLines
	if speed_lines.material:
		# Using the new stripes shader speed parameter
		speed_lines.material.set_shader_parameter("speed", 1.0)
	
	# Show action lines in victory screen
	if has_node("Control/ActionLines"):
		$Control/ActionLines.show()
	
	# Initial states
	time_label.text = "TIME: 00:00.00"
	time_label.modulate.a = 0
	time_label.scale = Vector2(1.5, 1.5) # 50% bigger initial display
	time_label.pivot_offset = time_label.size / 2
	
	if rank_container:
		rank_container.modulate.a = 0
		rank_container.scale = Vector2(5.0, 5.0) # Start huge for smash
		rank_container.pivot_offset = rank_container.size / 2
	
	rank_impact_label.modulate.a = 0
	rank_impact_label.pivot_offset = rank_impact_label.size / 2
	
	$Control/Panel/HBoxContainer.modulate.a = 0
	
	# Hide leaderboard initially
	if leaderboard_container:
		leaderboard_container.modulate.a = 0
	
	# Hide name entry initially
	if name_entry_container:
		name_entry_container.modulate.a = 0
	
	# Check if this time qualifies for the global leaderboard
	pending_time_taken = time_taken
	made_leaderboard = false
	name_submitted = false
	
	if LeaderboardManager:
		# CRITICAL: Fetch and set the current level's leaderboard BEFORE checking/displaying.
		# Otherwise we may show a different level's leaderboard (e.g. level 0 from startup).
		var level = LeaderboardManager.get_current_level_index()
		LeaderboardManager.last_submitted_level = level
		LeaderboardManager.fetch_global_leaderboard(level)
		
		made_leaderboard = LeaderboardManager.would_make_leaderboard(time_taken)
		
		if made_leaderboard:
			pass  # DON'T submit yet — wait for the player to enter their name
		else:
			# Submit immediately with existing player name
			LeaderboardManager.add_score(time_taken)
		
		# Connect to leaderboard update signal to refresh display when data arrives
		if not LeaderboardManager.global_leaderboard_updated.is_connected(_on_global_leaderboard_updated):
			LeaderboardManager.global_leaderboard_updated.connect(_on_global_leaderboard_updated)
	
	# Unlock next level
	unlock_next_level()
	action_buttons_ready = false
	
	var rank = calculate_rank(time_taken)
	var rank_upper = rank.to_upper()
	
	# Split rank into first letter and rest
	if rank_first_letter and rank_label:
		if rank_upper.length() > 0:
			rank_first_letter.text = rank_upper[0]
			if rank_upper.length() > 1:
				rank_label.text = rank_upper.substr(1)
			else:
				rank_label.text = ""
	
	# Split impact label too
	if rank_impact_first_letter and rank_impact_label:
		if rank_upper.length() > 0:
			rank_impact_first_letter.text = rank_upper[0]
			if rank_upper.length() > 1:
				rank_impact_label.text = rank_upper.substr(1)
			else:
				rank_impact_label.text = ""
	
	# Apply colors to both first letter and rest (matching in-game rank indicator)
	var rank_color: Color
	match rank:
		"Sonic": rank_color = Color(1.0, 0.0, 0.0, 1.0)       # Red (S rank)
		"Agile": rank_color = Color(1.0, 0.84, 0.0, 1.0)      # Gold (A rank)
		"Brisks": rank_color = Color(0.0, 0.4, 1.0, 1.0)      # Blue (B rank)
		"Casual": rank_color = Color(0.0, 1.0, 1.0, 1.0)      # Cyan (C rank)
		"Delayed": rank_color = Color(0.6, 0.3, 0.0, 1.0)     # Brown (D rank)
	
	if rank_first_letter:
		rank_first_letter.add_theme_color_override("font_color", rank_color)
	if rank_label:
		rank_label.add_theme_color_override("font_color", rank_color)

	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# 1. Time appears first
	tween.tween_property(time_label, "modulate:a", 1.0, 0.2)
	
	# Play climbing sound at start of counting
	tween.tween_callback(func():
		if score_climbing_sfx:
			climbing_player.stream = score_climbing_sfx
			climbing_player.volume_db = -5.0
			climbing_player.play()
	)
	
	# 2. Time ticks up gradually over 1.0s
	tween.tween_method(
		func(v): 
			var total_seconds = v
			var minutes = int(total_seconds / 60.0)
			var seconds = int(total_seconds) % 60
			var deciseconds = int((total_seconds - int(total_seconds)) * 100)  # Two decimal places (centiseconds)
			time_label.text = "TIME: %02d:%02d.%02d" % [minutes, seconds, deciseconds],
		0.0, time_taken, 1.0
	)
	
	# Stop climbing sound immediately after counting finishes
	tween.tween_callback(func():
		if climbing_player.playing:
			climbing_player.stop()
	)
	
	# 3. 0.5s delay
	tween.tween_interval(0.5)
	
	# 4. Rank smashes onto screen
	tween.tween_callback(func(): 
		# Stop climbing sound explicitly right before peak
		if climbing_player.playing:
			climbing_player.stop()
		
		# Safety stop sfx_player
		sfx_player.stop()
		
		if rank_container:
			rank_container.modulate.a = 1.0
		apply_ui_shake(20.0, 0.4)
		
		# Play peak sound when rank appears
		if score_peak_sfx:
			sfx_player.stream = score_peak_sfx
			sfx_player.volume_db = -2.0
			sfx_player.play()
		
		# Rank impact effect
		if rank_impact_container:
			rank_impact_container.modulate.a = 0.6
			rank_impact_container.scale = Vector2(1.0, 1.0)
			var impact_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			impact_tween.tween_property(rank_impact_container, "scale", Vector2(2.0, 2.0), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			impact_tween.parallel().tween_property(rank_impact_container, "modulate:a", 0.0, 0.3)
	)
	if rank_container:
		tween.tween_property(rank_container, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	
	tween.tween_interval(0.3)
	
	if made_leaderboard:
		# 5a. Show name entry instead of leaderboard
		tween.tween_callback(func():
			if name_entry_container:
				name_entry_container.modulate.a = 0
		)
		if name_entry_container:
			tween.tween_property(name_entry_container, "modulate:a", 1.0, 0.3)
		tween.tween_callback(func():
			# Focus the name input so the player can type immediately
			if name_input:
				name_input.grab_focus()
		)
		# Buttons are hidden until the player submits their name
	else:
		# 5b. Update and show leaderboard (no name entry needed)
		tween.tween_callback(_update_leaderboard_display)
		if leaderboard_container:
			tween.tween_property(leaderboard_container, "modulate:a", 1.0, 0.3)
		
		# 6. Buttons appear last
		tween.tween_property($Control/Panel/HBoxContainer, "modulate:a", 1.0, 0.3)
		tween.tween_callback(_on_victory_action_buttons_ready)

func _on_victory_action_buttons_ready() -> void:
	action_buttons_ready = true
	_action_button_index = 0
	_using_keyboard_nav = false
	if restart_btn:
		restart_btn.grab_focus()

func _activate_action_button(index: int) -> void:
	if index < 0 or index >= action_buttons.size():
		return
	match index:
		0:
			_on_restart_button_pressed()
		1:
			_on_leaderboard_button_pressed()
		2:
			_on_menu_button_pressed()

func _input(event):
	# Don't handle shortcuts while the player is typing their name
	if made_leaderboard and not name_submitted:
		return
	
	if not get_tree().paused:
		return
	
	if event is InputEventMouseMotion:
		_using_keyboard_nav = false
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_using_keyboard_nav = false
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_perform_restart()
			var vp_r := get_viewport()
			if vp_r != null:
				vp_r.set_input_as_handled()
			return
		if action_buttons_ready and action_buttons.size() > 0:
			var vp := get_viewport()
			var n: int = action_buttons.size()
			if event.keycode in [KEY_LEFT, KEY_A]:
				_using_keyboard_nav = true
				_action_button_index = (_action_button_index - 1 + n) % n
				action_buttons[_action_button_index].grab_focus()
				if vp != null:
					vp.set_input_as_handled()
			elif event.keycode in [KEY_RIGHT, KEY_D]:
				_using_keyboard_nav = true
				_action_button_index = (_action_button_index + 1) % n
				action_buttons[_action_button_index].grab_focus()
				if vp != null:
					vp.set_input_as_handled()
			elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_activate_action_button(_action_button_index)
				if vp != null:
					vp.set_input_as_handled()

func apply_ui_shake(intensity: float, duration: float):
	current_shake_intensity = intensity
	shake_timer = duration

func calculate_rank(time: float) -> String:
	if time < 100.0:
		return "Sonic"
	elif time < 175.0:
		return "Agile"
	elif time < 225.0:
		return "Brisks"
	elif time < 275.0:
		return "Casual"
	else:
		return "Delayed"

func _update_leaderboard_display():
	"""Update the leaderboard display with top 3 scores."""
	if not LeaderboardManager:
		return
	
	if not leaderboard_container:
		return
	
	_refresh_leaderboard_display()

func _refresh_leaderboard_display():
	"""Internal function to refresh the leaderboard display."""
	if not LeaderboardManager or not leaderboard_container:
		return
	
	# Get ONLY global scores from Supabase
	var global_scores = LeaderboardManager.get_top_scores(3, true)
	
	# Update title
	if leaderboard_title:
		leaderboard_title.text = "LEADERBOARD"
	
	var entries = [leaderboard_entry_1, leaderboard_entry_2, leaderboard_entry_3]
	
	# Clear all entries first
	for entry in entries:
		if entry:
			entry.text = ""
			entry.modulate.a = 0
	
	# Display top 3 scores from Supabase only
	var num_to_show = min(global_scores.size(), 3)
	for i in range(num_to_show):
		if entries[i]:
			var score_data = global_scores[i]
			var time = score_data["time"]
			var player_name = score_data.get("player_name", "Player")
			
			var minutes = int(time) / 60
			var seconds = int(time) % 60
			var centiseconds = int((time - int(time)) * 100)
			
			# Format display: NAME - MM:SS.SS
			var display_text = "%s - %02d:%02d.%02d" % [player_name, minutes, seconds, centiseconds]
			
			entries[i].text = display_text
			entries[i].modulate.a = 1.0

func _on_global_leaderboard_updated():
	"""Called when the global leaderboard is updated from the API."""
	# Refresh the display with new data
	_refresh_leaderboard_display()

func _on_name_submit_pressed():
	"""Called when the OK button is pressed after entering name."""
	_submit_player_name()

func _on_name_cancel_pressed():
	"""Called when the Cancel button is pressed — do not record the run to the leaderboard."""
	if name_submitted:
		return
	name_submitted = true
	# Transition to leaderboard display without adding score
	_animate_post_submission()

func _on_name_text_submitted(_text: String):
	"""Called when Enter is pressed in the name input field."""
	_submit_player_name()

func _on_name_input_text_changed(new_text: String):
	"""Auto-capitalize text as the player types."""
	var upper_text = new_text.to_upper()
	if upper_text != new_text:
		name_input.text = upper_text
		name_input.caret_column = upper_text.length()

func _submit_player_name():
	"""Process the player's name entry and submit the score."""
	if name_submitted:
		return
	
	var entered_name = name_input.text.strip_edges().to_upper()
	
	# Validate name
	if entered_name.is_empty():
		entered_name = "PLAYER"
	
	# Clamp to 10 chars (LineEdit max_length should handle this, but just in case)
	if entered_name.length() > 10:
		entered_name = entered_name.substr(0, 10)
	
	name_submitted = true
	
	# Check if name already exists on global leaderboard
	if LeaderboardManager:
		var existing_entry = LeaderboardManager.find_existing_entry_by_name(entered_name)
		
		if not existing_entry.is_empty():
			var existing_time = existing_entry["time"]
			
			if pending_time_taken < existing_time:
				# Current time is BETTER — update the existing entry
				LeaderboardManager.set_player_name(entered_name)
				LeaderboardManager.update_score_for_name(pending_time_taken)
				_animate_post_submission()
				return
			else:
				# Existing time is BETTER or EQUAL — show rejection message
				_show_name_exists_message()
				return
	
	# Name doesn't exist — normal submission flow
	if LeaderboardManager:
		LeaderboardManager.set_player_name(entered_name)
		LeaderboardManager.add_score(pending_time_taken)
	
	_animate_post_submission()

func _animate_post_submission():
	"""Animate transition from name entry to leaderboard display."""
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Fade out name entry
	if name_entry_container:
		tween.tween_property(name_entry_container, "modulate:a", 0.0, 0.2)
	
	# Show leaderboard
	tween.tween_callback(_update_leaderboard_display)
	if leaderboard_container:
		tween.tween_property(leaderboard_container, "modulate:a", 1.0, 0.3)
	
	# Show buttons
	tween.tween_property($Control/Panel/HBoxContainer, "modulate:a", 1.0, 0.3)
	tween.tween_callback(_on_victory_action_buttons_ready)

func _show_name_exists_message():
	"""Show a message that the name already exists with a better time, then transition."""
	var mark_lbl = $Control/Panel/NameEntryContainer/MarkLabel
	var prompt_lbl = $Control/Panel/NameEntryContainer/NamePromptLabel
	var input_row = $Control/Panel/NameEntryContainer/NameInputRow
	
	# Update message and hide input elements
	if mark_lbl:
		mark_lbl.text = "Name already exists with better result"
	if prompt_lbl:
		prompt_lbl.visible = false
	if input_row:
		input_row.visible = false
	
	# Wait 1 second, then transition to normal victory screen
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(1.0)
	tween.tween_callback(_animate_post_submission)

func _on_restart_button_pressed():
	_perform_restart()

func _perform_restart():
	# 1. Block input to prevent double clicks
	$Control.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 2. Trigger reload
	get_tree().paused = false
	LoadingIndicator.reload_scene()
	
	# 3. Do NOT remove UI immediately. 
	# It will be removed by player.gd in the new scene's _ready().
	# This covers the ugly reload frame/freeze.

func _on_leaderboard_button_pressed():
	# 1. Block input
	$Control.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 2. Unpause and go to leaderboard scene
	get_tree().paused = false
	
	# Hide Victory UI
	visible = false
	
	# Change scene to leaderboard
	if ResourceLoader.exists("res://leaderboard_scene.tscn"):
		LoadingIndicator.change_scene("res://leaderboard_scene.tscn")
	else:
		push_error("VictoryUI: leaderboard_scene.tscn not found!")
	
	# Clean up
	queue_free()

func _on_menu_button_pressed():
	# 1. Block input
	$Control.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 2. Unpause and go to level select menu
	get_tree().paused = false
	
	# Hide Victory UI
	visible = false
	
	# Change scene to level select menu
	if ResourceLoader.exists("res://level_select_menu.tscn"):
		LoadingIndicator.change_scene("res://level_select_menu.tscn")
	else:
		push_error("VictoryUI: level_select_menu.tscn not found!")
	
	# Clean up
	queue_free()

func unlock_next_level():
	"""Unlock the next level after completing the current one"""
	const SAVE_FILE_PATH = "user://level_progress.cfg"
	
	# Keep this in sync with `level_select_menu.tscn` metadata order.
	var ordered_levels = [
		"res://level.tscn",      # Level 1 - The First Minute
		"res://level1.tscn",     # Level 2 - The Escape
		"res://level2.tscn",     # Level 3 - Burning Bright
		"res://level1.1.tscn",   # Level 4
		"res://level1.2.tscn",   # Level 5
		"res://level1.3.tscn"    # Level 6
	]
	# Accept alternate/legacy scene paths that should map to the same level index.
	var level_path_alias_to_index := {
		"res://level.tscn": 0,
		"res://level1.tscn": 1,
		"res://level2.tscn": 2,
		"res://level1.1.tscn": 3,
		"res://level1.2.tscn": 4,
		"res://level1.3.tscn": 5
	}
	
	# Get current scene path
	var current_scene_path = get_tree().current_scene.scene_file_path
	
	# Find current level index
	var current_level_index: int = int(level_path_alias_to_index.get(current_scene_path, -1))
	if current_level_index == -1:
		for i in range(ordered_levels.size()):
			if ordered_levels[i] == current_scene_path:
				current_level_index = i
				break
	
	if current_level_index == -1:
		push_warning("VictoryUI: unlock_next_level skipped, unknown scene path: " + str(current_scene_path))
		return
	
	# Calculate next level index
	var next_level_index = current_level_index + 1
	if next_level_index >= ordered_levels.size():
		return

	# Load existing progress
	var config = ConfigFile.new()
	var error = config.load(SAVE_FILE_PATH)
	if error != OK:
		# File doesn't exist, create new one
		config = ConfigFile.new()
	
	# Unlock next level
	var key = "level_%d_unlocked" % (next_level_index + 1)
	config.set_value("progress", key, true)
	
	# Save progress
	error = config.save(SAVE_FILE_PATH)
	if error != OK:
		push_error("VictoryUI: Failed to save level progress: " + str(error))
	else:
		pass
