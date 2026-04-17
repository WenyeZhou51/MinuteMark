extends CanvasLayer

const MARGIN_PX := 80.0
const RADIUS_PX := 54.0
const STROKE_PX := 12.0
const ARC_SWEEP_DEG := 270.0
const ROTATION_SPEED_RAD := 6.0
const COLOR_FG := Color(1, 0.9, 0, 1)
const COLOR_TRACK := Color(1, 1, 1, 0.15)

var _loading := false
var _load_path := ""
var _rotation_rad := 0.0
@onready var _spinner: Node2D = $Spinner


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	layer = 200
	hide()
	_spinner.draw.connect(_on_spinner_draw)


func _process(delta: float) -> void:
	if not _loading:
		return
	_rotation_rad += ROTATION_SPEED_RAD * delta
	_spinner.queue_redraw()
	_poll_load()


func change_scene(path: String) -> void:
	_begin_load(path)


func reload_scene() -> void:
	var current := get_tree().current_scene
	if current == null or current.scene_file_path == "":
		push_warning("LoadingIndicator.reload_scene: no current scene path")
		return
	_begin_load(current.scene_file_path)


func _begin_load(path: String) -> void:
	if _loading:
		push_warning("LoadingIndicator: load already in flight, ignoring: " + path)
		return
	if not ResourceLoader.exists(path):
		push_error("LoadingIndicator: path does not exist: " + path)
		return
	var err := ResourceLoader.load_threaded_request(path)
	if err != OK:
		push_error("LoadingIndicator: load_threaded_request failed: " + str(err))
		return
	_load_path = path
	_loading = true
	show()
	_spinner.queue_redraw()


func _poll_load() -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_load_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(_load_path) as PackedScene
			_finish_load()
			if packed:
				get_tree().change_scene_to_packed(packed)
			else:
				push_error("LoadingIndicator: loaded resource is not a PackedScene")
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("LoadingIndicator: threaded load failed for " + _load_path)
			_finish_load()


func _finish_load() -> void:
	_loading = false
	_load_path = ""
	hide()


func _on_spinner_draw() -> void:
	var vp := get_viewport().get_visible_rect().size
	var center := Vector2(vp.x - MARGIN_PX, vp.y - MARGIN_PX)
	_spinner.draw_arc(center, RADIUS_PX, 0.0, TAU, 48, COLOR_TRACK, STROKE_PX, true)
	var arc_start := _rotation_rad
	var arc_end := _rotation_rad + deg_to_rad(ARC_SWEEP_DEG)
	_spinner.draw_arc(center, RADIUS_PX, arc_start, arc_end, 48, COLOR_FG, STROKE_PX, true)
