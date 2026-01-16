extends Node2D
class_name MinorAnimSystem

## A minor animation system that plays an animation based on player proximity.
## Add an Area2D as a child node to define the trigger zone.

@export_group("Animation Settings")
@export var frame_folder: String = "res://Sprites/minor_anim_test_frames"
@export var frame_prefix: String = "frame_"
@export var fps: float = 10.0
@export var anim_scale: Vector2 = Vector2.ONE
@export var looping: bool = false # Default to false so it can finish
@export var show_first_frame_by_default: bool = false

@export_group("Behavior Settings")
@export var hide_when_inactive: bool = true
@export var repeatable: bool = false # Default to false as requested
@export var debug_mode: bool = false

var animated_sprite: AnimatedSprite2D
var trigger_area: Area2D
var has_played: bool = false
var is_playing: bool = false
var last_frame: int = -1

## Automatically counts how many frames exist in the folder
func _count_frames() -> int:
	var count = 0
	while true:
		var frame_path = "%s/%s%d.png" % [frame_folder, frame_prefix, count]
		if ResourceLoader.exists(frame_path):
			count += 1
		else:
			break
	return count

func _ready() -> void:
	if debug_mode:
		print("[MinorAnimSystem] _ready() called at position: ", global_position)
	
	# Setup Animation
	var frame_count = _count_frames()
	if debug_mode:
		print("[MinorAnimSystem] Found ", frame_count, " frames in ", frame_folder)
	
	if frame_folder != "" and frame_count > 0:
		animated_sprite = GifLoader.create_animated_sprite_from_frames(frame_folder, frame_prefix, frame_count, fps)
		if animated_sprite:
			# Set scale BEFORE adding to scene tree to prevent one frame at wrong scale
			animated_sprite.scale = anim_scale
			animated_sprite.centered = true  # Ensure proper centering
			add_child(animated_sprite)
			
			if animated_sprite.sprite_frames:
				animated_sprite.sprite_frames.set_animation_loop("default", looping)
			
			if show_first_frame_by_default:
				animated_sprite.visible = true
				animated_sprite.frame = 0
			elif hide_when_inactive:
				animated_sprite.visible = false
			
			if debug_mode:
				print("[MinorAnimSystem] AnimatedSprite setup: FPS=", fps, " Looping=", looping, " Visible=", animated_sprite.visible)
			
			animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Find Trigger Area (must be added as a child in the scene)
	for child in get_children():
		if child is Area2D:
			trigger_area = child
			break
	
	if trigger_area:
		trigger_area.body_entered.connect(_on_body_entered)
		trigger_area.body_exited.connect(_on_body_exited)
		if debug_mode:
			print("[MinorAnimSystem] Trigger area found and connected")
	else:
		push_warning("MinorAnimSystem: No Area2D child found! Add an Area2D node as a child to define the trigger zone.")

func _process(_delta: float) -> void:
	if debug_mode and animated_sprite and is_playing:
		var current_frame = animated_sprite.frame
		if current_frame != last_frame:
			var total_frames = animated_sprite.sprite_frames.get_frame_count("default")
			print("[MinorAnimSystem] Frame: ", current_frame, "/", total_frames - 1, 
				  " | Playing: ", animated_sprite.is_playing(), 
				  " | Visible: ", animated_sprite.visible)
			last_frame = current_frame

func _on_body_entered(body: Node2D) -> void:
	if debug_mode:
		print("[MinorAnimSystem] body_entered: ", body.name, " | is_player: ", body.is_in_group("player"), " | has_played: ", has_played)
	
	if body.is_in_group("player") and !has_played:
		if animated_sprite:
			animated_sprite.visible = true
			animated_sprite.play("default")
			is_playing = true
			last_frame = -1
			if !repeatable:
				has_played = true
			
			if debug_mode:
				print("[MinorAnimSystem] ▶ ANIMATION STARTED | Visible: ", animated_sprite.visible, 
					  " | is_playing: ", animated_sprite.is_playing(), 
					  " | Total frames: ", animated_sprite.sprite_frames.get_frame_count("default"))

func _on_body_exited(body: Node2D) -> void:
	if debug_mode:
		print("[MinorAnimSystem] body_exited: ", body.name, " | is_player: ", body.is_in_group("player"), " | is_playing: ", is_playing)
	
	if body.is_in_group("player"):
		# If animation is currently playing, let it finish - don't interrupt it
		if is_playing:
			if debug_mode:
				print("[MinorAnimSystem] 🎬 Animation is playing - letting it finish (ignoring body_exited)")
			return
		
		# Only handle exit logic if animation is not playing
		if animated_sprite:
			if debug_mode:
				print("[MinorAnimSystem] ⏸ Player exited while not playing")
			
			if !repeatable and has_played:
				# HIDE COMPLETELY AND PERMANENTLY
				if debug_mode:
					print("[MinorAnimSystem] 🚫 HIDING PERMANENTLY (non-repeatable, already played)")
				animated_sprite.visible = false
				_disable_system()
			else:
				if show_first_frame_by_default:
					animated_sprite.frame = 0
					animated_sprite.visible = true
					if debug_mode:
						print("[MinorAnimSystem] Reset to first frame, visible")
				elif hide_when_inactive:
					animated_sprite.visible = false
					if debug_mode:
						print("[MinorAnimSystem] Hidden (inactive)")

func _on_animation_finished() -> void:
	if debug_mode:
		print("[MinorAnimSystem] ✓ ANIMATION FINISHED | repeatable: ", repeatable, 
			  " | Current frame: ", animated_sprite.frame,
			  " | Total frames: ", animated_sprite.sprite_frames.get_frame_count("default"))
	
	is_playing = false
	
	if !repeatable:
		if debug_mode:
			print("[MinorAnimSystem] 🚫 Hiding and disabling (non-repeatable)")
		animated_sprite.visible = false
		animated_sprite.stop()
		_disable_system()

func _disable_system() -> void:
	if debug_mode:
		print("[MinorAnimSystem] ⛔ DISABLING SYSTEM - Disconnecting all signals")
	
	if trigger_area:
		trigger_area.set_deferred("monitoring", false)
		trigger_area.set_deferred("monitorable", false)
	# Disconnect to prevent any further logic
	if trigger_area and trigger_area.body_entered.is_connected(_on_body_entered):
		trigger_area.body_entered.disconnect(_on_body_entered)
	if trigger_area and trigger_area.body_exited.is_connected(_on_body_exited):
		trigger_area.body_exited.disconnect(_on_body_exited)
