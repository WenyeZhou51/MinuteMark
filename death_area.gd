extends Area2D

func _ready():
	# Connect the body_entered signal to detect when player enters
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Check if the body is the player
	if body.name == "Player" or body.is_in_group("player"):
		# Call the die method on the player
		if body.has_method("die"):
			body.die()
