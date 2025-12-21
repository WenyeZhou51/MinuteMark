extends Control

## Base class for all inner menus (video, audio, assist)
## Handles the shared animation logic and transition system

@export_group("Animation Settings")
@export var inner_menu_fade_duration: float = 0.2  # Duration of inner menu gif fade-in
@export var inner_menu_fps: float = 60.0  # Speed of inner menu animation (frames per second)
@export var white_overlay_slide_distance: float = 50.0  # Distance to slide white overlay
@export var white_overlay_slide_duration: float = 0.3  # Duration of white overlay slide
@export var menu_fade_duration: float = 0.3  # Duration of menu options fade-in
@export var option_stagger_delay: float = 0.1  # Delay between each option appearing (left to right)

var inner_menu_frames: Array[Texture2D] = []
var is_animating_in: bool = false
var is_animating_out: bool = false
var is_visible_flag: bool = false

# Override these in derived classes
func get_menu_title() -> String:
	return "SETTINGS"

func setup_menu_options() -> void:
	pass


func _ready():
	# Setup inner menu animation frames
	setup_inner_menu_animation()
	
	# Setup initial visibility states for animation elements
	if has_node("InnerMenuBg"):
		$InnerMenuBg.visible = false
	if has_node("WhiteOverlay"):
		$WhiteOverlay.visible = false
		$WhiteOverlay.modulate.a = 0.0
	if has_node("MenuContainer"):
		$MenuContainer.visible = false
	
	# Hide the entire control initially
	visible = false


func setup_inner_menu_animation():
	"""Load inner menu GIF frames"""
	if not has_node("InnerMenuBg"):
		return
	
	# Load all frame images
	var frame_path = "res://Sprites/inner_menu_frames/frame_%04d.png"
	
	# Try loading frames (we have 11 frames: 0-10)
	for i in range(20):  # Try up to 20 frames to be safe
		var path = frame_path % i
		if ResourceLoader.exists(path):
			var texture = load(path)
			inner_menu_frames.append(texture)
		else:
			break  # No more frames
	
	if inner_menu_frames.size() > 0:
		# print("Loaded %d frames for inner menu animation" % inner_menu_frames.size())
		pass
	else:
		push_warning("No inner menu frames found!")


func show_menu():
	"""Show this inner menu with animation"""
	if is_animating_in:
		return
	
	visible = true
	is_visible_flag = true
	play_inner_menu_intro()


func hide_menu():
	"""Hide this inner menu with reverse animation"""
	if is_animating_out:
		return
	
	is_visible_flag = false
	play_inner_menu_outro()


