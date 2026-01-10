extends CanvasLayer

@onready var timer_label: Label = $Control/TimerBackground/TimerLabel

@export_group("Font Settings")
@export var custom_font: Font
@export var font_size: int = 180
@export var font_color: Color = Color.WHITE
@export var outline_color: Color = Color.BLACK
@export var outline_size: int = 8
@export var shadow_color: Color = Color(1, 0, 1, 1)
@export var shadow_offset: Vector2 = Vector2(5, 10)

func _ready() -> void:
	_apply_font_settings()

func _apply_font_settings() -> void:
	if not timer_label:
		return
	
	if custom_font:
		timer_label.add_theme_font_override("font", custom_font)
	
	if font_size > 0:
		timer_label.add_theme_font_size_override("font_size", font_size)
		
	timer_label.add_theme_color_override("font_color", font_color)
	timer_label.add_theme_color_override("font_outline_color", outline_color)
	timer_label.add_theme_constant_override("outline_size", outline_size)
	timer_label.add_theme_color_override("font_shadow_color", shadow_color)
	timer_label.add_theme_constant_override("shadow_offset_x", int(shadow_offset.x))
	timer_label.add_theme_constant_override("shadow_offset_y", int(shadow_offset.y))

func update_display(current_time: float) -> void:
	if not timer_label:
		return
	
	var total_seconds = max(0, current_time)
	var seconds = int(total_seconds)
	var centiseconds = int((total_seconds - seconds) * 100)
	
	timer_label.text = "%02d:%02d" % [seconds, centiseconds]

