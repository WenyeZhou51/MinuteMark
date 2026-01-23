extends Control

## UI component for displaying tutorial block instructions with spotlight effect

@export_range(0.0, 1.0, 0.05) var darkness: float = 0.5 ## How dark the scene becomes (0 = no darkening, 1 = completely black)
@export_range(0.0, 0.3, 0.01) var spotlight_radius: float = 0.08 ## Base spotlight radius (will be adjusted based on player size)
@export_range(0.0, 0.3, 0.01) var edge_softness: float = 0.08 ## How soft/feathered the spotlight edge is
@export var match_player_size: bool = true ## Automatically size spotlight to match player

@onready var label: Label = $Label
@onready var spotlight_overlay: ColorRect = $SpotlightOverlay

var fade_tween: Tween
var is_active: bool = false

func _ready() -> void:
	# Hide initially
	modulate.a = 0.0
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Hide spotlight initially
	if spotlight_overlay:
		spotlight_overlay.visible = false
		spotlight_overlay.modulate.a = 0.0

func _process(_delta: float) -> void:
	# Update spotlight position to follow player when active
	if is_active and spotlight_overlay and spotlight_overlay.visible:
		_update_spotlight_position()

func show_message(message: String) -> void:
	label.text = message
	is_active = true
	_fade_in()

func hide_message() -> void:
	is_active = false
	_fade_out()

func _update_spotlight_position() -> void:
	"""Update the spotlight shader to follow the player."""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Get player position in screen space
	var viewport = get_viewport()
	if not viewport:
		return
	
	var camera = viewport.get_camera_2d()
	if not camera:
		return
	
	# Convert player world position to screen coordinates
	var player_screen_pos = player.global_position
	var camera_pos = camera.global_position
	var viewport_size = get_viewport_rect().size
	
	# Calculate relative position (normalized 0-1)
	var relative_pos = (player_screen_pos - camera_pos) / viewport_size
	relative_pos += Vector2(0.5, 0.5) # Center it
	
	# Calculate spotlight radius based on player size if enabled
	var final_radius = spotlight_radius
	if match_player_size and player is Node2D:
		# Try to get player's sprite or collision shape size
		var player_size = _get_player_visual_size(player)
		if player_size > 0:
			# Convert world space size to normalized screen space
			# Use the larger dimension (width or height)
			final_radius = (player_size / viewport_size.y) * 0.5 # Adjust multiplier as needed
	
	# Update shader parameters
	var material = spotlight_overlay.material as ShaderMaterial
	if material:
		material.set_shader_parameter("spotlight_position", relative_pos)
		material.set_shader_parameter("spotlight_radius", final_radius)
		material.set_shader_parameter("edge_softness", edge_softness)
		material.set_shader_parameter("darkness", darkness)

func _get_player_visual_size(player: Node2D) -> float:
	"""Try to determine the visual size of the player."""
	# Try to find a Sprite2D or AnimatedSprite2D
	for child in player.get_children():
		if child is Sprite2D:
			var sprite = child as Sprite2D
			if sprite.texture:
				var texture_size = sprite.texture.get_size()
				var scaled_size = texture_size * sprite.scale
				return max(scaled_size.x, scaled_size.y)
		elif child is AnimatedSprite2D:
			var anim_sprite = child as AnimatedSprite2D
			if anim_sprite.sprite_frames:
				var frame_texture = anim_sprite.sprite_frames.get_frame_texture(anim_sprite.animation, anim_sprite.frame)
				if frame_texture:
					var texture_size = frame_texture.get_size()
					var scaled_size = texture_size * anim_sprite.scale
					return max(scaled_size.x, scaled_size.y)
	
	# Fallback: try to get collision shape size
	for child in player.get_children():
		if child is CollisionShape2D:
			var collision = child as CollisionShape2D
			if collision.shape is RectangleShape2D:
				var rect = collision.shape as RectangleShape2D
				return max(rect.size.x, rect.size.y)
			elif collision.shape is CapsuleShape2D:
				var capsule = collision.shape as CapsuleShape2D
				return max(capsule.radius * 2, capsule.height)
	
	# Default fallback size
	return 64.0

func _fade_in() -> void:
	visible = true
	if fade_tween:
		fade_tween.kill()
	
	# Show spotlight overlay
	if spotlight_overlay:
		spotlight_overlay.visible = true
	
	fade_tween = create_tween()
	fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # Allow tweening while paused
	fade_tween.set_parallel(true) # Fade both elements at the same time
	fade_tween.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if spotlight_overlay:
		fade_tween.tween_property(spotlight_overlay, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _fade_out() -> void:
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # Allow tweening while paused
	fade_tween.set_parallel(true) # Fade both elements at the same time
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if spotlight_overlay:
		fade_tween.tween_property(spotlight_overlay, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade_tween.finished.connect(func(): 
		visible = false
		if spotlight_overlay:
			spotlight_overlay.visible = false
	)
