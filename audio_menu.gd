extends "res://base_inner_menu.gd"

## Audio settings menu - master, music, and game sound volume controls

@export var default_master_volume: float = 1.0
@export var default_music_volume: float = 1.0
@export var default_game_volume: float = 1.0

var current_master_volume: float = 1.0
var current_music_volume: float = 1.0
var current_game_volume: float = 1.0


func _ready():
	super._ready()
	
	# IMPROVEMENT: Ensure BackButton is correctly accessible and on top
	# We reparent it to the root node to match the structure of input_menu.tscn
	# This fixes the "stuck hover color" issue caused by container focus/layout interference
	if has_node("MenuContainer/BackButton"):
		var back_btn = $MenuContainer/BackButton
		$MenuContainer.remove_child(back_btn)
		add_child(back_btn)
		
		# Set position to match input_menu (bottom right)
		back_btn.position = Vector2(1497, 1101)
		
		# Explicitly set mouse filter to STOP
		back_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Load saved settings
	load_settings()
	
	# Apply current settings
	apply_master_volume(current_master_volume)
	apply_music_volume(current_music_volume)
	apply_game_volume(current_game_volume)


func get_menu_title() -> String:
	return "AUDIO SETTINGS"


func load_settings():
	"""Load audio settings from config file or use defaults"""
	# For now, use defaults - later can add config file support
	current_master_volume = default_master_volume
	current_music_volume = default_music_volume
	current_game_volume = default_game_volume


func save_settings():
	"""Save audio settings to config file"""
	# For now, settings are applied immediately
	# Later can add config file support
	pass


func apply_master_volume(value: float):
	"""Apply master volume setting (affects all audio)"""
	current_master_volume = value
	
	# Get the master audio bus (index 0)
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		# Convert linear volume (0-1) to decibels
		if value <= 0.0:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			var db = linear_to_db(value)
			AudioServer.set_bus_volume_db(bus_idx, db)
	
	save_settings()


func apply_music_volume(value: float):
	"""Apply music volume setting"""
	current_music_volume = value
	
	# Get the music audio bus (create if doesn't exist)
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx < 0:
		# Create music bus if it doesn't exist
		bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, "Music")
		AudioServer.set_bus_send(bus_idx, "Master")
	
	# Set volume
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		var db = linear_to_db(value)
		AudioServer.set_bus_volume_db(bus_idx, db)
	
	save_settings()


func apply_game_volume(value: float):
	"""Apply game sound effects volume setting"""
	current_game_volume = value
	
	# Get the game audio bus (create if doesn't exist)
	var bus_idx = AudioServer.get_bus_index("Game")
	if bus_idx < 0:
		# Create game bus if it doesn't exist
		bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, "Game")
		AudioServer.set_bus_send(bus_idx, "Master")
	
	# Set volume
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		var db = linear_to_db(value)
		AudioServer.set_bus_volume_db(bus_idx, db)
	
	save_settings()


func _on_master_volume_slider_value_changed(value: float):
	"""Called when master volume slider changes"""
	apply_master_volume(value)
	
	# Update label
	if has_node("MenuContainer/MasterVolumeContainer/MasterVolumeLabel"):
		$MenuContainer/MasterVolumeContainer/MasterVolumeLabel.text = "Master Volume: %.0f%%" % (value * 100)


func _on_music_volume_slider_value_changed(value: float):
	"""Called when music volume slider changes"""
	apply_music_volume(value)
	
	# Update label
	if has_node("MenuContainer/MusicVolumeContainer/MusicVolumeLabel"):
		$MenuContainer/MusicVolumeContainer/MusicVolumeLabel.text = "Music Level: %.0f%%" % (value * 100)


func _on_game_volume_slider_value_changed(value: float):
	"""Called when game volume slider changes"""
	apply_game_volume(value)
	
	# Update label
	if has_node("MenuContainer/GameVolumeContainer/GameVolumeLabel"):
		$MenuContainer/GameVolumeContainer/GameVolumeLabel.text = "Game Sound: %.0f%%" % (value * 100)


