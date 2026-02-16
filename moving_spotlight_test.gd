extends CanvasLayer
## Bar-style lighting: vertical beam → full dark → new beam elsewhere (totally random position).
## One beam at a time, then screen goes dark, then a new beam pops up somewhere random.

@export var beam_open_width: float = 0.18      # half-width of vertical beam when open
@export var open_duration: float = 0.5
@export var close_duration: float = 0.4
@export var min_beam_hold: float = 0.8
@export var max_beam_hold: float = 2.2
@export var min_dark_hold: float = 0.2
@export var max_dark_hold: float = 0.8
@export var sparkle_chance: float = 0.4
@export var sparkle_duration: float = 0.35
@export var position_margin: float = 0.12      # beam center kept away from screen edges (0-1)
@export var fire_light_radius_uv: float = 0.07  # radius of fire "hole" in overlay (0-1)

@onready var overlay: ColorRect = $OverlayContainer/SpotlightOverlay
@onready var timer: Timer = $Timer

var _material: ShaderMaterial
var _current_half_width: float
var _current_center_x: float
var _tween: Tween
var _phase: String = "full_dark"  # full_dark | opening | beam | sparkling | closing

func _ready() -> void:
	if not overlay.material:
		push_error("SpotlightOverlay has no material")
		return
	_material = overlay.material as ShaderMaterial
	if not _material:
		push_error("SpotlightOverlay material is not a ShaderMaterial")
		return
	_current_half_width = 0.0
	_current_center_x = 0.5
	_material.set_shader_parameter("beam_center_x", _current_center_x)
	_material.set_shader_parameter("beam_half_width", 0.0)
	_material.set_shader_parameter("sparkle_amount", 0.0)
	timer.one_shot = true
	timer.timeout.connect(_advance_phase)
	_start_full_dark()

func _process(_delta: float) -> void:
	_update_fire_lights()

func _update_fire_lights() -> void:
	if not _material:
		return
	var cam := get_viewport().get_camera_2d()
	if not cam:
		_material.set_shader_parameter("fire_1_radius", 0.0)
		_material.set_shader_parameter("fire_2_radius", 0.0)
		return
	var vp_rect := get_viewport().get_visible_rect()
	var canvas_t := get_viewport().get_canvas_transform()
	var fires := get_tree().get_nodes_in_group("fire_lights")
	var idx := 0
	for fire in fires:
		if not is_instance_valid(fire) or not fire is Node2D:
			continue
		var screen_pos: Vector2 = canvas_t * (fire as Node2D).global_position
		var uv := Vector2(
			(screen_pos.x - vp_rect.position.x) / vp_rect.size.x,
			(screen_pos.y - vp_rect.position.y) / vp_rect.size.y
		)
		if idx == 0:
			_material.set_shader_parameter("fire_1_pos", uv)
			_material.set_shader_parameter("fire_1_radius", fire_light_radius_uv)
		elif idx == 1:
			_material.set_shader_parameter("fire_2_pos", uv)
			_material.set_shader_parameter("fire_2_radius", fire_light_radius_uv)
		idx += 1
		if idx >= 2:
			break
	if idx == 0:
		_material.set_shader_parameter("fire_1_radius", 0.0)
		_material.set_shader_parameter("fire_2_radius", 0.0)
	elif idx == 1:
		_material.set_shader_parameter("fire_2_radius", 0.0)

func _start_full_dark() -> void:
	_phase = "full_dark"
	_set_width(0.0)
	timer.wait_time = randf_range(min_dark_hold, max_dark_hold)
	timer.start()

func _pick_random_beam_position() -> void:
	var lo := position_margin
	var hi := 1.0 - position_margin
	_current_center_x = randf_range(lo, hi)
	_material.set_shader_parameter("beam_center_x", _current_center_x)

func _advance_phase() -> void:
	match _phase:
		"full_dark":
			# New beam elsewhere: pick random X, then open
			_pick_random_beam_position()
			_phase = "opening"
			_tween_width_to(beam_open_width, open_duration, _on_opening_done)
		"beam":
			if randf() < sparkle_chance:
				_phase = "sparkling"
				_do_sparkle()
			else:
				_phase = "closing"
				_tween_width_to(0.0, close_duration, _on_closing_done)
		"closing":
			_start_full_dark()

func _on_opening_done() -> void:
	_phase = "beam"
	_current_half_width = beam_open_width
	timer.wait_time = randf_range(min_beam_hold, max_beam_hold)
	timer.start()

func _on_closing_done() -> void:
	_current_half_width = 0.0
	_start_full_dark()

func _set_width(half_width: float) -> void:
	_current_half_width = half_width
	_material.set_shader_parameter("beam_half_width", half_width)

func _tween_width_to(target: float, duration: float, on_finished: Callable) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_set_width, _current_half_width, target, duration)
	_tween.tween_callback(on_finished)

func _do_sparkle() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_sparkle, 0.0, 0.9, sparkle_duration * 0.3)
	_tween.tween_method(_set_sparkle, 0.9, 0.0, sparkle_duration * 0.7)
	_tween.tween_callback(func() -> void:
		_material.set_shader_parameter("sparkle_amount", 0.0)
		_phase = "closing"
		_tween_width_to(0.0, close_duration, _on_closing_done)
	)

func _set_sparkle(amount: float) -> void:
	_material.set_shader_parameter("sparkle_amount", amount)
