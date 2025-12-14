extends Node
class_name GifLoader

## Helper class to load GIF animations into Godot
## Note: This requires the GIF to be split into individual frames
## or uses a texture array approach

## Creates an AnimatedSprite2D from individual frame images
static func create_animated_sprite_from_frames(frame_folder: String, frame_prefix: String, frame_count: int, fps: float = 10.0) -> AnimatedSprite2D:
	var animated_sprite = AnimatedSprite2D.new()
	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("default")
	
	for i in range(frame_count):
		var frame_path = "%s/%s%d.png" % [frame_folder, frame_prefix, i]
		if ResourceLoader.exists(frame_path):
			var texture = load(frame_path)
			sprite_frames.add_frame("default", texture)
	
	sprite_frames.set_animation_speed("default", fps)
	animated_sprite.sprite_frames = sprite_frames
	
	return animated_sprite


## Creates a simple texture cycling animation for a Sprite2D
static func create_texture_animation(sprite: Sprite2D, textures: Array[Texture2D], duration: float) -> Tween:
	if textures.is_empty():
		return null
	
	var tween = sprite.create_tween()
	tween.set_loops()
	
	var time_per_frame = duration / textures.size()
	for i in range(textures.size()):
		tween.tween_callback(func(): sprite.texture = textures[i])
		tween.tween_interval(time_per_frame)
	
	return tween

