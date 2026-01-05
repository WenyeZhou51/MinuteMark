extends Node2D

## Handles the paper tear effect. Positioned BEHIND the player.

@export var noise_texture: FastNoiseLite
@export var scrap_script = preload("res://paper_scrap.gd")

var mask_viewport: SubViewport
var screen_shader_rect: ColorRect
var stored_screenshot: Texture2D
var active_line: Line2D

func _ready() -> void:
	print("[PAPER-SYSTEM] Initializing...")
	var screen_size = get_viewport().get_visible_rect().size
	
	# Ensure this node stays at a low Z-index to be behind the player
	z_index = -10
	
	# 1. Setup Mask Viewport
	mask_viewport = SubViewport.new()
	mask_viewport.size = screen_size
	mask_viewport.transparent_bg = true
	mask_viewport.disable_3d = true
	mask_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(mask_viewport)
	
	# 2. Setup Post-Process Shader
	# We use a simple Sprite2D that covers the screen instead of a CanvasLayer
	# This keeps it in the world-space rendering order
	screen_shader_rect = ColorRect.new()
	screen_shader_rect.size = screen_size
	screen_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var tear_mat = ShaderMaterial.new()
	tear_mat.shader = load("res://shaders/paper_tear.gdshader")
	tear_mat.set_shader_parameter("mask_texture", mask_viewport.get_texture())
	
	if not noise_texture:
		noise_texture = FastNoiseLite.new()
		noise_texture.frequency = 0.05
	
	var noise_tex = NoiseTexture2D.new()
	noise_tex.noise = noise_texture
	tear_mat.set_shader_parameter("noise_texture", noise_tex)
	
	screen_shader_rect.material = tear_mat
	add_child(screen_shader_rect)

func _process(_delta: float) -> void:
	# Keep the shader rect centered on the camera/view
	var canvas_transform = get_viewport().get_canvas_transform().affine_inverse()
	screen_shader_rect.global_position = canvas_transform.origin

func capture_screen():
	await RenderingServer.frame_post_draw
	var viewport = get_viewport()
	if not viewport: return
	var img = viewport.get_texture().get_image()
	if img:
		stored_screenshot = ImageTexture.create_from_image(img)

func start_tear():
	active_line = Line2D.new()
	active_line.width = 75.0 # Wider for better visibility
	active_line.default_color = Color.WHITE
	active_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	active_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	active_line.joint_mode = Line2D.LINE_JOINT_ROUND
	mask_viewport.add_child(active_line)

func add_tear_point(global_pos: Vector2):
	if not active_line: return
	# Add subtle jitter to the path itself for extra jaggedness
	var jitter = Vector2(randf_range(-2, 2), randf_range(-2, 2))
	var screen_pos = (get_viewport().get_canvas_transform() * global_pos) + jitter
	active_line.add_point(screen_pos)

func end_tear(fade_duration: float = 1.5):
	if not active_line: return
	var line_to_fade = active_line
	active_line = null
	var tween = create_tween()
	tween.tween_property(line_to_fade, "width", 0.0, fade_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(line_to_fade.queue_free)

func spawn_scrap(global_pos: Vector2, direction: float):
	var scrap = RigidBody2D.new()
	scrap.set_script(scrap_script)
	scrap.global_position = global_pos
	scrap.z_index = 5 # Scraps should fly IN FRONT of the player
	
	get_tree().root.add_child(scrap)
	
	if stored_screenshot and scrap.has_method("set_texture_from_capture"):
		scrap.set_texture_from_capture(stored_screenshot, global_pos)
	
	# Flunge them out and rotating
	scrap.apply_impulse(Vector2(-direction * randf_range(200, 400), randf_range(-150, -300)))
	scrap.apply_torque_impulse(randf_range(-500, 500))
