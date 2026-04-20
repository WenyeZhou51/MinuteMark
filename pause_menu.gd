extends CanvasLayer

enum TransitionType {
	SCREEN_TRANSITION,  # Texture-based dissolve
	POLKA_DOTS          # Circular dots dissolve
}

@export_group("Transition Settings")
@export var use_transition_effect: bool = true
@export var transition_type: TransitionType = TransitionType.SCREEN_TRANSITION
@export var transition_duration: float = 0.4
@export var transition_texture: Texture2D

@export_group("Animation Settings")
@export var pause_bg_fade_duration: float = 0.2  # Duration of pause background fade-in
@export var pocket_watch_fade_duration: float = 0.2  # Duration of pocket watch fade-in
@export var pocket_watch_fps: float = 10.0  # Speed of pocket watch animation (frames per second)
@export var white_overlay_slide_distance: float = 50.0  # Distance to slide white overlay
@export var white_overlay_slide_duration: float = 0.3  # Duration of white overlay slide
@export var menu_fade_duration: float = 0.3  # Duration of menu text/buttons fade-in

var transition_shader_screen: Shader = preload("res://shaders/screen_transition_shader.gdshader")
var transition_shader_polka: Shader = preload("res://shaders/polka_dots.gdshader")
var transition_rect: TextureRect
var is_transitioning: bool = false
var is_animating_in: bool = false

# Inner menu state
var current_inner_menu: Control = null
var inner_menus: Dictionary = {}

# Keep track of the last focused button in the main menu
var last_focused_button: Control = null

# Audio
var menu_transition_player: AudioStreamPlayer
var menu_select_player: AudioStreamPlayer
var pause_music_player: AudioStreamPlayer

# Keep track of where we came from
var opened_from_victory: bool = false

func _ready():
	# Initialize pause menu
	hide()
	
	# Set Level Name
	if has_node("MenuContainer/Title"):
		var title = $MenuContainer/Title
		title.text = "The First Second"
		# Make it more distinct but keep B&W style: 
		# Bigger, Black with White outline (inverted from buttons which are often black text)
		title.add_theme_font_size_override("font_size", 280)
		title.add_theme_color_override("font_color", Color(0, 0, 0, 1)) # Black
		title.add_theme_color_override("font_outline_color", Color(1, 1, 1, 1)) # White outline
		title.add_theme_constant_override("outline_size", 25) # Thicker outline
		title.rotation_degrees = -8 # Tilted more aggressively
		
		# Reset any previous offset first to avoid accumulation if this runs multiple times (though _ready runs once)
		# But wait, original .tscn might have offsets. We should be careful about " += ".
		# The original offset_top is -613 and offset_bottom -404.
		# Let's set absolute position if possible or just use what we have.
		# A safer way to "move down" is to just set position relative to anchor center.
		# It's anchored to center (0.5, 0.5).
		
		# Original offsets: top -613, bottom -404.
		# We want to move it down by 150.
		# New target: top -463, bottom -254.
		
		title.offset_top = -463
		title.offset_bottom = -254
	
	# Load default transition texture if not set
	if transition_texture == null:
		transition_texture = load("res://textures/screen_transition_test.png")
	
	# Setup pocket watch animation frames
	setup_pocket_watch_animation()
	
	# Setup initial visibility states for animation elements
	if has_node("PauseBg"):
		$PauseBg.visible = false
	if has_node("PocketWatch"):
		$PocketWatch.visible = false
	if has_node("WhiteOverlay"):
		$WhiteOverlay.visible = false
		$WhiteOverlay.modulate.a = 0.0
	if has_node("MenuContainer"):
		$MenuContainer.visible = false
	
	# Setup inner menus
	if has_node("SettingsMenu"):
		inner_menus["settings"] = $SettingsMenu
	if has_node("InputMenu"):
		inner_menus["inputs"] = $InputMenu
	
	# Setup Restart Button if it doesn't exist (Dynamic injection)
	if has_node("MenuContainer") and not has_node("MenuContainer/RestartButton"):
		_inject_restart_button()
	elif has_node("MenuContainer/RestartButton"):
		# Connect if already exists (e.g. from manual edit)
		if not $MenuContainer/RestartButton.pressed.is_connected(_on_restart_pressed):
			$MenuContainer/RestartButton.pressed.connect(_on_restart_pressed)
	
	# Setup audio players
	setup_audio_players()
	
	# Connect to all buttons for hover/select sounds
	setup_button_audio_connections()
	
	# Connect hover-to-focus so mouse hover triggers the same scale/indicator effect as keyboard focus
	setup_menu_button_hover()

	# Set focus order by visual position so S/Down moves top-to-bottom correctly
	call_deferred("_update_pause_menu_focus_order")


