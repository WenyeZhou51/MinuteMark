extends "res://base_inner_menu.gd"

## Combined Settings menu - Video (brightness, fullscreen) + Audio (master, music, game volume)

# Video
@export var default_brightness: float = 1.0
@export var min_brightness: float = 0.3
@export var max_brightness: float = 2.0
var current_brightness: float = 1.0
var is_fullscreen: bool = false

# Audio
@export var default_master_volume: float = 1.0
@export var default_music_volume: float = 1.0
@export var default_game_volume: float = 1.0
var current_master_volume: float = 1.0
var current_music_volume: float = 1.0
var current_game_volume: float = 1.0


func _ready():
	super._ready()
	
	if has_node("MenuContainer/BackButton"):
		var back_btn = $MenuContainer/BackButton
		$MenuContainer.remove_child(back_btn)
		add_child(back_btn)
		back_btn.position = Vector2(1497, 1101)
		back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Load and apply
	load_settings()
	apply_brightness(current_brightness)
	apply_fullscreen(is_fullscreen)
	apply_master_volume(current_master_volume)
	apply_music_volume(current_music_volume)
	apply_game_volume(current_game_volume)
	if has_node("MenuContainer/ScrollContainer/InnerVBox/VideoSection/FullscreenContainer/FullscreenToggle"):
		$MenuContainer/ScrollContainer/InnerVBox/VideoSection/FullscreenContainer/FullscreenToggle.button_pressed = is_fullscreen


func get_menu_title() -> String:
	return "SETTINGS"


func load_settings():
	current_brightness = default_brightness
	is_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	current_master_volume = default_master_volume
	current_music_volume = default_music_volume
	current_game_volume = default_game_volume


# ---- Video ----
func apply_brightness(value: float):
	current_brightness = value
	var viewport = get_viewport()
	if viewport:
		var canvas_layer = get_tree().root.get_node_or_null("BrightnessControl")
		if not canvas_layer:
			canvas_layer = CanvasLayer.new()
			canvas_layer.name = "BrightnessControl"
			canvas_layer.layer = 128
			get_tree().root.call_deferred("add_child", canvas_layer)
			await get_tree().process_frame
			var color_rect = ColorRect.new()
			color_rect.name = "BrightnessRect"
			color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			canvas_layer.add_child(color_rect)
		var color_rect = canvas_layer.get_node_or_null("BrightnessRect")
		if color_rect:
			if value < 1.0:
				var darkness = 1.0 - value
				color_rect.color = Color(0, 0, 0, darkness * 0.9)
				color_rect.material = null
			elif value > 1.0:
				var brightness_boost = value - 1.0
				color_rect.color = Color(1, 1, 1, brightness_boost * 0.4)
				color_rect.material = null
			else:
				color_rect.color = Color(0, 0, 0, 0)
				color_rect.material = null


func apply_fullscreen(enabled: bool):
	is_fullscreen = enabled
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_brightness_slider_value_changed(value: float):
	apply_brightness(value)
	if has_node("MenuContainer/ScrollContainer/InnerVBox/VideoSection/BrightnessContainer/BrightnessLabel"):
		$MenuContainer/ScrollContainer/InnerVBox/VideoSection/BrightnessContainer/BrightnessLabel.text = "Screen Brightness: %.0f%%" % (value * 100)


func _on_fullscreen_toggle_toggled(toggled_on: bool):
	apply_fullscreen(toggled_on)


# ---- Audio ----
func apply_master_volume(value: float):
	current_master_volume = value
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		if value <= 0.0:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))


func apply_music_volume(value: float):
	current_music_volume = value
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx < 0:
		bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, "Music")
		AudioServer.set_bus_send(bus_idx, "Master")
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))


func apply_game_volume(value: float):
	current_game_volume = value
	var bus_idx = AudioServer.get_bus_index("Game")
	if bus_idx < 0:
		bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, "Game")
		AudioServer.set_bus_send(bus_idx, "Master")
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))


func _on_master_volume_slider_value_changed(value: float):
	apply_master_volume(value)
	if has_node("MenuContainer/ScrollContainer/InnerVBox/AudioSection/MasterVolumeContainer/MasterVolumeLabel"):
		$MenuContainer/ScrollContainer/InnerVBox/AudioSection/MasterVolumeContainer/MasterVolumeLabel.text = "Master Volume: %.0f%%" % (value * 100)


func _on_music_volume_slider_value_changed(value: float):
	apply_music_volume(value)
	if has_node("MenuContainer/ScrollContainer/InnerVBox/AudioSection/MusicVolumeContainer/MusicVolumeLabel"):
		$MenuContainer/ScrollContainer/InnerVBox/AudioSection/MusicVolumeContainer/MusicVolumeLabel.text = "Music Level: %.0f%%" % (value * 100)


func _on_game_volume_slider_value_changed(value: float):
	apply_game_volume(value)
	if has_node("MenuContainer/ScrollContainer/InnerVBox/AudioSection/GameVolumeContainer/GameVolumeLabel"):
		$MenuContainer/ScrollContainer/InnerVBox/AudioSection/GameVolumeContainer/GameVolumeLabel.text = "Game Sound: %.0f%%" % (value * 100)


func _focus_first_control():
	"""Focus first focusable control (recursive for nested containers)"""
	if not has_node("MenuContainer"):
		return
	var first = _find_first_focusable($MenuContainer)
	if first:
		first.grab_focus()


func _find_first_focusable(node: Node) -> Control:
	if node is Button or node is HSlider or node is CheckButton or node is CheckBox:
		return node as Control
	for child in node.get_children():
		var found = _find_first_focusable(child)
		if found:
			return found
	return null
