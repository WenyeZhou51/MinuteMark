extends CPUParticles2D

func _ready() -> void:
	# Configure particles for a "shattering" look
	emitting = true
	one_shot = true
	explosiveness = 1.0
	amount = 12
	lifetime = 0.6
	spread = 180.0
	gravity = Vector2(0, 800)
	initial_velocity_min = 100.0
	initial_velocity_max = 250.0
	scale_amount_min = 2.0
	scale_amount_max = 4.0
	color = Color(0.8, 0.8, 0.8, 1.0) # Light gray by default
	
	# Connect the finished signal to queue_free (Godot 4.x)
	finished.connect(queue_free)




