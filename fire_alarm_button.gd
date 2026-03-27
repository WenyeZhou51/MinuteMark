extends Area2D
## Kickable fire alarm button.
## When kicked, triggers the paired sprinkler sequence.

@export_group("Pairing")
@export var target_sprinkler_path: NodePath

@export_group("Behavior")
@export var one_shot: bool = false
@export var debug_logs: bool = false
@export var kick_range_override: float = 8.0

@export_group("Audio")
@export var button_sfx_path: String = "res://audio/button.wav"
@export var alarm_sfx_path: String = "res://audio/alarm.wav"
@export var alarm_start_delay: float = 0.08
@export var button_sfx_volume_db: float = 4.0
@export var alarm_sfx_volume_db: float = -3.0

var has_triggered: bool = false
var _pulse_time: float = 0.0
var _near_player: bool = false
var _press_feedback_id: int = 0
var _activation_audio_id: int = 0

@onready var button_face: Polygon2D = $ButtonVisual/ButtonFace
@onready var status_light: Polygon2D = $ButtonVisual/StatusLight

var _button_sfx_player: AudioStreamPlayer2D
var _alarm_sfx_player: AudioStreamPlayer2D


func _ready() -> void:
	add_to_group("kickable_objects")
	collision_layer = 32
	collision_mask = 2
	_setup_audio_players()
	_set_idle_visual()
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func _process(delta: float) -> void:
	if _near_player and (not one_shot or not has_triggered):
		_pulse_time += delta
		_update_pulse()
		queue_redraw()


func kick(_direction: Vector2, _speed: float = 0.0) -> void:
	"""Called by player kick system."""
	if one_shot and has_triggered:
		return
	
	has_triggered = true
	_play_press_feedback()
	_play_activation_audio_and_trigger()
	queue_redraw()


func can_be_kicked() -> bool:
	return not (one_shot and has_triggered)


func get_kick_range_override() -> float:
	"""Force very-close kick requirement for alarm buttons."""
	return maxf(1.0, kick_range_override)


func _trigger_paired_sprinkler() -> void:
	var target = get_node_or_null(target_sprinkler_path)
	if not target:
		if debug_logs:
			print("[FIRE ALARM] No sprinkler found at path: ", target_sprinkler_path)
		return
	
	if target.has_method("trigger_sprinkler"):
		target.trigger_sprinkler()
		if debug_logs:
			print("[FIRE ALARM] Triggered sprinkler: ", target.name)
	else:
		if debug_logs:
			print("[FIRE ALARM] Target has no trigger_sprinkler(): ", target.name)


func _setup_audio_players() -> void:
	_button_sfx_player = AudioStreamPlayer2D.new()
	_button_sfx_player.name = "ButtonSfxPlayer"
	_button_sfx_player.volume_db = button_sfx_volume_db
	add_child(_button_sfx_player)
	
	_alarm_sfx_player = AudioStreamPlayer2D.new()
	_alarm_sfx_player.name = "AlarmSfxPlayer"
	_alarm_sfx_player.volume_db = alarm_sfx_volume_db
	add_child(_alarm_sfx_player)
	
	var button_stream = load(button_sfx_path)
	if button_stream:
		_button_sfx_player.stream = button_stream
	
	var alarm_stream = load(alarm_sfx_path)
	if alarm_stream:
		_alarm_sfx_player.stream = alarm_stream


func _play_activation_audio_and_trigger() -> void:
	_activation_audio_id += 1
	var activation_id := _activation_audio_id
	
	if _button_sfx_player and _button_sfx_player.stream:
		_button_sfx_player.play()
	
	_trigger_paired_sprinkler()
	
	if alarm_start_delay > 0.0:
		await get_tree().create_timer(alarm_start_delay).timeout
		if activation_id != _activation_audio_id:
			return
	
	if _alarm_sfx_player and _alarm_sfx_player.stream:
		_alarm_sfx_player.play()


func _update_pulse() -> void:
	if not status_light:
		return
	var pulse := 0.45 + 0.45 * (0.5 + 0.5 * sin(_pulse_time * 5.0))
	status_light.color = Color(1.0, 0.2, 0.2, pulse)


func _set_pressed_visual() -> void:
	if button_face:
		button_face.color = Color(0.72, 0.14, 0.14, 1.0)
		button_face.position = Vector2(0, 2)
	if status_light:
		status_light.color = Color(0.2, 1.0, 0.25, 1.0)


func _set_idle_visual() -> void:
	if button_face:
		button_face.color = Color(0.95, 0.18, 0.18, 1.0)
		button_face.position = Vector2.ZERO
	if status_light:
		status_light.color = Color(1.0, 0.2, 0.2, 0.65)


func _play_press_feedback() -> void:
	_press_feedback_id += 1
	var feedback_id = _press_feedback_id
	_set_pressed_visual()
	if one_shot:
		return
	
	await get_tree().create_timer(0.12).timeout
	if feedback_id != _press_feedback_id:
		return
	_set_idle_visual()


func _draw() -> void:
	var can_trigger := can_be_kicked()
	var status := "READY" if can_trigger else "USED"
	var status_color := Color(1.0, 0.3, 0.3, 0.9) if can_trigger else Color(0.35, 0.9, 0.35, 0.9)
	_draw_text_label("FIRE ALARM", Vector2(0, -84), Color(1.0, 0.98, 0.92, 1.0), 20, Color(0, 0, 0, 0.92), 2)
	_draw_text_label(status, Vector2(0, 80), status_color, 18, Color(0, 0, 0, 0.85), 2)
	
	if _near_player and can_trigger:
		var prompt_alpha := 0.65 + 0.35 * sin(_pulse_time * 4.0)
		_draw_text_label("KICK", Vector2(0, -112), Color(1.0, 0.25, 0.25, prompt_alpha), 22, Color(0, 0, 0, 0.9), 2)


func _draw_text_label(
	text: String,
	pos: Vector2,
	color: Color,
	size: int = 14,
	outline_color: Color = Color(0, 0, 0, 0.85),
	outline_px: float = 1.0
) -> void:
	var font := ThemeDB.fallback_font
	if not font:
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	var offset := Vector2(-text_size.x / 2.0, text_size.y / 4.0)
	var base_pos := pos + offset
	
	# Draw small outline first for readability over bright effects.
	draw_string(font, base_pos + Vector2(-outline_px, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline_color)
	draw_string(font, base_pos + Vector2(outline_px, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline_color)
	draw_string(font, base_pos + Vector2(0, -outline_px), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline_color)
	draw_string(font, base_pos + Vector2(0, outline_px), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline_color)
	
	draw_string(font, base_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_near_player = true
		queue_redraw()


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		_near_player = false
		_pulse_time = 0.0
		if status_light and can_be_kicked():
			status_light.color = Color(1.0, 0.2, 0.2, 0.65)
		queue_redraw()


func _is_player(body: Node2D) -> bool:
	return body and (body.is_in_group("player") or body.name == "Player")
