extends Node2D

func _ready() -> void:
	# Listen for when dialogue starts/finishes to pause/resume
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	
	# Initial state: Game is NOT paused.
	get_tree().paused = false

func _on_dialogue_started(_id: String) -> void:
	get_tree().paused = true

func _on_dialogue_finished() -> void:
	get_tree().paused = false
