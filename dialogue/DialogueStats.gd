# DialogueStats.gd
extends Node

# Singleton to track dialogue choices per level

const SAVE_FILE_PATH = "user://dialogue_stats.cfg"

# Structure: level_path -> {interrupt_count: int, peaceful_count: int, has_peaceful: bool}
var level_stats: Dictionary = {}

# Current level path (set when level starts)
var current_level_path: String = ""

func _ready():
	load_stats()

func set_current_level(level_path: String) -> void:
	"""Set the current level path. Call this when a level starts."""
	current_level_path = level_path
	
	# Reload stats from disk to ensure we have the latest data
	load_stats()
	
	# Initialize stats for this level if not exists
	if not level_stats.has(level_path):
		level_stats[level_path] = {
			"interrupt_count": 0,
			"peaceful_count": 0,
			"has_peaceful": false
		}

func record_interrupt() -> void:
	"""Record an interruption choice for the current level."""
	if current_level_path == "":
		return
	
	if not level_stats.has(current_level_path):
		set_current_level(current_level_path)
	
	level_stats[current_level_path]["interrupt_count"] += 1
	save_stats()

func record_peaceful() -> void:
	"""Record a peaceful choice for the current level."""
	if current_level_path == "":
		return
	
	if not level_stats.has(current_level_path):
		set_current_level(current_level_path)
	
	level_stats[current_level_path]["peaceful_count"] += 1
	level_stats[current_level_path]["has_peaceful"] = true
	save_stats()

func get_level_stats(level_path: String) -> Dictionary:
	"""Get statistics for a specific level."""
	if not level_stats.has(level_path):
		return {
			"interrupt_count": 0,
			"peaceful_count": 0,
			"has_peaceful": false
		}
	return level_stats[level_path].duplicate()

func get_current_level_stats() -> Dictionary:
	"""Get statistics for the current level."""
	var stats = get_level_stats(current_level_path)
	return stats

func reset_level_stats(level_path: String) -> void:
	"""Reset statistics for a specific level."""
	if level_stats.has(level_path):
		level_stats[level_path] = {
			"interrupt_count": 0,
			"peaceful_count": 0,
			"has_peaceful": false
		}
		save_stats()

func reset_current_level_stats() -> void:
	"""Reset statistics for the current level."""
	reset_level_stats(current_level_path)

func save_stats() -> void:
	"""Save dialogue statistics to file."""
	var config = ConfigFile.new()
	
	for level_path in level_stats.keys():
		var stats = level_stats[level_path]
		# Use a safe key format (replace / with _)
		var safe_key = level_path.replace("/", "_").replace("res:", "res").replace(".tscn", "")
		config.set_value("dialogue_stats", safe_key + "_interrupt", stats["interrupt_count"])
		config.set_value("dialogue_stats", safe_key + "_peaceful", stats["peaceful_count"])
		config.set_value("dialogue_stats", safe_key + "_has_peaceful", stats["has_peaceful"])
	
	var error = config.save(SAVE_FILE_PATH)
	if error != OK:
		push_error("DialogueStats: Failed to save stats: " + str(error))
	else:
		pass

func load_stats() -> void:
	"""Load dialogue statistics from file."""
	var config = ConfigFile.new()
	var error = config.load(SAVE_FILE_PATH)
	
	if error != OK:
		# File doesn't exist - start fresh
		level_stats = {}
		return
	
	level_stats = {}
	
	# Get all keys from the dialogue_stats section
	var section = "dialogue_stats"
	if not config.has_section(section):
		return
	
	var keys = config.get_section_keys(section)
	var processed_levels: Dictionary = {}
	
	# Group keys by level
	for key in keys:
		# Parse key format: res_level_tscn_interrupt, res_level_tscn_peaceful, etc.
		var parts = key.split("_")
		if parts.size() < 2:
			continue
		
		# Reconstruct level path (e.g., "res_level_tscn" -> "res://level.tscn")
		# Find where the stat type starts (interrupt, peaceful, has_peaceful)
		var stat_type = ""
		if key.ends_with("_interrupt"):
			stat_type = "interrupt"
		elif key.ends_with("_peaceful"):
			stat_type = "peaceful"
		elif key.ends_with("_has_peaceful"):
			stat_type = "has_peaceful"
		else:
			continue
		
		# Remove the stat type suffix to get the level identifier
		var level_key = key.substr(0, key.length() - stat_type.length() - 1)  # -1 for the underscore
		
		# Convert back to scene path format
		# "res__level" -> "res://level.tscn"
		# First replace "res__" with "res://", then replace remaining "_" with "/"
		var level_path = level_key.replace("res__", "res://").replace("_", "/") + ".tscn"
		
		if not processed_levels.has(level_path):
			processed_levels[level_path] = {
				"interrupt_count": 0,
				"peaceful_count": 0,
				"has_peaceful": false
			}
		
		var value = config.get_value(section, key)
		match stat_type:
			"interrupt":
				processed_levels[level_path]["interrupt_count"] = value
			"peaceful":
				processed_levels[level_path]["peaceful_count"] = value
			"has_peaceful":
				processed_levels[level_path]["has_peaceful"] = value
	
	level_stats = processed_levels
