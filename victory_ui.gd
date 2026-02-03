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

var current_shake_intensity: float = 0.0
var shake_timer: float = 0.0
var original_control_pos: Vector2

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
	
	# Ensure buttons are clickable even when paused
	var restart_btn = $Control/Panel/HBoxContainer/RestartButton
	var menu_btn = $Control/Panel/HBoxContainer/MenuButton
	
	restart_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Explicitly set focus mode to allow interaction
	restart_btn.focus_mode = Control.FOCUS_ALL
	menu_btn.focus_mode = Control.FOCUS_ALL
	
	# Ensure buttons are on top and not blocked
	restart_btn.mouse_filter = Control.MOUSE_FILTER_STOP
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
	if ResourceLoader.exists("res://audio/scoreClimbing.wav"):
		score_climbing_sfx = load("res://audio/scoreClimbing.wav")
	elif ResourceLoader.exists("res://audio/scoreClimbing.mp3"):
		score_climbing_sfx = load("res://audio/scoreClimbing.mp3")
		
	if not score_climbing_sfx:
		print("VictoryUI: Failed to load scoreClimbing sound! Check res://audio/")
		
	if ResourceLoader.exists("res://audio/scorePeak.wav"):
		score_peak_sfx = load("res://audio/scorePeak.wav")
	elif ResourceLoader.exists("res://audio/scorePeak.mp3"):
		score_peak_sfx = load("res://audio/scorePeak.mp3")
		
	if not score_peak_sfx:
		print("VictoryUI: Failed to load scorePeak sound! Check res://audio/")

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
	
	# Save score to leaderboard
	if LeaderboardManager:
		var is_new_best = LeaderboardManager.add_score(time_taken)
		if is_new_best:
			print("VictoryUI: New best score! Time: %.2f" % time_taken)
			print("VictoryUI: Player: %s (ID: %s, IP: %s)" % [
				LeaderboardManager.get_player_name(),
				LeaderboardManager.get_player_id(),
				LeaderboardManager.get_local_ip()
			])
		
		# Connect to leaderboard update signal to refresh display when data arrives
		if not LeaderboardManager.global_leaderboard_updated.is_connected(_on_global_leaderboard_updated):
			LeaderboardManager.global_leaderboard_updated.connect(_on_global_leaderboard_updated)
		
		# Don't fetch here - let the submission callback handle it
		# This ensures we wait for submission to complete first
	
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
	
	# Apply colors to both first letter and rest
	var rank_color: Color
	match rank:
		"Sonic": rank_color = Color.CYAN
		"Agile": rank_color = Color.GREEN
		"Brisks": rank_color = Color.YELLOW
		"Casual": rank_color = Color.ORANGE
		"Delayed": rank_color = Color.RED
	
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
	
	# 5. Update and show leaderboard
	tween.tween_callback(_update_leaderboard_display)
	if leaderboard_container:
		tween.tween_property(leaderboard_container, "modulate:a", 1.0, 0.3)
	
	# 6. Buttons appear last
	tween.tween_property($Control/Panel/HBoxContainer, "modulate:a", 1.0, 0.3)
	
func _input(event):
	# Fallback: Allow pressing 'R' or 'Enter' or 'Space' to restart if button fails
	if not get_tree().paused:
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_perform_restart()

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
			print("VictoryUI: Displaying rank #%d: %s" % [i + 1, display_text])

func _on_global_leaderboard_updated():
	"""Called when the global leaderboard is updated from the API."""
	# Refresh the display with new data
	_refresh_leaderboard_display()

func _on_restart_button_pressed():
	print("VictoryUI: Restart button pressed")
	_perform_restart()

func _perform_restart():
	# 1. Block input to prevent double clicks
	$Control.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 2. Trigger reload
	get_tree().paused = false
	get_tree().reload_current_scene()
	
	# 3. Do NOT remove UI immediately. 
	# It will be removed by player.gd in the new scene's _ready().
	# This covers the ugly reload frame/freeze.

func _on_menu_button_pressed():
	print("VictoryUI: Menu button pressed")
	# 1. Block input
	$Control.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 2. Open Pause Menu
	var pause_menu = get_tree().root.find_child("PauseMenu", true, false)
	if pause_menu:
		print("VictoryUI: Found PauseMenu, opening it")
		# We are currently paused. 
		
		# Let's hide Victory UI first
		visible = false
		
		# Force pause menu to open using the new explicit method
		if pause_menu.has_method("open_pause_menu"):
			pause_menu.open_pause_menu(true)
		elif pause_menu.has_method("toggle_pause"):
			# Fallback if old version
			get_tree().paused = false
			pause_menu.toggle_pause()
			
		# And destroy ourselves
		queue_free()
	else:
		# Fallback: Just reload the level if we can't find menu (or print error)
		print("VictoryUI: Could not find PauseMenu to switch to. Trying direct scene change.")
		# Try to find a MainMenu scene or just reload
		# get_tree().change_scene_to_file("res://MainMenu.tscn")
