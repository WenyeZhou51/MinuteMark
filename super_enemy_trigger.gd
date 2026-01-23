extends Area2D

@export var super_enemy: Node2D

var has_triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	print("[SuperEnemyTrigger] Ready at position: ", global_position)
	if super_enemy:
		print("[SuperEnemyTrigger] Super enemy assigned: ", super_enemy.name, " at position: ", super_enemy.global_position)
	else:
		push_error("[SuperEnemyTrigger] ERROR: No super enemy assigned!")

func _on_body_entered(body: Node2D) -> void:
	print("[SuperEnemyTrigger] Body entered: ", body.name)
	
	if has_triggered:
		print("[SuperEnemyTrigger] Already triggered, ignoring")
		return
		
	if body.is_in_group("player") or body.name == "Player":
		has_triggered = true
		print("[SuperEnemyTrigger] PLAYER DETECTED! Triggering super enemy sequence")
		
		# Get timing values from super_enemy
		var pause_duration = super_enemy.player_pause_duration if super_enemy else 0.5
		var grunt_delay = super_enemy.grunt_delay if super_enemy else 0.5
		var fire_delay = super_enemy.fire_delay if super_enemy else 1.0
		
		# Immediately set speed cap (pause player)
		if body.has_method("set_speed_cap"):
			body.set_speed_cap(true)
			print("[SuperEnemyTrigger] Player paused (speed cap ENABLED)")
		else:
			push_error("[SuperEnemyTrigger] ERROR: Player doesn't have set_speed_cap method!")
		
		# Unpause player after pause_duration
		get_tree().create_timer(pause_duration).timeout.connect(func():
			if body and body.has_method("set_speed_cap"):
				body.set_speed_cap(false)
				print("[SuperEnemyTrigger] Player unpaused after ", pause_duration, " seconds")
		)
		
		# Show grunt at grunt_delay
		if super_enemy and super_enemy.has_method("show_grunt"):
			print("[SuperEnemyTrigger] Scheduling grunt at ", grunt_delay, " seconds")
			get_tree().create_timer(grunt_delay).timeout.connect(super_enemy.show_grunt)
		else:
			push_error("[SuperEnemyTrigger] ERROR: Super enemy doesn't have show_grunt method!")
		
		# Fire rockets at fire_delay
		if super_enemy and super_enemy.has_method("fire_rockets"):
			print("[SuperEnemyTrigger] Scheduling rocket fire at ", fire_delay, " seconds")
			get_tree().create_timer(fire_delay).timeout.connect(super_enemy.fire_rockets)
		else:
			push_error("[SuperEnemyTrigger] ERROR: Super enemy doesn't have fire_rockets method!") 


