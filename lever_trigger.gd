extends Area2D

@export var target_system_path: NodePath
@export var one_shot: bool = true
@export var debug_logs: bool = false

var player_in_range: bool = false
var has_triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if not player_in_range:
		return
	if one_shot and has_triggered:
		return
	if Input.is_action_just_pressed("melee_attack"):
		_activate()


func _activate() -> void:
	if one_shot and has_triggered:
		return
	
	var target = get_node_or_null(target_system_path)
	if target and target.has_method("start_motion"):
		target.start_motion()
		has_triggered = true
		if debug_logs:
			print("[LeverTrigger] Activated platform system.")
	else:
		if debug_logs:
			print("[LeverTrigger] No valid target at path: ", target_system_path)


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		player_in_range = true


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		player_in_range = false


func _is_player(body: Node2D) -> bool:
	return body and (body.is_in_group("player") or body.name == "Player")
