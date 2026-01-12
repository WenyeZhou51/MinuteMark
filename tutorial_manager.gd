extends Node

var tutorial_ui_scene = preload("res://TutorialUI.tscn")
var tutorial_ui_instance: Control

func _ready() -> void:
	# Create a CanvasLayer to hold the tutorial UI
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100 # High layer to be on top
	add_child(canvas_layer)
	
	tutorial_ui_instance = tutorial_ui_scene.instantiate()
	canvas_layer.add_child(tutorial_ui_instance)

func display_message(message: String) -> void:
	if tutorial_ui_instance:
		tutorial_ui_instance.show_message(message)

func clear_message() -> void:
	if tutorial_ui_instance:
		tutorial_ui_instance.hide_message()

