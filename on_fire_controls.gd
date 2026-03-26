extends Node2D

@onready var player: CharacterBody2D = $Player


func _ready() -> void:
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			if player:
				if player.is_on_fire:
					player.extinguish_fire()
				else:
					player.set_on_fire()
