extends Node2D

var tear_points = [] # Array of {pos: Vector2, time: float}
var fade_time = 3.0
var mask_image: Image
var mask_texture: ImageTexture
var noise_tex: NoiseTexture2D
var tear_material: ShaderMaterial

@onready var screen_size = get_viewport_rect().size

func _ready():
	z_index = 100
	# Initialize mask at lower resolution for performance
	mask_image = Image.create(int(screen_size.x / 4), int(screen_size.y / 4), false, Image.FORMAT_R8)
	mask_texture = ImageTexture.create_from_image(mask_image)
	
	# Setup noise
	noise_tex = NoiseTexture2D.new()
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	var noise = FastNoiseLite.new()
	noise.frequency = 0.05
	noise_tex.noise = noise
	await noise_tex.changed # Ensure noise is generated
	
	# Setup material
	tear_material = ShaderMaterial.new()
	tear_material.shader = preload("res://shaders/paper_tear.gdshader")
	tear_material.set_shader_parameter("mask_texture", mask_texture)
	tear_material.set_shader_parameter("noise_texture", noise_tex)

func add_point(global_pos: Vector2):
	tear_points.append({"pos": global_pos, "time": Time.get_ticks_msec() / 1000.0})

func _process(_delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	var camera = get_viewport().get_camera_2d()
	if not camera: return
	
	mask_image.fill(Color(0, 0, 0, 0))
	
	var i = tear_points.size() - 1
	while i >= 0:
		var p = tear_points[i]
		var age = current_time - p.time
		if age > fade_time:
			tear_points.remove_at(i)
		else:
			var camera_center = camera.get_screen_center_position()
			# Convert world to screen space, then to our 1/4 size mask space
			var local_pos = p.pos - camera_center + screen_size/2
			var mask_pos = local_pos / 4.0
			var opacity = 1.0 - (age / fade_time)
			_draw_soft_circle(mask_pos, 8.0, opacity)
		i -= 1
	
	mask_texture.update(mask_image)
	queue_redraw()

func _draw_soft_circle(pos: Vector2, radius: float, opacity: float):
	var start_x = int(max(0, pos.x - radius))
	var end_x = int(min(mask_image.get_width(), pos.x + radius))
	var start_y = int(max(0, pos.y - radius))
	var end_y = int(min(mask_image.get_height(), pos.y + radius))
	
	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			var d = pos.distance_to(Vector2(x, y))
			if d < radius:
				var current = mask_image.get_pixel(x, y).r
				var val = max(current, (1.0 - d/radius) * opacity)
				mask_image.set_pixel(x, y, Color(val, 0, 0, 1))

func _draw():
	var camera = get_viewport().get_camera_2d()
	if not camera: return
	
	var camera_center = camera.get_screen_center_position()
	var rect = Rect2(camera_center - screen_size/2, screen_size)
	
	draw_rect(rect, Color.WHITE)
	# Apply the material to the drawing
	# Note: In Godot _draw, we use draw_rect but the CanvasItem's material property handles the shader
	if material != tear_material:
		material = tear_material

