extends Area2D

@export_multiline var tutorial_message: String = "Tutorial Message"
@export var stay_duration: float = 1.0

var player_in_area: bool = false
var triggered: bool = false
var stay_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if triggered:
		return
		
	if player_in_area:
		stay_timer += delta
		if stay_timer >= stay_duration:
			_trigger_tutorial()

func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return
		
	if body.is_in_group("player"):
		player_in_area = true
		stay_timer = 0.0

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false
		stay_timer = 0.0
		if triggered:
			# If it was already triggered and showing, hide it when player leaves
			TutorialManager.clear_message()
			# Requirement: "colliding with the area further will not trigger the message again"
			# This means once they leave, it's done for this trigger.
			# But we might want to keep triggered = true to prevent re-triggering.

func _trigger_tutorial() -> void:
	triggered = true
	TutorialManager.display_message(tutorial_message)
