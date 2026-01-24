extends CanvasLayer

@onready var time_label = $Control/Panel/TimeLabel
@onready var rank_label = $Control/Panel/RankLabel
@onready var rank_impact_label = $Control/Panel/RankImpactLabel
@onready var animation_player = $AnimationPlayer
@onready var control_node = $Control

var current_shake_intensity: float = 0.0
var shake_timer: float = 0.0
var original_control_pos: Vector2

func _ready():
	# Make sure the UI is visible and top-most
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	original_control_pos = control_node.position
	
	# Setup pivots for scaling effects
	time_label.pivot_offset = time_label.size / 2
	rank_label.pivot_offset = rank_label.size / 2
	rank_impact_label.pivot_offset = rank_impact_label.size / 2
	
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
		speed_lines.material.set_shader_parameter("speed", 10.0)
	
	# Initial states
	time_label.text = "TIME: 00:00"
	time_label.modulate.a = 0
	time_label.scale = Vector2(1.5, 1.5) # 50% bigger initial display
	time_label.pivot_offset = time_label.size / 2
	
	rank_label.modulate.a = 0
	rank_label.scale = Vector2(5.0, 5.0) # Start huge for smash
	rank_label.pivot_offset = rank_label.size / 2
	
	rank_impact_label.modulate.a = 0
	rank_impact_label.pivot_offset = rank_impact_label.size / 2
	
	$Control/Panel/HBoxContainer.modulate.a = 0
	
	var rank = calculate_rank(time_taken)
	if rank_label:
		rank_label.text = rank.to_upper()
		rank_impact_label.text = rank.to_upper()
		match rank:
			"Sonic": rank_label.add_theme_color_override("font_color", Color.CYAN)
			"Agile": rank_label.add_theme_color_override("font_color", Color.GREEN)
			"Brisks": rank_label.add_theme_color_override("font_color", Color.YELLOW)
			"Casual": rank_label.add_theme_color_override("font_color", Color.ORANGE)
			"Delayed": rank_label.add_theme_color_override("font_color", Color.RED)

	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# 1. Time appears first
	tween.tween_property(time_label, "modulate:a", 1.0, 0.2)
	
	# 2. Time ticks up gradually over 1.0s
	tween.tween_method(
		func(v): 
			var seconds = int(v)
			var centiseconds = int((v - seconds) * 100)
			time_label.text = "TIME: %02d:%02d" % [seconds, centiseconds],
		0.0, time_taken, 1.0
	)
	
	# 3. 0.5s delay
	tween.tween_interval(0.5)
	
	# 4. Rank smashes onto screen
	tween.tween_callback(func(): 
		rank_label.modulate.a = 1.0
		apply_ui_shake(20.0, 0.4)
		
		# Rank impact effect
		rank_impact_label.modulate.a = 0.6
		rank_impact_label.scale = Vector2(1.0, 1.0)
		var impact_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		impact_tween.tween_property(rank_impact_label, "scale", Vector2(2.0, 2.0), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		impact_tween.parallel().tween_property(rank_impact_label, "modulate:a", 0.0, 0.3)
	)
	tween.tween_property(rank_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	
	tween.tween_interval(0.3)
	
	# 5. Buttons appear last
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

