extends Node2D

## Handles the paper tear effect.
## Logic: Renders Line2D DIRECTLY in world space.
## This prevents camera-sync issues because world nodes stay fixed relative to walls.

@export var tear_image: Texture2D = preload("res://Sprites/slide.png")
@export var tear_offset: Vector2 = Vector2.ZERO
@export var tear_width: float = 150.0
@export var tear_v_squish: float = 0.4

var active_line: Line2D
var particles: CPUParticles2D
var stored_screenshot: Image

func _ready() -> void:
	# Keep the manager at the world origin so its children's positions are world coordinates.
	global_position = Vector2.ZERO
	z_index = 200 # Above background and foreground
	
	# Setup Particles
	particles = CPUParticles2D.new()
	particles.emitting = false
	particles.amount = 100
	particles.lifetime = 1.0
	particles.spread = 60.0
	particles.gravity = Vector2(0, 800)
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 400.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 10.0
	particles.z_index = 210
	add_child(particles)

func capture_screen():
	# Ensure we capture a safe frame
	await RenderingServer.frame_post_draw
	var vp = get_viewport()
	if vp:
		stored_screenshot = vp.get_texture().get_image()

func start_tear(direction: float = 1.0, width: float = 150.0, squish: float = 0.4):
	# LOGGING: Verify start
	capture_screen()
	
	active_line = Line2D.new()
	active_line.width = width
	active_line.texture = tear_image
	active_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	
	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/paper_tear_direct.gdshader")
	mat.set_shader_parameter("main_texture", tear_image)
	mat.set_shader_parameter("texture_width_px", tear_image.get_width() if tear_image else 256.0)
	mat.set_shader_parameter("is_finished", false)
	mat.set_shader_parameter("v_squish", squish)
	active_line.material = mat
	
	add_child(active_line)
	
	particles.direction = Vector2(-direction, -0.5).normalized()
	particles.emitting = true

func add_tear_point(global_pos: Vector2, offset: Vector2 = Vector2.ZERO):
	if not active_line: return
	
	# Apply inspector offset
	var final_pos = global_pos + offset
	active_line.add_point(final_pos)
	
	particles.global_position = final_pos
	
	if stored_screenshot:
		var screen_pos = get_viewport().get_canvas_transform() * final_pos
		if Rect2(Vector2.ZERO, stored_screenshot.get_size()).has_point(screen_pos):
			particles.color = stored_screenshot.get_pixelv(Vector2i(screen_pos))
			
	if active_line.material:
		var length = 0.0
		for i in range(active_line.points.size() - 1):
			length += active_line.points[i].distance_to(active_line.points[i+1])
		active_line.material.set_shader_parameter("line_length_px", max(length, 1.0))

func end_tear(_fade_duration: float = 0.0):
	if active_line:
		var line_to_fade = active_line
		if line_to_fade.material:
			line_to_fade.material.set_shader_parameter("is_finished", true)
		
		# Stay visible for a moment, then fade out over 0.5 seconds
		var tween = create_tween()
		tween.tween_interval(0.5) # Stay duration
		tween.tween_property(line_to_fade, "modulate:a", 0.0, 0.5)
		tween.tween_callback(line_to_fade.queue_free)
	
	particles.emitting = false
	active_line = null
