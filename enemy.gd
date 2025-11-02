extends Area2D

signal enemy_touched_by_player
signal enemy_destroyed

var is_destroyed: bool = false

func _ready() -> void:
	# Connect the area entered signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Check if the body is the player (more robust detection)
	if body.has_method("_on_enemy_touched") and not is_destroyed:
		# Emit signal that player touched enemy
		enemy_touched_by_player.emit()
		print("Enemy touched by player!")

func destroy() -> void:
	"""Destroy the enemy (called when player attacks through it)"""
	if not is_destroyed:
		is_destroyed = true
		enemy_destroyed.emit()
		# Hide the enemy
		visible = false
		# Disable collision
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		print("Enemy destroyed!")
