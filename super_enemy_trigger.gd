extends Area2D

@export var super_enemy: Node2D

var has_triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if super_enemy:
		if super_enemy.has_signal("rocket_created"):
			super_enemy.rocket_created.connect(_on_rocket_created)
	else:
		push_error("[SuperEnemyTrigger] ERROR: No super enemy assigned!")

func _on_body_entered(body: Node2D) -> void:
	if has_triggered: return
	
	if body.is_in_group("player") or body.name == "Player":
		has_triggered = true
		
		# Set speed cap immediately
		if body.has_method("set_speed_cap"):
			body.set_speed_cap(true)
		
		# 1. Camera Zoom Out to see full view
		var midpoint = (body.global_position + super_enemy.global_position) / 2
		
		# Calculate dynamic zoom to fit both characters
		var view_size = get_viewport_rect().size
		var dist_vec = (body.global_position - super_enemy.global_position).abs()
		var margin = Vector2(400, 300) # Margin around the characters
		var required_size = dist_vec + margin
		
		# Calculate zoom factor (Viewport / RequiredSize)
		# NOTE: zoom > 1 is zoomed in (smaller view), zoom < 1 is zoomed out (larger view) in Godot 4 logic for Camera2D.zoom
		# Wait, actually Camera2D.zoom (2,2) means 2x magnification (objects look 2x bigger, so visible area is 1/2).
		# So VisibleArea = ViewportSize / Zoom.
		# We need VisibleArea >= RequiredSize.
		# ViewportSize / Zoom >= RequiredSize
		# Zoom <= ViewportSize / RequiredSize
		
		var max_zoom_x = view_size.x / required_size.x
		var max_zoom_y = view_size.y / required_size.y
		var safe_zoom = min(max_zoom_x, max_zoom_y)
		
		# Clamp zoom to reasonable values
		safe_zoom = clamp(safe_zoom, 0.4, 1.2)
		var target_zoom = Vector2(safe_zoom, safe_zoom)
		
		if body.has_method("start_camera_override"):
			# Move camera over 2.0 seconds (normal time) for a slower, more cinematic feel
			body.start_camera_override(midpoint, target_zoom, 2.0)
		
		# 2. Wait for camera to settle, THEN Slow Motion
		# Using a timer that ignores time scale (though time scale is 1.0 here anyway)
		get_tree().create_timer(2.0, true, false, true).timeout.connect(func():
			# Start Slow Motion
			Engine.time_scale = 0.2

			
			# 3. Super Enemy Speaks
			if super_enemy.has_method("speak"):
				# Speak duration 0.5s game time = 2.5s real time at 0.2 scale
				super_enemy.speak("I've been waiting...", 0.5)
			
			# 4. Fire Rocket after a delay
			# 1.5s real time delay = 0.3s game time wait? 
			# Or just use real time timer.
			get_tree().create_timer(1.5, true, false, true).timeout.connect(func():
				if super_enemy.has_method("stop_speaking"):
					super_enemy.stop_speaking()
				if super_enemy.has_method("fire_rockets"):
					super_enemy.fire_rockets()
			)
		)

func _on_rocket_created(rocket: Node2D) -> void:
	if rocket.has_signal("exploded"):
		rocket.exploded.connect(_on_rocket_exploded)

func _on_rocket_exploded() -> void:
	# Restore normal speed and camera after a short delay
	get_tree().create_timer(1.0, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
		var player = get_tree().get_first_node_in_group("player")
		if player:
			if player.has_method("stop_camera_override"):
				player.stop_camera_override(1.0)
			
			# Disable speed cap so player can dash freely
			if player.has_method("set_speed_cap"):
				player.set_speed_cap(false)
	)
