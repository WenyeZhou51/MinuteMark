extends CPUParticles2D

func _ready() -> void:
	emitting = true
	z_index = 5 # Ensure particles are visible above most world elements
	# Auto-destroy after lifetime expires
	var timer = get_tree().create_timer(lifetime + 0.1)
	timer.timeout.connect(queue_free)

func _process(delta: float) -> void:
	# Simple fade out effect
	modulate.a = move_toward(modulate.a, 0.0, delta / lifetime)

func setup(mode: String, direction_vec: Vector2 = Vector2.ZERO) -> void:
	match mode:
		"jump":
			amount = 16
			lifetime = 0.6
			explosiveness = 0.9
			direction = Vector2(0, -1)
			spread = 60.0
			initial_velocity_min = 40.0
			initial_velocity_max = 100.0
			scale_amount_min = 6.0
			scale_amount_max = 12.0
		"wall_jump":
			amount = 14
			lifetime = 0.5
			explosiveness = 0.9
			direction = direction_vec # Should be wall normal
			spread = 45.0
			initial_velocity_min = 60.0
			initial_velocity_max = 120.0
			scale_amount_min = 6.0
			scale_amount_max = 12.0
		"run":
			amount = 6
			lifetime = 0.4
			explosiveness = 0.5
			direction = direction_vec + Vector2(0, -0.5) # Puff back and slightly up
			spread = 30.0
			initial_velocity_min = 20.0
			initial_velocity_max = 50.0
			scale_amount_min = 4.0
			scale_amount_max = 8.0
		"slide":
			amount = 8
			lifetime = 0.5
			explosiveness = 0.3
			direction = Vector2(0, -1)
			spread = 180.0
			initial_velocity_min = 10.0
			initial_velocity_max = 40.0
			scale_amount_min = 4.0
			scale_amount_max = 10.0
		"slide_jump":
			amount = 25
			lifetime = 0.8
			explosiveness = 0.95
			direction = Vector2(0, -1)
			spread = 120.0
			initial_velocity_min = 100.0
			initial_velocity_max = 200.0
			scale_amount_min = 10.0
			scale_amount_max = 20.0

