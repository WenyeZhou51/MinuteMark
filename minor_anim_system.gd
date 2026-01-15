extends Node2D
class_name MinorAnimSystem

## A minor animation system that plays an animation based on player proximity.
## Can easily control size, speed, and trigger distance.

@export_group("Animation Settings")
@export var frame_folder: String = "res://Sprites/minor_anim_test_frames"
@export var frame_prefix: String = "frame_"
@export var frame_count: int = 8
@export var fps: float = 10.0
@export var anim_scale: Vector2 = Vector2.ONE
@export var looping: bool = false # Default to false so it can finish
@export var show_first_frame_by_default: bool = false

@export_group("Trigger Settings")
@export var trigger_radius: float = 200.0
@export var hide_when_inactive: bool = true
@export var repeatable: bool = false # Default to false as requested

var animated_sprite: AnimatedSprite2D
var trigger_area: Area2D
var has_played: bool = false

func _ready() -> void:
	# Setup Animation
	if frame_folder != "" and frame_count > 0:
		animated_sprite = GifLoader.create_animated_sprite_from_frames(frame_folder, frame_prefix, frame_count, fps)
		if animated_sprite:
			add_child(animated_sprite)
			animated_sprite.scale = anim_scale
			
			if animated_sprite.sprite_frames:
				animated_sprite.sprite_frames.set_animation_loop("default", looping)
			
			if show_first_frame_by_default:
				animated_sprite.visible = true
				animated_sprite.frame = 0
			elif hide_when_inactive:
				animated_sprite.visible = false
			
			animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Setup Trigger Area
	trigger_area = Area2D.new()
	trigger_area.collision_layer = 0
	trigger_area.collision_mask = 1
	
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = trigger_radius
	collision.shape = circle
	trigger_area.add_child(collision)
	add_child(trigger_area)
	
	trigger_area.body_entered.connect(_on_body_entered)
	trigger_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and !has_played:
		if animated_sprite:
			animated_sprite.visible = true
			animated_sprite.play("default")
			if !repeatable:
				has_played = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if animated_sprite:
			animated_sprite.stop()
			if !repeatable and has_played:
				# HIDE COMPLETELY AND PERMANENTLY
				animated_sprite.visible = false
				_disable_system()
			else:
				if show_first_frame_by_default:
					animated_sprite.frame = 0
					animated_sprite.visible = true
				elif hide_when_inactive:
					animated_sprite.visible = false

func _on_animation_finished() -> void:
	if !repeatable:
		animated_sprite.visible = false
		animated_sprite.stop()
		_disable_system()

func _disable_system() -> void:
	if trigger_area:
		trigger_area.set_deferred("monitoring", false)
		trigger_area.set_deferred("monitorable", false)
	# Disconnect to prevent any further logic
	if trigger_area.body_entered.is_connected(_on_body_entered):
		trigger_area.body_entered.disconnect(_on_body_entered)
	if trigger_area.body_exited.is_connected(_on_body_exited):
		trigger_area.body_exited.disconnect(_on_body_exited)
