extends Node
class_name Juicy_player

signal juice_play()

@export var autoplay : bool

func _ready():
	if autoplay:
		Play()

func Play():
	juice_play.emit()
	for child in get_children():
		if child is Juicy_effect:
			var juicy : Juicy_effect = child
			child.Play()
			if child.stopper :
				await child.on_stop
			

func Stop():
	for child in get_children():
		if child is Juicy_effect:
			var juicy : Juicy_effect = child
			child.Stop()

