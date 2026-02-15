extends ParallaxBackground

## Horizontal scroll factor for each parallax layer.
## Lower values = slower movement = appears farther away.
## A value of 1.0 means the layer moves at the same rate as the camera (no parallax).
## A value of 0.0 means the layer stays completely fixed horizontally.

@export var layer1_scroll_factor: float = 0.1  ## Farthest background (1.png)
@export var layer2_scroll_factor: float = 0.3  ## (2.png)
@export var layer3_scroll_factor: float = 0.5  ## (3.png)
@export var layer4_scroll_factor: float = 0.8  ## Closest foreground (4.png)


func _ready() -> void:
	_apply_scroll_factors()


func _apply_scroll_factors() -> void:
	var factors := [
		layer1_scroll_factor,
		layer2_scroll_factor,
		layer3_scroll_factor,
		layer4_scroll_factor,
	]

	var layer_index := 0
	for child in get_children():
		if child is ParallaxLayer and layer_index < factors.size():
			# Horizontal parallax only; vertical motion_scale is 1.0 so the
			# layers follow the camera exactly vertically (no vertical
			# parallax) but always remain visible on screen.
			child.motion_scale = Vector2(factors[layer_index], 1.0)
			layer_index += 1
