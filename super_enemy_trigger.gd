extends Area2D

@export var super_enemy: Node2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		if super_enemy and super_enemy.has_method("fire_at_target"):
			super_enemy.fire_at_target()
			# Disable trigger after use if needed, or keep it for multiple shots
			# queue_free() 


