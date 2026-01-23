extends Node2D

# Afterimage that can display either a sprite or a polygon, and fades out over time

@export var lifetime: float = 0.4  ## Total time before the afterimage disappears
@export var initial_alpha: float = 0.7  ## Starting opacity

var elapsed_time: float = 0.0

# Using direct access or get_node to ensure we can setup right after instantiation
@onready var sprite: Sprite2D = $Sprite2D
@onready var polygon: Polygon2D = $Polygon2D

func _ready() -> void:
	# Set initial alpha
	modulate.a = initial_alpha
	# Ensure it's drawn behind the player but above background
	z_index = -1

func setup_from_sprite(source_sprite: AnimatedSprite2D, custom_modulate: Color = Color.WHITE) -> void:
	# If @onready hasn't run, fetch manually
	var s = sprite if sprite else get_node_or_null("Sprite2D")
	var p = polygon if polygon else get_node_or_null("Polygon2D")
	
	if not s: return
	
	# Get the current frame as a texture
	var frames = source_sprite.sprite_frames
	var anim = source_sprite.animation
	var frame_idx = source_sprite.frame
	var texture = frames.get_frame_texture(anim, frame_idx)
	
	s.texture = texture
	s.flip_h = source_sprite.flip_h
	s.scale = source_sprite.scale
	s.centered = source_sprite.centered
	s.offset = source_sprite.offset
	s.modulate = custom_modulate
	s.visible = true
	
	if p:
		p.visible = false

func _process(delta: float) -> void:
	elapsed_time += delta
	
	# Calculate fade progress (0.0 to 1.0)	
	var fade_progress = elapsed_time / lifetime
	
	if fade_progress >= 1.0:
		# Lifetime expired, delete the afterimage
		queue_free()
		return
	
	# Apply fade out to alpha
	modulate.a = initial_alpha * (1.0 - fade_progress)