func _update_pause_menu_focus_order():
	"""Set focus_neighbor_top/bottom so keyboard (S/Down) navigates buttons in visual top-to-bottom order."""
	if not has_node("MenuContainer"):
		return
	var buttons: Array[Control] = []
	for child in $MenuContainer.get_children():
		if child is Button and child.focus_mode != Control.FOCUS_NONE and child.visible:
			buttons.append(child)
	if buttons.is_empty():
		return
	# Sort by vertical position (top = smaller Y)
	buttons.sort_custom(func(a: Control, b: Control) -> bool:
		return a.global_position.y < b.global_position.y
	)
	for i in range(buttons.size()):
		var btn = buttons[i]
		var prev = buttons[i - 1] if i > 0 else buttons[buttons.size() - 1]
		var next = buttons[i + 1] if i < buttons.size() - 1 else buttons[0]
		btn.focus_neighbor_top = prev.get_path()
		btn.focus_neighbor_bottom = next.get_path()


var pocket_watch_frames: Array[Texture2D] = []

func setup_pocket_watch_animation():
	"""Load pocket watch GIF frames"""
	if not has_node("PocketWatch"):
		return
	
	# Load all frame images
	var frame_path = "res://Sprites/pocket_watch_frames/frame_%04d.png"
	
	# Try loading frames (we have 11 frames: 0-10)
	for i in range(20):  # Try up to 20 frames to be safe
		var path = frame_path % i
		if ResourceLoader.exists(path):
			var texture = load(path)
			pocket_watch_frames.append(texture)
		else:
			break  # No more frames
	
	if pocket_watch_frames.size() == 0:
		push_warning("No pocket watch frames found! Make sure to run convert_gif_to_frames.py")


