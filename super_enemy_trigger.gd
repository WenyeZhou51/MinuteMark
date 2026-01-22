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
		
		# Immediately set speed cap
		if body.has_method("set_speed_cap"):
			body.set_speed_cap(true)
			print("[SuperEnemyTrigger] Speed cap ENABLED on player")
		else:
			push_error("[SuperEnemyTrigger] ERROR: Player doesn't have set_speed_cap method!")
		
		# Grunt at 0.2 seconds
		if super_enemy and super_enemy.has_method("show_grunt"):
			print("[SuperEnemyTrigger] Scheduling grunt at 0.2 seconds")
			get_tree().create_timer(0.2).timeout.connect(super_enemy.show_grunt)
		else:
			push_error("[SuperEnemyTrigger] ERROR: Super enemy doesn't have show_grunt method!")
		
		# Fire at 0.4 seconds
		if super_enemy and super_enemy.has_method("fire_rockets"):
			print("[SuperEnemyTrigger] Scheduling rocket fire at 0.4 seconds")
			get_tree().create_timer(0.4).timeout.connect(super_enemy.fire_rockets)
		else:
			push_error("[SuperEnemyTrigger] ERROR: Super enemy doesn't have fire_rockets method!") 


