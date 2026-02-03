extends Control

@onready var bar_container = $BarContainer
@onready var bar_gradient = $BarContainer/BarGradient
@onready var top_fire = $BarContainer/TopFire
@onready var bottom_fire = $BarContainer/BottomFire
@onready var left_fire = $BarContainer/LeftFire
@onready var right_fire = $BarContainer/RightFire

var bar_width = 400.0  # Width in pixels
var bar_height = 40.0
var pulse_timer = 0.0

func _ready():
	setup_bar_gradient()
	setup_fire_effects()

func _process(delta):
	# Pulse effect every second
	pulse_timer += delta
	if pulse_timer >= 1.0:
		pulse_timer = 0.0
		pulse_red()

func setup_bar_gradient():
	# Create gradient texture for the bar
	# 0 and 100: green, 20 and 80: yellow, 40-60: red
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.0, 1.0, 0.0))    # Position 0: GREEN
	gradient.add_point(0.2, Color(1.0, 1.0, 0.0))    # Position 20: YELLOW
	gradient.add_point(0.4, Color(1.0, 0.0, 0.0))    # Position 40: RED
	gradient.add_point(0.6, Color(1.0, 0.0, 0.0))    # Position 60: RED
	gradient.add_point(0.8, Color(1.0, 1.0, 0.0))    # Position 80: YELLOW
	gradient.add_point(1.0, Color(0.0, 1.0, 0.0))    # Position 100: GREEN
	
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0, 0.5)
	gradient_texture.fill_to = Vector2(1, 0.5)
	
	bar_gradient.texture = gradient_texture
	bar_gradient.size = Vector2(bar_width, bar_height)

func setup_fire_effects():
	# Position fire effects around the bar
	top_fire.size = Vector2(bar_width, 12)
	top_fire.position = Vector2(0, -12)
	
	bottom_fire.size = Vector2(bar_width, 12)
	bottom_fire.position = Vector2(0, bar_height)
	
	left_fire.size = Vector2(12, bar_height)
	left_fire.position = Vector2(-12, 0)
	
	right_fire.size = Vector2(12, bar_height)
	right_fire.position = Vector2(bar_width, 0)

func pulse_red():
	# Create expanding red pulse effect on all sides
	var tween = create_tween()
	tween.set_parallel(true)
	
	for fire in [top_fire, bottom_fire, left_fire, right_fire]:
		if fire and fire.material:
			# Store original size
			var original_size = fire.size
			var is_horizontal = fire == top_fire or fire == bottom_fire
			
			# Pulse outward by increasing size
			if is_horizontal:
				# Top and bottom expand vertically
				var expand_amount = 8.0
				tween.tween_property(fire, "size:y", original_size.y + expand_amount, 0.15)
				tween.tween_property(fire, "size:y", original_size.y, 0.35).set_delay(0.15)
				
				if fire == top_fire:
					tween.tween_property(fire, "position:y", fire.position.y - expand_amount, 0.15)
					tween.tween_property(fire, "position:y", fire.position.y, 0.35).set_delay(0.15)
			else:
				# Left and right expand horizontally
				var expand_amount = 8.0
				tween.tween_property(fire, "size:x", original_size.x + expand_amount, 0.15)
				tween.tween_property(fire, "size:x", original_size.x, 0.35).set_delay(0.15)
				
				if fire == left_fire:
					tween.tween_property(fire, "position:x", fire.position.x - expand_amount, 0.15)
					tween.tween_property(fire, "position:x", fire.position.x, 0.35).set_delay(0.15)
			
			# Flash red
			tween.tween_property(fire.material, "shader_parameter/fire_alpha", 1.8, 0.15)
			tween.tween_property(fire.material, "shader_parameter/fire_alpha", 1.0, 0.35).set_delay(0.15)
			
			fire.material.set_shader_parameter("bottom_color", Color(1.0, 0.0, 0.0))
			fire.material.set_shader_parameter("middle_color", Color(1.0, 0.3, 0.0))
			fire.material.set_shader_parameter("top_color", Color(1.0, 0.6, 0.2))
	
	await tween.finished
	
	# Reset to default fire colors
	for fire in [top_fire, bottom_fire, left_fire, right_fire]:
		if fire and fire.material:
			fire.material.set_shader_parameter("bottom_color", Color(0.0, 0.7, 1.0))
			fire.material.set_shader_parameter("middle_color", Color(1.0, 0.5, 0.0))
			fire.material.set_shader_parameter("top_color", Color(1.0, 0.03, 0.001))