func _inject_restart_button():
	var resume_btn = $MenuContainer/ResumeButton
	if not resume_btn:
		return
		
	var restart_btn = resume_btn.duplicate()
	restart_btn.name = "RestartButton"
	restart_btn.text = "RESTART" # This sets button text property if using standard button
	
	# If using custom setup with child Label (as seen in .tscn)
	var label = restart_btn.get_node_or_null("ButtonContent/Label")
	if label:
		label.text = "RESTART"
		
	# Adjust properties
	restart_btn.focus_neighbor_top = resume_btn.get_path()
	restart_btn.focus_neighbor_bottom = resume_btn.focus_neighbor_bottom
	
	# Add to container
	$MenuContainer.add_child(restart_btn)
	# Position it below Resume (this is tricky with manual layout, let's try to infer)
	# Resume is at y=-300 (top) to -220 (bottom)
	# There is a gap. Video is at -95.
	# We can put Restart in between? Or re-layout.
	# Let's put it at y=-150 roughly.
	
	restart_btn.anchor_left = 0.5
	restart_btn.anchor_top = 0.5
	restart_btn.anchor_right = 0.5
	restart_btn.anchor_bottom = 0.5
	
	# Current Resume: top=-300, bottom=-220.
	# Current Video: top=-95.
	# Current Audio: top=90.
	# Current Input: top=275.
	# Current Quit: top=460.
	
	# We have 5 buttons now (Resume, Restart, Video, Audio, Input, Quit) -> 6 buttons!
	# The screen height is ~1600 based on project.godot
	# Center is 0.
	
	# Let's redistribute ALL buttons evenly if we are injecting
	
	var spacing = 150 # Increased spacing (was 120, originally 140)
	var start_y = -200 # Moved down slightly (was -250, originally -150)
	
	var buttons = []
	if has_node("MenuContainer/ResumeButton"): buttons.append($MenuContainer/ResumeButton)
	buttons.append(restart_btn) # The new one
	if has_node("MenuContainer/SettingsButton"): buttons.append($MenuContainer/SettingsButton)
	if has_node("MenuContainer/MenuButton"): buttons.append($MenuContainer/MenuButton)
	if has_node("MenuContainer/InputButton"): buttons.append($MenuContainer/InputButton)
	if has_node("MenuContainer/QuitButton"): buttons.append($MenuContainer/QuitButton)
	
	for i in range(buttons.size()):
		var btn = buttons[i]
		var y_pos = start_y + (i * spacing)
		
		# Keep horizontal centering but update vertical
		btn.anchor_top = 0.5
		btn.anchor_bottom = 0.5
		btn.offset_top = y_pos - 40 # Height 80/2
		btn.offset_bottom = y_pos + 40
		
		# Reset rotation to look cleaner or alternate slightly
		btn.rotation = randf_range(-0.03, 0.03) 
		
	# Connect signal (need to disconnect old one from duplicate)
	if restart_btn.pressed.is_connected(_on_resume_pressed):
		restart_btn.pressed.disconnect(_on_resume_pressed)
	
	if not restart_btn.pressed.is_connected(_on_restart_pressed):
		restart_btn.pressed.connect(_on_restart_pressed)
	
	# Update focus neighbors based on new order
	for i in range(buttons.size()):
		var btn = buttons[i]
		var prev = buttons[i-1] if i > 0 else buttons[buttons.size()-1]
		var next = buttons[i+1] if i < buttons.size()-1 else buttons[0]
		
		btn.focus_neighbor_top = prev.get_path()
		btn.focus_neighbor_bottom = next.get_path()

func _input(event):
	if visible and current_inner_menu == null and event is InputEventKey and event.pressed and not event.echo and not is_transitioning and not is_animating_in:
		# Requested remap for pause menu navigation:
		# Right behaves like Down (next item), Up behaves like Left (previous item).
		if event.keycode in [KEY_RIGHT, KEY_D, KEY_S]:
			if _move_main_menu_focus(1):
				get_viewport().set_input_as_handled()
				return
		elif event.keycode in [KEY_UP, KEY_LEFT, KEY_W, KEY_A]:
			if _move_main_menu_focus(-1):
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("ui_cancel") and not is_transitioning and not is_animating_in:  # ESC key by default
		# Don't toggle pause if we're in an inner menu
		if current_inner_menu != null:
			return
			
		# Don't toggle pause if dialogue is active
		if DialogueManager.current_id != "":
			return
		
		# Check if Victory UI is active and visible
		var victory_ui = get_tree().root.find_child("VictoryUI", true, false)
		if victory_ui and victory_ui.visible:
			# Hide Victory UI just like the Menu button does
			victory_ui.visible = false
			victory_ui.queue_free()
			
			open_pause_menu(true) # Open as if from victory (disables resume)
			return
			
		toggle_pause()


func _move_main_menu_focus(step: int) -> bool:
	"""Move focus across main pause menu buttons."""
	if step == 0 or not has_node("MenuContainer"):
		return false
	var buttons: Array[Control] = []
	for child in $MenuContainer.get_children():
		if child is Button and child.focus_mode != Control.FOCUS_NONE and child.visible and not child.disabled:
			buttons.append(child)
	if buttons.is_empty():
		return false
	buttons.sort_custom(func(a: Control, b: Control) -> bool:
		return a.global_position.y < b.global_position.y
	)
	var focused := get_viewport().gui_get_focus_owner()
	var current_index := 0
	for i in range(buttons.size()):
		if buttons[i] == focused:
			current_index = i
			break
	var next_index := (current_index + step + buttons.size()) % buttons.size()
	buttons[next_index].grab_focus()
	return true


