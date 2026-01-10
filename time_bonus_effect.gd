extends Label

func setup(start_screen_pos: Vector2, target_screen_pos: Vector2, callback: Callable):
	text = "+1"
	
	# Apply styling
	add_theme_color_override("font_color", Color.YELLOW)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 10)
	
	# Use a font if possible - we'll try to load the one from TimerUI
	var font = load("res://Fonts/Funkrocker.otf")
	if font:
		add_theme_font_override("font", font)
	add_theme_font_size_override("font_size", 80)
	
	# Initial state
	# We need to wait a frame to get the correct size for centering
	await get_tree().process_frame
	
	global_position = start_screen_pos - size / 2
	pivot_offset = size / 2
	scale = Vector2.ONE
	
	var tween = create_tween()
	
	# 1. Float up
	var float_dist = 100.0
	tween.tween_property(self, "global_position:y", global_position.y - float_dist, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 2. Brief pause/hang
	tween.tween_interval(0.1)
	
	# 3. Move to timer and shrink
	var move_tween = create_tween().set_parallel(true)
	# Target is the center of the timer. As we shrink to 0.1, the offset becomes negligible,
	# but we'll still try to center it.
	move_tween.tween_property(self, "global_position", target_screen_pos - (size * 0.1) / 2.0, 0.8)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	move_tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.8)
	move_tween.tween_property(self, "modulate:a", 0.0, 0.8)
	
	await move_tween.finished
	callback.call()
	queue_free()
