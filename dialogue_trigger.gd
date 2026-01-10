extends Area2D

var triggered := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return
	
	if body.is_in_group("player"):
		triggered = true
		# Wait a small delay to let the player fully land/settle
		get_tree().create_timer(0.1).timeout.connect(func(): DialogueManager.start("intro"))