func _process(_delta):
	# Safeguard: Ensure mouse is visible when menu is open
	if visible and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func open_pause_menu(from_victory: bool = false):
	"""Explicitly open the pause menu (used by VictoryUI)"""
	if visible and not from_victory:
		return
		
	opened_from_victory = from_victory
	
	# Cancel any active rewind before pausing to ensure time_scale is reset
	_cancel_player_rewind()
	
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	
	# Pause level music and play pause menu music
	if AudioManager:
		AudioManager.pause_music()
	if pause_music_player and pause_music_player.stream:
		pause_music_player.play()
	
	play_menu_transition_sound()
	play_pause_menu_intro()
	
	# Update buttons state based on context
	_update_buttons_state()
	
	# Hide other UI
	_set_other_ui_visible(false)


func toggle_pause():
	var is_paused = not get_tree().paused
	
	if is_paused:
		# Cancel any active rewind before pausing to ensure time_scale is reset
		_cancel_player_rewind()
	
	get_tree().paused = is_paused
	
	if is_paused:
		opened_from_victory = false # Normal pause is not from victory
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		visible = true
		
		# Pause level music and play pause menu music
		if AudioManager:
			AudioManager.pause_music()
		if pause_music_player and pause_music_player.stream:
			pause_music_player.play()
			
		play_menu_transition_sound()
		play_pause_menu_intro()
		
		# Update buttons state
		_update_buttons_state()
		
		# Hide other UI (timer, dialogue, etc.)
		_set_other_ui_visible(false)
	else:
		# Stop pause menu music and resume level music
		if pause_music_player:
			pause_music_player.stop()
		if AudioManager:
			AudioManager.resume_music()
			
		# Restore assist time scale when exiting pause
		if get_tree().root.has_meta("assist_time_scale"):
			Engine.time_scale = get_tree().root.get_meta("assist_time_scale")
		else:
			Engine.time_scale = 1.0
		
		# Play transition effect when exiting pause menu
		if use_transition_effect:
			play_exit_transition()
		else:
			visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_set_other_ui_visible(true)

func _update_buttons_state():
	if not has_node("MenuContainer"):
		return
		
	# Handle Resume button visibility/state
	if has_node("MenuContainer/ResumeButton"):
		var resume_btn = $MenuContainer/ResumeButton
		if opened_from_victory:
			# Disable resume if came from victory
			resume_btn.visible = true
			resume_btn.disabled = true
			resume_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			resume_btn.focus_mode = Control.FOCUS_NONE
			# Grey it out
			resume_btn.modulate = Color(0.5, 0.5, 0.5, 0.5)
			
			# If we have a restart button, focus that instead
			if has_node("MenuContainer/RestartButton"):
				$MenuContainer/RestartButton.grab_focus()
		else:
			# Enable resume normally
			resume_btn.visible = true
			resume_btn.disabled = false
			resume_btn.mouse_filter = Control.MOUSE_FILTER_STOP
			resume_btn.focus_mode = Control.FOCUS_ALL
			resume_btn.modulate = Color(1, 1, 1, 1)
			resume_btn.grab_focus()

func _on_restart_pressed():
	if pause_music_player:
		pause_music_player.stop()
	
	# 1. Block input to prevent double clicks
	if has_node("MenuContainer"):
		$MenuContainer.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 2. Unpause the game so reload can happen
	get_tree().paused = false
	
	# 3. IMPORTANT: Restore other UI elements BEFORE reloading
	# This ensures persistent UI (like TutorialBlockManager's CanvasLayer) is visible
	_set_other_ui_visible(true)
	
	# 4. Use full scene reload to ensure everything resets correctly (same as Victory UI)
	LoadingIndicator.reload_scene()


func _cancel_player_rewind():
	"""Find the player and cancel any active rewind to ensure time_scale is reset."""
	var tree = get_tree()
	if not tree:
		return
	
	# Find the player node
	var player = tree.root.find_child("Player", true, false)
	if player and player.has_method("cancel_rewind_and_set_cooldown"):
		player.cancel_rewind_and_set_cooldown()


func _set_other_ui_visible(p_visible: bool):
	"""Toggles visibility of all other CanvasLayer UI elements (timer, etc.)"""
	var tree = get_tree()
	if not tree:
		return
		
	# Find all CanvasLayer nodes in the tree
	for node in tree.root.find_children("*", "CanvasLayer", true, false):
		# Don't hide our own layer or the root
		if node != self:
			node.visible = p_visible