func play_inner_menu_intro():
	"""Plays the complete inner menu introduction animation sequence"""
	is_animating_in = true
	
	# Step 1: Show inner menu background and play animation
	if has_node("InnerMenuBg") and inner_menu_frames.size() > 0:
		$InnerMenuBg.visible = true
		$InnerMenuBg.modulate.a = 0.0
		
		# Set first frame
		$InnerMenuBg.texture = inner_menu_frames[0]
		
		var tween_bg = create_tween()
		tween_bg.tween_property($InnerMenuBg, "modulate:a", 1.0, inner_menu_fade_duration)
		
		# Play the animation by cycling through frames
		var time_per_frame = 1.0 / inner_menu_fps
		
		for i in range(inner_menu_frames.size()):
			await get_tree().create_timer(time_per_frame).timeout
			if has_node("InnerMenuBg"):
				$InnerMenuBg.texture = inner_menu_frames[i]
		
		# Animation complete - inner menu stays visible on last frame
	
	# Step 2: Show white overlay with slide-in effect
	if has_node("WhiteOverlay"):
		$WhiteOverlay.visible = true
		$WhiteOverlay.modulate.a = 0.0
		$WhiteOverlay.position.x = -white_overlay_slide_distance
		
		var tween_overlay = create_tween()
		tween_overlay.set_parallel(true)
		tween_overlay.tween_property($WhiteOverlay, "modulate:a", 1.0, white_overlay_slide_duration)
		tween_overlay.tween_property($WhiteOverlay, "position:x", 0.0, white_overlay_slide_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		await tween_overlay.finished
	
	# Step 3: Fade in all menu options at once
	if has_node("MenuContainer"):
		$MenuContainer.visible = true
		$MenuContainer.modulate.a = 0.0
		
		# Fade in entire menu container at once
		var tween_menu = create_tween()
		tween_menu.tween_property($MenuContainer, "modulate:a", 1.0, menu_fade_duration)
		await tween_menu.finished
	
	# Animation complete
	is_animating_in = false
	
	# Focus first focusable control
	_focus_first_control()


func _focus_first_control():
	"""Focus the first focusable control in the menu"""
	if not has_node("MenuContainer"):
		return
	
	for child in $MenuContainer.get_children():
		if child is Button or child is HSlider:
			child.grab_focus()
			break


func reset_animation_elements():
	"""Reset all animation elements to their initial state"""
	if has_node("InnerMenuBg"):
		$InnerMenuBg.visible = false
		$InnerMenuBg.modulate.a = 1.0
		# Reset to first frame
		if inner_menu_frames.size() > 0:
			$InnerMenuBg.texture = inner_menu_frames[0]
	if has_node("WhiteOverlay"):
		$WhiteOverlay.visible = false
		$WhiteOverlay.modulate.a = 1.0
		$WhiteOverlay.position.x = 0.0
	if has_node("MenuContainer"):
		$MenuContainer.visible = false
		# Reset all children alpha
		for child in $MenuContainer.get_children():
			child.modulate.a = 1.0


func _input(event):
	"""Handle back button to return to main pause menu"""
	if not is_visible_flag or is_animating_in or is_animating_out:
		return
	
	if event.is_action_pressed("ui_cancel"):  # ESC key
		# Consume the input so it doesn't bubble up to pause menu
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed():
	"""Return to main pause menu with reverse animation"""
	hide_menu()


func play_inner_menu_outro():
	"""Plays the inner menu exit animation (reverse)"""
	is_animating_out = true
	
	# Step 1: Hide menu options instantly (no fade out animation)
	if has_node("MenuContainer"):
		$MenuContainer.visible = false
	
	# Step 2: Fade out white overlay at 2x speed
	if has_node("WhiteOverlay"):
		var exit_overlay_duration = white_overlay_slide_duration / 2.0  # 2x speed
		var tween_overlay = create_tween()
		tween_overlay.set_parallel(true)
		tween_overlay.tween_property($WhiteOverlay, "modulate:a", 0.0, exit_overlay_duration)
		tween_overlay.tween_property($WhiteOverlay, "position:x", -white_overlay_slide_distance, exit_overlay_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		await tween_overlay.finished
		$WhiteOverlay.visible = false
	
	# Step 3: Play inner menu animation in REVERSE at 2x speed
	if has_node("InnerMenuBg") and inner_menu_frames.size() > 0:
		var time_per_frame = 1.0 / inner_menu_fps
		var reverse_time_per_frame = time_per_frame / 2.0  # 2x speed for exit
		
		# Play frames in reverse order at 2x speed
		for i in range(inner_menu_frames.size() - 1, -1, -1):
			await get_tree().create_timer(reverse_time_per_frame).timeout
			if has_node("InnerMenuBg"):
				$InnerMenuBg.texture = inner_menu_frames[i]
		
		# Fade out the inner menu background at 2x speed
		var exit_fade_duration = inner_menu_fade_duration / 2.0  # 2x speed
		var tween_bg = create_tween()
		tween_bg.tween_property($InnerMenuBg, "modulate:a", 0.0, exit_fade_duration)
		await tween_bg.finished
		
		$InnerMenuBg.visible = false
	
	# Animation complete - now hide and tell parent to show main menu
	visible = false
	is_animating_out = false
	reset_animation_elements()
	
	# Tell parent pause menu to show main menu
	if get_parent().has_method("show_main_menu_after_transition"):
		get_parent().show_main_menu_after_transition()


