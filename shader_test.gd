extends Control

@onready var texture_rect: TextureRect = $CanvasLayer/TextureRect
var is_revealing: bool = false

func _ready() -> void:
	
	if not texture_rect:
		return
		
	# REDUNDANT PROTECTION 1: Visibility
	texture_rect.visible = false
	
	# Check Material
	var mat = texture_rect.material as ShaderMaterial
	if not mat:
		# Try to force load if missing
		var shader_res = load("res://shaders/paint_splatter_reveal.gdshader")
		if shader_res:
			mat = ShaderMaterial.new()
			mat.shader = shader_res
			texture_rect.material = mat
	
	if mat:
		mat.set_shader_parameter("reveal_progress", 0.0)
		mat.set_shader_parameter("edge_roughness", 0.4)
		mat.set_shader_parameter("detail_scale", 10.0)
		mat.set_shader_parameter("edge_softness", 0.02)
		
		if texture_rect.texture:
			var size = texture_rect.texture.get_size()
			var aspect = size.x / size.y
			mat.set_shader_parameter("aspect_ratio", aspect)
		else:
			pass
	

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_revealing:
			start_reveal()
		else:
			pass

func start_reveal() -> void:
	is_revealing = true
	
	# Only make visible when animation starts
	texture_rect.visible = true
	
	var mat = texture_rect.material as ShaderMaterial
	if mat:
		var current_val = mat.get_shader_parameter("reveal_progress")
		
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		
		# Explicitly tween the shader parameter
		tween.tween_method(
			func(v): 
				mat.set_shader_parameter("reveal_progress", v)
				# Only log every 10% to avoid spam but track movement
				if fmod(v * 100.0, 10.0) < 1.0:
					pass
			,
			0.0, 
			1.0, 
			4.0 # Slower animation (4 seconds) to better see the sprawl
		)
		
		tween.finished.connect(func(): pass)
	else:
		pass
