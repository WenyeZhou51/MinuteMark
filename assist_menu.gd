extends "res://base_inner_menu.gd"

## Assist settings menu - godmode, infinite jumps, and time slow controls

@export var default_godmode: bool = false
@export var default_infinite_jumps: bool = false
@export var default_time_slow: float = 0.0  # 0% = normal speed, 100% = maximum slowdown

var godmode_enabled: bool = false
var infinite_jumps_enabled: bool = false
var time_slow_percent: float = 0.0
var base_time_scale: float = 1.0  # Normal game speed


func _ready():
	super._ready()
	
	# Load saved settings
	load_settings()
	
	# Apply current settings
	apply_godmode(godmode_enabled)
	apply_infinite_jumps(infinite_jumps_enabled)
	apply_time_slow(time_slow_percent)


func get_menu_title() -> String:
	return "ASSIST OPTIONS"


func load_settings():
	"""Load assist settings from config file or use defaults"""
	# For now, use defaults - later can add config file support
	godmode_enabled = default_godmode
	infinite_jumps_enabled = default_infinite_jumps
	time_slow_percent = default_time_slow


func save_settings():
	"""Save assist settings to config file"""
	# For now, settings are applied immediately
	# Later can add config file support
	pass


func apply_godmode(enabled: bool):
	"""Apply godmode setting - makes player invulnerable"""
	godmode_enabled = enabled
	
	# Find the player and set invulnerability
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		# Try alternative search
		player = get_node_or_null("/root/Level/Player")
	
	if player:
		# Set godmode property if it exists
		if "is_invulnerable" in player:
			player.is_invulnerable = enabled
		
		# Also disable stun if godmode is on
		if enabled and "is_stunned" in player:
			if player.is_stunned:
				player._end_stun() if player.has_method("_end_stun") else null
	
	save_settings()


func apply_infinite_jumps(enabled: bool):
	"""Apply infinite jumps setting"""
	infinite_jumps_enabled = enabled
	
	# Find the player and set infinite jumps
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("/root/Level/Player")
	
	if player:
		# Store the infinite jumps state in the player
		# The player script will need to check this when handling jumps
		player.set_meta("infinite_jumps_enabled", enabled)
	
	save_settings()


func apply_time_slow(percent: float):
	"""Apply time slow setting (0% = normal, 100% = maximum slowdown)
	   This only affects in-game time, not menus or animations"""
	time_slow_percent = percent
	
	# Calculate time scale: 0% = 1.0 (normal), 100% = 0.1 (90% slower)
	# Formula: time_scale = 1.0 - (percent / 100.0) * 0.9
	var target_time_scale = 1.0 - (percent / 100.0) * 0.9
	
	# Only apply time scale when not in a menu
	# The pause menu and inner menus should not be affected
	var is_in_menu = get_tree().paused
	
	if not is_in_menu:
		Engine.time_scale = target_time_scale
	
	# Store the desired time scale so it can be applied when exiting menus
	get_tree().root.set_meta("assist_time_scale", target_time_scale)
	
	save_settings()


func get_current_time_scale() -> float:
	"""Get the current assist time scale setting"""
	if get_tree().root.has_meta("assist_time_scale"):
		return get_tree().root.get_meta("assist_time_scale")
	return 1.0


func _on_godmode_toggle_toggled(toggled_on: bool):
	"""Called when godmode toggle changes"""
	apply_godmode(toggled_on)


func _on_infinite_jumps_toggle_toggled(toggled_on: bool):
	"""Called when infinite jumps toggle changes"""
	apply_infinite_jumps(toggled_on)


func _on_time_slow_slider_value_changed(value: float):
	"""Called when time slow slider changes"""
	apply_time_slow(value)
	
	# Update label
	if has_node("MenuContainer/TimeSlowContainer/TimeSlowLabel"):
		$MenuContainer/TimeSlowContainer/TimeSlowLabel.text = "Time Slow: %.0f%%" % value