func play_pause_menu_intro():
	"""Plays the complete pause menu introduction animation sequence"""
	is_animating_in = true
	
	# Step 1: Show pause background immediately
	if has_node("PauseBg"):
		$PauseBg.visible = true
		$PauseBg.modulate.a = 0.0
		var tween_bg = create_tween()
		tween_bg.tween_property($PauseBg, "modulate:a", 1.0, pause_bg_fade_duration)
	
	# Step 2: Wait a moment, then show pocket watch
	await get_tree().create_timer(pause_bg_fade_duration, true, false, true).timeout
	
	if has_node("PocketWatch") and pocket_watch_frames.size() > 0:
		$PocketWatch.visible = true
		$PocketWatch.modulate.a = 0.0
		
		# Set first frame
		$PocketWatch.texture = pocket_watch_frames[0]
		
		var tween_watch = create_tween()
		tween_watch.tween_property($PocketWatch, "modulate:a", 1.0, pocket_watch_fade_duration)
		
		# Play the animation by cycling through frames using the FPS inspector variable
		var time_per_frame = 1.0 / pocket_watch_fps
		
		for i in range(pocket_watch_frames.size()):
			await get_tree().create_timer(time_per_frame, true, false, true).timeout
			if has_node("PocketWatch"):
				$PocketWatch.texture = pocket_watch_frames[i]
		
		# Animation complete - pocket watch stays visible on last frame
	
	# Step 4: Show white overlay with slide-in effect
	if has_node("WhiteOverlay"):
		$WhiteOverlay.visible = true
		$WhiteOverlay.modulate.a = 0.0
		$WhiteOverlay.position.x = -white_overlay_slide_distance
		
		var tween_overlay = create_tween()
		tween_overlay.set_parallel(true)
		tween_overlay.tween_property($WhiteOverlay, "modulate:a", 1.0, white_overlay_slide_duration)
		tween_overlay.tween_property($WhiteOverlay, "position:x", 0.0, white_overlay_slide_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		await tween_overlay.finished
	
	# Step 5: Show menu container (text and buttons)
	if has_node("MenuContainer"):
		$MenuContainer.visible = true
		$MenuContainer.modulate.a = 0.0
		var tween_menu = create_tween()
		tween_menu.tween_property($MenuContainer, "modulate:a", 1.0, menu_fade_duration)
		await tween_menu.finished
	
	# Animation complete, allow interaction
	is_animating_in = false
	
	if opened_from_victory:
		# If came from victory, Resume is disabled, so focus Restart
		if has_node("MenuContainer/RestartButton"):
			$MenuContainer/RestartButton.grab_focus()
	elif has_node("MenuContainer/ResumeButton"):
		$MenuContainer/ResumeButton.grab_focus()


func play_exit_transition():
	is_transitioning = true
	
	# Capture current viewport screenshot
	var img = get_viewport().get_texture().get_image()
	var texture = ImageTexture.create_from_image(img)
	
	# Create transition overlay
	transition_rect = TextureRect.new()
	transition_rect.name = "TransitionOverlay"
	transition_rect.texture = texture
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.z_index = 1000  # Make sure it's on top
	
	# Apply the appropriate shader
	var shader_material = ShaderMaterial.new()
	if transition_type == TransitionType.SCREEN_TRANSITION:
		shader_material.shader = transition_shader_screen
		shader_material.set_shader_parameter("transition_pattern", transition_texture)
	else:  # POLKA_DOTS
		shader_material.shader = transition_shader_polka
	
	shader_material.set_shader_parameter("transition_state", 0.0)
	transition_rect.material = shader_material
	
	# Add to scene
	add_child(transition_rect)
	
	# Hide menu content but keep canvas layer visible for transition
	$MenuContainer.visible = false
	if has_node("Background"):
		$Background.visible = false
	
	# Hide animation elements
	if has_node("PauseBg"):
		$PauseBg.visible = false
	if has_node("PocketWatch"):
		$PocketWatch.visible = false
	if has_node("WhiteOverlay"):
		$WhiteOverlay.visible = false
	
	# Animate the transition
	var tween = create_tween()
	tween.tween_method(update_transition_state, 0.0, 1.0, transition_duration)
	tween.tween_callback(finish_exit_transition)


func update_transition_state(value: float):
	if transition_rect and transition_rect.material:
		transition_rect.material.set_shader_parameter("transition_state", value)


func finish_exit_transition():
	# Clean up transition overlay
	if transition_rect:
		remove_child(transition_rect)
		transition_rect.queue_free()
		transition_rect = null
	
	# Hide pause menu and restore game
	visible = false
	$MenuContainer.visible = true
	if has_node("Background"):
		$Background.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	is_transitioning = false
	
	# Show other UI again after transition finishes
	_set_other_ui_visible(true)
	
	# Reset animation elements for next time
	reset_animation_elements()


func reset_animation_elements():
	"""Reset all animation elements to their initial state"""
	if has_node("PauseBg"):
		$PauseBg.visible = false
		$PauseBg.modulate.a = 1.0
	if has_node("PocketWatch"):
		$PocketWatch.visible = false
		$PocketWatch.modulate.a = 1.0
		# Reset to first frame
		if pocket_watch_frames.size() > 0:
			$PocketWatch.texture = pocket_watch_frames[0]
	if has_node("WhiteOverlay"):
		$WhiteOverlay.visible = false
		$WhiteOverlay.modulate.a = 1.0
		$WhiteOverlay.position.x = 0.0
	if has_node("MenuContainer"):
		$MenuContainer.visible = false
		$MenuContainer.modulate.a = 1.0


func _on_resume_pressed():
	toggle_pause()


func _on_settings_pressed():
	show_inner_menu("settings")


func _on_inputs_pressed():
	show_inner_menu("inputs")


func show_inner_menu(menu_name: String):
	"""Show an inner menu with transition"""
	if not inner_menus.has(menu_name):
		return
	
	# Store current focus to restore it later
	var focused = get_viewport().gui_get_focus_owner()
	# Only store if it's one of our main menu buttons or inside the main menu container
	if focused and has_node("MenuContainer") and $MenuContainer.is_ancestor_of(focused):
		last_focused_button = focused
	elif has_node("MenuContainer") and $MenuContainer.get_child_count() > 0:
		# Fallback: manually map buttons if focus was lost or mouse was used
		# (This logic is implicit; if we clicked Video, Video button is likely focused or at least the intended target)
		if menu_name == "settings" and has_node("MenuContainer/SettingsButton"):
			last_focused_button = $MenuContainer/SettingsButton
		elif menu_name == "inputs" and has_node("MenuContainer/InputButton"):
			last_focused_button = $MenuContainer/InputButton
	
	# Play transition sound when entering inner menu
	play_menu_transition_sound()
	
	# Hide main menu elements (but keep background)
	# The pocket watch last frame disappears when inner menu starts
	if has_node("PocketWatch"):
		$PocketWatch.visible = false
	if has_node("WhiteOverlay"):
		$WhiteOverlay.visible = false
	if has_node("MenuContainer"):
		$MenuContainer.visible = false
	
	# Show the requested inner menu
	current_inner_menu = inner_menus[menu_name]
	current_inner_menu.show_menu()


func show_main_menu():
	"""Return to main pause menu from inner menu (instant, no animation)"""
	# Hide current inner menu if any
	if current_inner_menu:
		current_inner_menu.visible = false
		current_inner_menu = null
	
	# Show main menu elements again
	if has_node("PocketWatch"):
		$PocketWatch.visible = true
		# Already on last frame from initial animation
	if has_node("WhiteOverlay"):
		$WhiteOverlay.visible = true
	if has_node("MenuContainer"):
		$MenuContainer.visible = true
		# Restore focus to last used button
		if last_focused_button and is_instance_valid(last_focused_button) and last_focused_button.is_visible_in_tree():
			last_focused_button.grab_focus()
		elif has_node("MenuContainer/ResumeButton"):
			$MenuContainer/ResumeButton.grab_focus()


func show_main_menu_after_transition():
	"""Called after inner menu reverse animation completes - show pocket watch last frame"""
	current_inner_menu = null
	
	# Play transition sound when returning to pause menu
	play_menu_transition_sound()
	
	# Show pocket watch last frame (appears after inner menu animation finishes)
	if has_node("PocketWatch"):
		$PocketWatch.visible = true
		$PocketWatch.modulate.a = 0.0
		
		# Fade in the pocket watch last frame
		var tween_watch = create_tween()
		tween_watch.tween_property($PocketWatch, "modulate:a", 1.0, 0.2)
		await tween_watch.finished
	
	# Show other main menu elements
	if has_node("WhiteOverlay"):
		$WhiteOverlay.visible = true
	if has_node("MenuContainer"):
		$MenuContainer.visible = true
		# Restore focus to last used button
		if last_focused_button and is_instance_valid(last_focused_button) and last_focused_button.is_visible_in_tree():
			last_focused_button.grab_focus()
		elif has_node("MenuContainer/ResumeButton"):
			$MenuContainer/ResumeButton.grab_focus()


func _on_menu_pressed():
	"""Return to level select menu"""
	if pause_music_player:
		pause_music_player.stop()
	get_tree().paused = false
	_set_other_ui_visible(true)
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.scene_file_path != "":
		get_tree().root.set_meta("level_select_target_scene_path", current_scene.scene_file_path)
	if ResourceLoader.exists("res://level_select_menu.tscn"):
		LoadingIndicator.change_scene("res://level_select_menu.tscn")
	else:
		push_error("PauseMenu: level_select_menu.tscn not found!")


func _on_quit_pressed():
	if pause_music_player:
		pause_music_player.stop()
	get_tree().quit()


func setup_audio_players():
	"""Create audio players for menu sounds"""
	# Create menu transition sound player
	menu_transition_player = AudioStreamPlayer.new()
	menu_transition_player.name = "MenuTransitionPlayer"
	menu_transition_player.bus = "Master"
	add_child(menu_transition_player)
	
	# Create menu select sound player
	menu_select_player = AudioStreamPlayer.new()
	menu_select_player.name = "MenuSelectPlayer"
	menu_select_player.bus = "Master"
	add_child(menu_select_player)
	
	# Load audio files (using your existing audio files)
	if ResourceLoader.exists("res://audio/Menu transition.ogg"):
		menu_transition_player.stream = load("res://audio/Menu transition.ogg")
	elif ResourceLoader.exists("res://audio/menu_transition.ogg"):
		menu_transition_player.stream = load("res://audio/menu_transition.ogg")
	elif ResourceLoader.exists("res://audio/Menu transition.mp3"):
		menu_transition_player.stream = load("res://audio/Menu transition.mp3")
	elif ResourceLoader.exists("res://audio/menu_transition.ogg"):
		menu_transition_player.stream = load("res://audio/menu_transition.ogg")
	
	if ResourceLoader.exists("res://audio/menu select.ogg"):
		menu_select_player.stream = load("res://audio/menu select.ogg")
	elif ResourceLoader.exists("res://audio/menu_select.ogg"):
		menu_select_player.stream = load("res://audio/menu_select.ogg")
	elif ResourceLoader.exists("res://audio/menu_select.mp3"):
		menu_select_player.stream = load("res://audio/menu_select.mp3")
	
	# Create pause menu background music player
	pause_music_player = AudioStreamPlayer.new()
	pause_music_player.name = "PauseMusicPlayer"
	pause_music_player.bus = "Master"
	pause_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_music_player)
	if not pause_music_player.finished.is_connected(_on_pause_music_finished):
		pause_music_player.finished.connect(_on_pause_music_finished)
	
	if ResourceLoader.exists("res://audio/Pause menu music.wav"):
		pause_music_player.stream = load("res://audio/Pause menu music.wav")
	_set_pause_music_loop_disabled()


