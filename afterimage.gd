extends Node2D

# Afterimage that can display either a sprite or a polygon, and fades out over time

@export_group("Afterimage Fade Settings")
@export var lifetime: float = 0.4  ## Total time before the afterimage disappears (seconds)
@export var initial_alpha: float = 0.7  ## Starting opacity (0.0 = invisible, 1.0 = fully opaque)

var elapsed_time: float = 0.0

# Using direct access or get_node to ensure we can setup right after instantiation
@onready var sprite: Sprite2D = $Sprite2D
@onready var polygon: Polygon2D = $Polygon2D

# Keep reference to sprite for fading
var active_sprite: Sprite2D = null

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
	
	# Create a silhouette shader that replaces all opaque pixels with a solid color
	var shader_code = """
shader_type canvas_item;
render_mode blend_mix;

uniform vec4 silhouette_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Replace all non-transparent pixels with the silhouette color
	// Apply fade_alpha uniform to control opacity over time
	COLOR = vec4(silhouette_color.rgb, tex.a * silhouette_color.a * fade_alpha);
}
"""
	
	var shader = Shader.new()
	shader.code = shader_code
	
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("silhouette_color", custom_modulate)
	shader_material.set_shader_parameter("fade_alpha", 1.0)  # Start at full opacity
	
	s.material = shader_material
	
	# Store reference for fading
	active_sprite = s
	
	# DEBUG: Verify shader setup
	print("[Afterimage] Created silhouette - Color: RGB(%.2f, %.2f, %.2f) Alpha: %.2f" % [custom_modulate.r, custom_modulate.g, custom_modulate.b, custom_modulate.a])
	s.visible = true
	
	if p:
		p.visible = false

func _process(delta: float) -> void:
	elapsed_time += delta
	
	# Calculate fade progress (0.0 to 1.0)	
	var fade_progress = elapsed_time / lifetime
	
	# Calculate alpha for this frame
	var current_alpha = initial_alpha * (1.0 - fade_progress)
	
	# DEBUG: Print fade state periodically (every ~0.1 seconds)
	if int(elapsed_time * 10) % 3 == 0:
		print("[Afterimage] Fading - Progress: %.2f%%, fade_alpha: %.3f" % [fade_progress * 100, current_alpha])
	
	if fade_progress >= 1.0:
		# Lifetime expired, delete the afterimage
		print("[Afterimage] Destroyed - Total lifetime: %.2f seconds" % elapsed_time)
		queue_free()
		return
	
	# Update the shader uniform directly to control fade
	if active_sprite and active_sprite.material:
		active_sprite.material.set_shader_parameter("fade_alpha", current_alpha)
