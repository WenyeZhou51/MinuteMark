extends "res://base_inner_menu.gd"

## Video settings menu - brightness and fullscreen controls

@export var default_brightness: float = 1.0
@export var min_brightness: float = 0.3
@export var max_brightness: float = 2.0

var current_brightness: float = 1.0
var is_fullscreen: bool = false


func _ready():
	super._ready()
	
	# Load saved settings
	load_settings()
	
	# Apply current settings
	apply_brightness(current_brightness)
	apply_fullscreen(is_fullscreen)


func get_menu_title() -> String:
	return "VIDEO SETTINGS"


func load_settings():
	"""Load video settings from config file or use defaults"""
	# For now, use defaults - later can add config file support
	current_brightness = default_brightness
	is_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func save_settings():
	"""Save video settings to config file"""
	# For now, settings are applied immediately
	# Later can add config file support
	pass


func apply_brightness(value: float):
	"""Apply brightness setting to the game"""
	current_brightness = value
	
	# Get the viewport and apply brightness via an overlay
	var viewport = get_viewport()
	if viewport:
		# Find or create the brightness control canvas layer
		var canvas_layer = get_tree().root.get_node_or_null("BrightnessControl")
		if not canvas_layer:
			# Create a canvas layer for brightness control if it doesn't exist
			canvas_layer = CanvasLayer.new()
			canvas_layer.name = "BrightnessControl"
			canvas_layer.layer = 128  # High layer to affect everything
			get_tree().root.add_child(canvas_layer)
			
			var color_rect = ColorRect.new()
			color_rect.name = "BrightnessRect"
			color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			canvas_layer.add_child(color_rect)
		
		var color_rect = canvas_layer.get_node_or_null("BrightnessRect")
		if color_rect:
			# Adjust brightness using overlay technique
			# value = 1.0 is normal (no overlay)
			# value < 1.0 = darker (black overlay with increasing opacity)
			# value > 1.0 = brighter (white overlay with additive blend)
			
			if value < 1.0:
				# Darken: use black overlay
				var darkness = 1.0 - value  # 0.0 to 0.7 (when value is 1.0 to 0.3)
				color_rect.color = Color(0, 0, 0, darkness * 0.9)  # Scale to prevent complete blackout
				color_rect.material = null  # Remove any shader material
			elif value > 1.0:
				# Brighten: use white overlay with reduced opacity
				var brightness_boost = value - 1.0  # 0.0 to 1.0 (when value is 1.0 to 2.0)
				color_rect.color = Color(1, 1, 1, brightness_boost * 0.4)  # Subtle brightening
				color_rect.material = null
			else:
				# Normal brightness: make overlay invisible
				color_rect.color = Color(0, 0, 0, 0)
				color_rect.material = null
	
	save_settings()


func apply_fullscreen(enabled: bool):
	"""Apply fullscreen setting"""
	is_fullscreen = enabled
	
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	save_settings()


func _on_brightness_slider_value_changed(value: float):
	"""Called when brightness slider changes"""
	apply_brightness(value)
	
	# Update label
	if has_node("MenuContainer/BrightnessContainer/BrightnessLabel"):
		$MenuContainer/BrightnessContainer/BrightnessLabel.text = "Screen Brightness: %.0f%%" % (value * 100)


func _on_fullscreen_toggle_toggled(toggled_on: bool):
	"""Called when fullscreen toggle changes"""
	apply_fullscreen(toggled_on)