func _set_pause_music_loop_disabled():
	"""Disable embedded loop settings so finished-signal restarts are reliable."""
	if not pause_music_player or not pause_music_player.stream:
		return
	var stream = pause_music_player.stream
	if stream is AudioStreamWAV:
		var wav_stream := stream as AudioStreamWAV
		wav_stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		var ogg_stream := stream as AudioStreamOggVorbis
		ogg_stream.loop = false
	elif stream is AudioStreamMP3:
		var mp3_stream := stream as AudioStreamMP3
		mp3_stream.loop = false


func _on_pause_music_finished():
	"""Keep pause menu BGM running while the menu stays open."""
	if visible and pause_music_player and pause_music_player.stream:
		pause_music_player.play()


func setup_menu_button_hover():
	"""Connect mouse_entered to grab_focus for all main menu buttons so hover shows focus effect"""
	if not has_node("MenuContainer"):
		return
	for child in $MenuContainer.get_children():
		if child is Button:
			if not child.mouse_entered.is_connected(_on_menu_button_hover_entered):
				child.mouse_entered.connect(_on_menu_button_hover_entered.bind(child))


func _on_menu_button_hover_entered(btn: Button):
	"""When hovering a menu button, give it focus so the Juicy focus/scale effect plays"""
	if btn and is_instance_valid(btn):
		btn.grab_focus()


