extends ParallaxBackground

const LAYER_SCALE := Vector2.ONE
const LAYERS := [
	{"path": "res://parallax/Merged-1.png", "ratio": 0.1},
	{"path": "res://parallax/Merged-2.png", "ratio": 0.2},
	{"path": "res://parallax/Merged-3.png", "ratio": 0.35},
	{"path": "res://parallax/Merged-4.png", "ratio": 0.5},
]

@onready var bounds_node: Node2D = $Bounds
@onready var bounds_shape: CollisionShape2D = $Bounds/CollisionShape2D

var bounds_offset_y := 0.0


func _ready() -> void:
	_cache_bounds()
	scroll_base_scale = Vector2(1.0, 0.0)
	_build_layers()

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		scroll_offset.y = -camera.global_position.y + bounds_offset_y
	else:
		scroll_offset.y = bounds_offset_y
	scroll_base_offset.y = 0.0


func _cache_bounds() -> void:
	if not bounds_node or not bounds_shape or not (bounds_shape.shape is RectangleShape2D):
		push_warning("Parallax bounds missing or invalid. Add Bounds/CollisionShape2D with RectangleShape2D.")
		return
	bounds_offset_y = bounds_node.position.y


func _get_bounds_rect() -> Rect2:
	if not bounds_shape or not (bounds_shape.shape is RectangleShape2D):
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var shape := bounds_shape.shape as RectangleShape2D
	var rect_size := shape.size
	var rect_pos := bounds_node.position - rect_size / 2.0
	return Rect2(rect_pos, rect_size)


func _build_layers() -> void:
	for child in get_children():
		if child is ParallaxLayer:
			child.queue_free()

	var bounds_rect := _get_bounds_rect()
	if bounds_rect.size == Vector2.ZERO:
		push_warning("Parallax bounds size is zero. Adjust Bounds rectangle in editor.")

	var prev_ratio := 0.0
	for layer_index in range(LAYERS.size()):
		var layer_info: Dictionary = LAYERS[layer_index]
		var texture_path := String(layer_info.get("path", ""))
		var raw_ratio := float(layer_info.get("ratio", 0.0))
		var ratio: float = clampf(raw_ratio, 0.0, 1.0)
		if ratio < prev_ratio:
			push_warning("Parallax layer ratio out of order for %s. Adjusting to %s." % [texture_path, prev_ratio])
			ratio = prev_ratio
		prev_ratio = ratio

		var texture := load(texture_path)
		if not texture:
			push_error("Parallax layer texture not found: %s" % texture_path)
			continue
		var texture_size: Vector2 = texture.get_size()
		if texture_size.y <= 0.0:
			push_warning("Parallax layer texture has invalid size: %s" % texture_path)
			continue

		var scale_factor := bounds_rect.size.y / texture_size.y if bounds_rect.size.y > 0.0 else 1.0

		var layer := ParallaxLayer.new()
		layer.motion_scale = Vector2(ratio, 0.0)
		layer.z_index = layer_index

		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.scale = LAYER_SCALE * scale_factor
		sprite.position = bounds_rect.position
		layer.motion_mirroring = Vector2(texture_size.x * scale_factor, 0.0)

		layer.add_child(sprite)
		add_child(layer)
