extends Area2D

signal level_finished(time_taken)

func _ready():
	# Hide the debug visuals in game
	if has_node("ColorRect"):
		$ColorRect.visible = false
	# Ensure the area is set up to detect the player
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		var time_taken = 0.0
		if "game_timer_duration" in body and "current_game_time" in body:
			time_taken = body.game_timer_duration - body.current_game_time
		
		level_finished.emit(time_taken)
		
		# Call method on player to handle level completion
		if body.has_method("finish_level"):
			body.finish_level(time_taken)