func setup_button_audio_connections():
	"""Connect audio to all buttons and controls"""
	# Connect to main menu buttons
	if has_node("MenuContainer"):
		_connect_controls_recursive($MenuContainer)
	
	# Connect to inner menu buttons
	for menu_name in inner_menus:
		var menu = inner_menus[menu_name]
		# Recursively connect to the WHOLE menu, not just MenuContainer
		# This ensures buttons outside MenuContainer (like BackButton in InputMenu) are connected
		_connect_controls_recursive(menu)


func _connect_controls_recursive(node: Node):
	"""Recursively connect audio to all interactive controls"""
	for child in node.get_children():
		# Connect buttons
		if child is Button:
			if not child.focus_entered.is_connected(_on_menu_item_focused):
				child.focus_entered.connect(_on_menu_item_focused)
			if not child.mouse_entered.is_connected(_on_menu_item_hovered):
				child.mouse_entered.connect(_on_menu_item_hovered)
		
		# Connect sliders
		elif child is HSlider:
			if not child.focus_entered.is_connected(_on_menu_item_focused):
				child.focus_entered.connect(_on_menu_item_focused)
			if not child.mouse_entered.is_connected(_on_menu_item_hovered):
				child.mouse_entered.connect(_on_menu_item_hovered)
			if not child.value_changed.is_connected(_on_slider_value_changed):
				child.value_changed.connect(_on_slider_value_changed)
		
		# Connect checkboxes/toggles
		elif child is CheckButton or child is CheckBox:
			if not child.focus_entered.is_connected(_on_menu_item_focused):
				child.focus_entered.connect(_on_menu_item_focused)
			if not child.mouse_entered.is_connected(_on_menu_item_hovered):
				child.mouse_entered.connect(_on_menu_item_hovered)
			if not child.toggled.is_connected(_on_toggle_changed):
				child.toggled.connect(_on_toggle_changed)
		
		# Recurse into children, but ONLY if they are containers or Control nodes that might contain buttons
		# We should be careful not to recurse into something that isn't a container if it has many children
		if child.get_child_count() > 0:
			_connect_controls_recursive(child)


func _on_menu_item_focused():
	"""Play select sound when focusing on a menu item"""
	play_menu_select_sound()


func _on_menu_item_hovered():
	"""Play select sound when hovering over a menu item"""
	play_menu_select_sound()


func _on_slider_value_changed(_value: float):
	"""Called when slider value changes - no sound to avoid spam"""
	pass  # Don't play sound on every slider adjustment


func _on_toggle_changed(_toggled_on: bool):
	"""Play select sound when toggle changes"""
	play_menu_select_sound()


func play_menu_transition_sound():
	"""Play the menu transition sound effect"""
	if menu_transition_player and menu_transition_player.stream:
		menu_transition_player.play()


func play_menu_select_sound():
	"""Play the menu select sound effect"""
	if menu_select_player and menu_select_player.stream:
		menu_select_player.play()
