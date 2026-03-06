# leaderboard_manager.gd
extends Node

# Signals
signal global_leaderboard_updated

# Leaderboard data structure: Array of dictionaries with "time", "date", "player_id", "player_name", "ip_address" keys
# Lower times are better (faster completion)
# Local leaderboard is per-level: Dictionary mapping level_index (int) -> Array of score dicts
var all_local_leaderboard_data: Dictionary = {}  # {level_index: [{time, date, ...}, ...]}
var global_leaderboard_data: Array[Dictionary] = []

const MAX_ENTRIES: int = 100  # Keep top 100 scores locally
const MAX_GLOBAL_PER_LEVEL: int = 20  # Keep top 20 scores per level on Supabase

# Track last submitted level for leaderboard scene
var last_submitted_level: int = 0
var last_submitted_time: float = 0.0
const SAVE_PATH: String = "user://leaderboard.json"
const PLAYER_ID_PATH: String = "user://player_id.txt"
const PLAYER_NAME_PATH: String = "user://player_name.txt"

# Player identification
var player_id: String = ""
var player_name: String = "PLAYER"
var local_ip_address: String = ""

# Supabase Configuration
const SUPABASE_URL: String = "https://btwtuohajgnvvacpklyj.supabase.co"
const SUPABASE_API_KEY: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ0d3R1b2hhamdudnZhY3BrbHlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk4OTE0NjYsImV4cCI6MjA4NTQ2NzQ2Nn0.Q0JvPC6nth5EXlM13d-_PlbNSDNh77krKKeFQoOjwWc"
const SUPABASE_TABLE: String = "Leaderboard"
var api_enabled: bool = true  # Set to true to enable Supabase integration

# HTTP request tracking
var http_request: HTTPRequest
var is_submitting: bool = false
var is_fetching: bool = false

func _ready():
	# CRITICAL: Allow this manager to process even when game is paused (for HTTP during victory screen)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	load_player_id()
	load_player_name()
	get_local_ip_address()
	load_local_leaderboard()
	
	# Setup HTTP request node
	http_request = HTTPRequest.new()
	http_request.name = "SupabaseHTTPRequest"
	# CRITICAL: Allow HTTPRequest to process even when game is paused
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)
	
	# Set timeout to 10 seconds
	http_request.timeout = 10.0
	
	# Try to fetch global leaderboard on startup if API is enabled
	if api_enabled:
		fetch_global_leaderboard()

func get_local_ip_address():
	"""Get the local IP address of this machine."""
	# Try to get IP from network interfaces
	var interfaces = IP.get_local_addresses()
	for ip in interfaces:
		# Filter out localhost and IPv6 link-local addresses
		if ip != "127.0.0.1" and not ip.begins_with("fe80:"):
			local_ip_address = ip
			return
	
	# Fallback: use a generated identifier if we can't get IP
	if local_ip_address.is_empty():
		local_ip_address = "unknown_" + player_id.substr(0, 8)

func load_player_id():
	"""Load or generate a unique player ID."""
	if FileAccess.file_exists(PLAYER_ID_PATH):
		var file = FileAccess.open(PLAYER_ID_PATH, FileAccess.READ)
		if file:
			player_id = file.get_as_text().strip_edges()
			file.close()
	
	# Generate new ID if none exists
	if player_id.is_empty():
		player_id = _generate_player_id()
		save_player_id()
	

func save_player_id():
	"""Save player ID to file."""
	var file = FileAccess.open(PLAYER_ID_PATH, FileAccess.WRITE)
	if file:
		file.store_string(player_id)
		file.close()

func load_player_name():
	"""Load player name from file."""
	if FileAccess.file_exists(PLAYER_NAME_PATH):
		var file = FileAccess.open(PLAYER_NAME_PATH, FileAccess.READ)
		if file:
			player_name = file.get_as_text().strip_edges().to_upper()
			file.close()
			if player_name.is_empty():
				player_name = "PLAYER"
	

func set_player_name(name: String):
	"""Set and save player name."""
	player_name = name.to_upper()
	var file = FileAccess.open(PLAYER_NAME_PATH, FileAccess.WRITE)
	if file:
		file.store_string(player_name)
		file.close()

func _generate_player_id() -> String:
	"""Generate a unique player ID."""
	# Combine timestamp with random number for uniqueness
	var timestamp = str(Time.get_unix_time_from_system())
	var random = str(randi() % 1000000)
	return "player_" + timestamp + "_" + random

func _get_local_data_for_level(level_index: int) -> Array:
	"""Get the local leaderboard array for a specific level, creating it if needed."""
	var key = str(level_index)
	if not all_local_leaderboard_data.has(key):
		all_local_leaderboard_data[key] = []
	return all_local_leaderboard_data[key]

func _set_local_data_for_level(level_index: int, data: Array) -> void:
	"""Set the local leaderboard array for a specific level."""
	all_local_leaderboard_data[str(level_index)] = data

func add_score(time_taken: float) -> bool:
	"""Add a new score to the leaderboard. Returns true if it's a new best score."""
	var level = get_current_level_index()
	var local_data = _get_local_data_for_level(level)
	
	var new_entry = {
		"time": time_taken,
		"date": Time.get_datetime_string_from_system(),
		"player_id": player_id,
		"player_name": player_name,
		"ip_address": local_ip_address
	}
	
	var is_new_best = false
	if local_data.is_empty() or time_taken < local_data[0]["time"]:
		is_new_best = true
	
	# Check for existing entry with same name (unique name constraint)
	var existing_idx = -1
	for i in range(local_data.size()):
		if local_data[i].get("player_name", "").to_upper() == player_name.to_upper():
			existing_idx = i
			break
	
	if existing_idx >= 0:
		# Name already exists locally — only update if new time is better
		if time_taken < local_data[existing_idx]["time"]:
			local_data[existing_idx] = new_entry
		# If existing time is better or equal, don't modify local data
	else:
		# New name — add to local leaderboard
		local_data.append(new_entry)
	
	# Sort by time (ascending - lower is better)
	local_data.sort_custom(func(a, b): return a["time"] < b["time"])
	
	# Keep only top MAX_ENTRIES
	if local_data.size() > MAX_ENTRIES:
		local_data = local_data.slice(0, MAX_ENTRIES)
	
	_set_local_data_for_level(level, local_data)
	save_local_leaderboard()
	
	# Submit to global leaderboard if API is enabled
	# Skip INSERT if name already exists globally (to prevent duplicates)
	if api_enabled:
		var existing_global = find_existing_entry_by_name(player_name)
		if existing_global.is_empty():
			submit_score_to_api(new_entry)
		else:
			pass  # Name already exists globally, skip INSERT
	
	return is_new_best

func would_make_leaderboard(time_taken: float) -> bool:
	"""Check if a time would qualify for the top 20 global leaderboard."""
	# If we have fewer than MAX_GLOBAL_PER_LEVEL entries, it always qualifies
	if global_leaderboard_data.size() < MAX_GLOBAL_PER_LEVEL:
		return true
	# If the new time is better (lower) than the worst entry in top 20, it qualifies
	var worst_time = global_leaderboard_data[global_leaderboard_data.size() - 1]["time"]
	return time_taken < worst_time

func find_existing_entry_by_name(name: String) -> Dictionary:
	"""Find an existing entry in the global leaderboard by player name (case-insensitive)."""
	var upper_name = name.to_upper()
	for entry in global_leaderboard_data:
		if entry.get("player_name", "").to_upper() == upper_name:
			return entry
	return {}

func update_score_for_name(new_time: float) -> bool:
	"""Update an existing score for the current player name. Returns true if it's a new best."""
	var level = get_current_level_index()
	var local_data = _get_local_data_for_level(level)
	
	var is_new_best = false
	if local_data.is_empty() or new_time < local_data[0]["time"]:
		is_new_best = true
	
	# Update local leaderboard
	var found_local = false
	for i in range(local_data.size()):
		if local_data[i].get("player_name", "").to_upper() == player_name.to_upper():
			local_data[i]["time"] = new_time
			local_data[i]["date"] = Time.get_datetime_string_from_system()
			found_local = true
			break
	
	if not found_local:
		var new_entry = {
			"time": new_time,
			"date": Time.get_datetime_string_from_system(),
			"player_id": player_id,
			"player_name": player_name,
			"ip_address": local_ip_address
		}
		local_data.append(new_entry)
	
	# Sort and trim
	local_data.sort_custom(func(a, b): return a["time"] < b["time"])
	if local_data.size() > MAX_ENTRIES:
		local_data = local_data.slice(0, MAX_ENTRIES)
	_set_local_data_for_level(level, local_data)
	save_local_leaderboard()
	
	# Update on Supabase via PATCH
	if api_enabled:
		_update_score_on_api(new_time)
	
	return is_new_best

func _update_score_on_api(new_time: float):
	"""Update an existing score on Supabase using HTTP PATCH."""
	if is_submitting:
		return
	
	if not api_enabled:
		return
	
	is_submitting = true
	
	var level = get_current_level_index()
	last_submitted_level = level
	last_submitted_time = new_time
	
	var encoded_name = player_name.uri_encode()
	var url = SUPABASE_URL + "/rest/v1/" + SUPABASE_TABLE + "?player_name=eq." + encoded_name + "&level=eq." + str(level)
	var payload = {"time_taken": new_time}
	var json_payload = JSON.stringify(payload)
	
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_API_KEY,
		"Authorization: Bearer " + SUPABASE_API_KEY,
		"Prefer: return=minimal"
	]
	
	set_meta("is_updating_entry", true)
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_PATCH, json_payload)
	if error != OK:
		push_error("LeaderboardManager: HTTP PATCH request failed. Error code: %d" % error)
		is_submitting = false
		remove_meta("is_updating_entry")

func get_current_level_index() -> int:
	"""Determine the current level index from the scene path."""
	var level_paths = [
		"res://level.tscn",      # Level 0 - The First Minute (Tutorial)
		"res://level1.3.tscn",   # Level 1 - Neon Countdown
		"res://level1.1.tscn",   # Level 2 - Neon Countdown Alternative
		"res://level1.tscn",     # Level 3
	]
	
	var tree = get_tree()
	if tree and tree.current_scene:
		var current_path = tree.current_scene.scene_file_path
		for i in range(level_paths.size()):
			if level_paths[i] == current_path:
				return i
	return 0

func submit_score_to_api(score_data: Dictionary):
	"""Submit a score to Supabase. First checks if cleanup is needed.
	Submits exactly ONE entry for the level the player just completed — never loops over levels."""
	if is_submitting:
		return
	
	if not api_enabled:
		return
	
	is_submitting = true
	
	# Capture level once — we submit only for this level, never for all levels
	var level = get_current_level_index()
	last_submitted_level = level
	last_submitted_time = score_data["time"]
	
	# Store the score data for later use after checking for cleanup (single entry only)
	var pending_submission = {
		"player_name": score_data.get("player_name", "Player"),
		"time_taken": score_data["time"],
		"level": level
	}
	
	# Store this so we can access it in the callback
	set_meta("pending_submission", pending_submission)
	
	# First, check how many entries exist for this level and get the worst one
	var check_url = SUPABASE_URL + "/rest/v1/" + SUPABASE_TABLE + "?select=id,time_taken&level=eq.%d&order=time_taken.desc&limit=1" % level
	
	var headers = [
		"apikey: " + SUPABASE_API_KEY,
		"Authorization: Bearer " + SUPABASE_API_KEY
	]
	
	# Set a flag to indicate this is a cleanup check, not a submission or fetch
	set_meta("is_checking_cleanup", true)
	
	var error = http_request.request(check_url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("LeaderboardManager: HTTP request failed to initiate cleanup check. Error code: %d" % error)
		is_submitting = false
		remove_meta("is_checking_cleanup")
		remove_meta("pending_submission")

func _count_level_entries(level: int):
	"""Count how many entries exist for a given level."""
	var count_url = SUPABASE_URL + "/rest/v1/" + SUPABASE_TABLE + "?select=id&level=eq.%d" % level
	
	var headers = [
		"apikey: " + SUPABASE_API_KEY,
		"Authorization: Bearer " + SUPABASE_API_KEY
	]
	
	set_meta("is_counting_entries", true)
	
	var error = http_request.request(count_url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("LeaderboardManager: HTTP request failed to count entries. Error code: %d" % error)
		is_submitting = false
		remove_meta("is_counting_entries")
		remove_meta("pending_submission")

func _delete_worst_entry(entry_id: int):
	"""Delete the worst (highest time) entry from the database."""
	var delete_url = SUPABASE_URL + "/rest/v1/" + SUPABASE_TABLE + "?id=eq.%d" % entry_id
	
	var headers = [
		"apikey: " + SUPABASE_API_KEY,
		"Authorization: Bearer " + SUPABASE_API_KEY
	]
	
	set_meta("is_deleting_entry", true)
	
	var error = http_request.request(delete_url, headers, HTTPClient.METHOD_DELETE)
	if error != OK:
		push_error("LeaderboardManager: HTTP request failed to delete entry. Error code: %d" % error)
		is_submitting = false
		remove_meta("is_deleting_entry")
		remove_meta("pending_submission")

func _actually_submit_score():
	"""Actually submit the score after cleanup is done. Inserts exactly one row for the completed level."""
	if not has_meta("pending_submission"):
		push_error("LeaderboardManager: No pending submission found!")
		is_submitting = false
		return
	
	var supabase_payload = get_meta("pending_submission")
	var url = SUPABASE_URL + "/rest/v1/" + SUPABASE_TABLE
	
	var json_payload = JSON.stringify(supabase_payload)
	var headers = [
		"Content-Type: application/json",
		"apikey: " + SUPABASE_API_KEY,
		"Authorization: Bearer " + SUPABASE_API_KEY,
		"Prefer: return=minimal"
	]
	
	set_meta("is_actually_submitting", true)
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_payload)
	if error != OK:
		push_error("LeaderboardManager: HTTP request failed to submit score. Error code: %d" % error)
		is_submitting = false
		remove_meta("is_actually_submitting")
		remove_meta("pending_submission")

func fetch_global_leaderboard(level: int = -1):
	"""Fetch the global leaderboard from Supabase. If level is -1, uses last_submitted_level."""
	if is_fetching:
		return
	
	if not api_enabled:
		return
	
	if level == -1:
		level = last_submitted_level
	
	is_fetching = true
	# Fetch top 20 scores for the level, ordered by time_taken ascending
	var url = SUPABASE_URL + "/rest/v1/" + SUPABASE_TABLE + "?select=*&level=eq.%d&order=time_taken.asc&limit=%d" % [level, MAX_GLOBAL_PER_LEVEL]
	
	var headers = [
		"apikey: " + SUPABASE_API_KEY,
		"Authorization: Bearer " + SUPABASE_API_KEY
	]
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("LeaderboardManager: HTTP request failed to initiate. Error code: %d" % error)
		is_fetching = false

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	"""Handle HTTP request completion."""
	var response_text = body.get_string_from_utf8()
	
	# Handle entry update via PATCH
	if has_meta("is_updating_entry"):
		remove_meta("is_updating_entry")
		is_submitting = false
		
		if response_code == 200 or response_code == 204:
			var timer = get_tree().create_timer(0.5)
			timer.timeout.connect(_on_submission_delay_complete)
		else:
			push_error("LeaderboardManager: Update failed. Response code: %d" % response_code)
		return
	
	# Handle cleanup check (step 1: check for worst entry)
	if has_meta("is_checking_cleanup"):
		remove_meta("is_checking_cleanup")
		if response_code == 200:
			var json = JSON.new()
			var parse_result = json.parse(response_text)
			if parse_result == OK and json.data is Array:
				var entries = json.data
				
				# Now count total entries for this level
				if has_meta("pending_submission"):
					var pending = get_meta("pending_submission")
					_count_level_entries(pending["level"])
				else:
					push_error("LeaderboardManager: No pending submission during cleanup check!")
					is_submitting = false
			else:
				push_error("LeaderboardManager: Failed to parse cleanup check response")
				is_submitting = false
				remove_meta("pending_submission")
		else:
			_actually_submit_score()
		return
	
	# Handle entry counting (step 2: count total entries)
	if has_meta("is_counting_entries"):
		remove_meta("is_counting_entries")
		if response_code == 200:
			var json = JSON.new()
			var parse_result = json.parse(response_text)
			if parse_result == OK and json.data is Array:
				var entry_count = json.data.size()
				
				if entry_count >= MAX_GLOBAL_PER_LEVEL:
					# Need to delete the worst entry before inserting
					# Get the worst entry again (we need its ID)
					if has_meta("pending_submission"):
						var pending = get_meta("pending_submission")
						var level = pending["level"]
						var check_url = SUPABASE_URL + "/rest/v1/" + SUPABASE_TABLE + "?select=id,time_taken&level=eq.%d&order=time_taken.desc&limit=1" % level
						
						var req_headers = [
							"apikey: " + SUPABASE_API_KEY,
							"Authorization: Bearer " + SUPABASE_API_KEY
						]
						
						set_meta("is_getting_worst_id", true)
						
						var error = http_request.request(check_url, req_headers, HTTPClient.METHOD_GET)
						if error != OK:
							push_error("LeaderboardManager: Failed to get worst entry ID")
							is_submitting = false
							remove_meta("pending_submission")
				else:
					# Less than MAX_GLOBAL_PER_LEVEL entries, just submit directly
					_actually_submit_score()
			else:
				push_error("LeaderboardManager: Failed to parse entry count response")
				_actually_submit_score()  # Proceed anyway
		else:
			_actually_submit_score()
		return
	
	# Handle getting worst entry ID for deletion (step 3: get ID of worst entry)
	if has_meta("is_getting_worst_id"):
		remove_meta("is_getting_worst_id")
		if response_code == 200:
			var json = JSON.new()
			var parse_result = json.parse(response_text)
			if parse_result == OK and json.data is Array and json.data.size() > 0:
				var worst_entry = json.data[0]
				var worst_id = worst_entry.get("id", -1)
				if worst_id > 0:
					_delete_worst_entry(worst_id)
				else:
					_actually_submit_score()
			else:
				_actually_submit_score()
		else:
			_actually_submit_score()
		return
	
	# Handle entry deletion (step 4: delete worst entry)
	if has_meta("is_deleting_entry"):
		remove_meta("is_deleting_entry")
		_actually_submit_score()
		return
	
	# Handle actual score submission (step 5: insert new score)
	if has_meta("is_actually_submitting"):
		remove_meta("is_actually_submitting")
		remove_meta("pending_submission")
		is_submitting = false
		
		if response_code == 200 or response_code == 201:
			# Wait a moment for Supabase to process, then refresh global leaderboard
			var timer = get_tree().create_timer(0.5)
			timer.timeout.connect(_on_submission_delay_complete)
		else:
			push_error("LeaderboardManager: Submission failed. Response code: %d, Error: %s" % [response_code, response_text])
		return
	
	# Handle leaderboard fetching
	if is_fetching:
		is_fetching = false
		if response_code == 200:
			var json = JSON.new()
			var parse_result = json.parse(response_text)
			if parse_result == OK:
				var parsed_data = json.data
				var new_scores: Array[Dictionary] = []
				
				if parsed_data is Array:
					# Supabase returns an array directly
					for item in parsed_data:
						if item is Dictionary:
							var time_value = item.get("time_taken", 0.0)
							# Convert Supabase format to internal format
							var score_entry = {
								"time": float(time_value),  # Time is already in seconds as a number
								"player_name": item.get("player_name", "Player"),
								"date": "",  # Supabase doesn't store date in our schema
								"player_id": "",  # Not stored in Supabase
								"ip_address": ""  # Not stored in Supabase
							}
							new_scores.append(score_entry)
				
				# Only update if we got valid scores
				if new_scores.size() > 0:
					global_leaderboard_data = new_scores
					# Already sorted by Supabase query, but ensure it
					global_leaderboard_data.sort_custom(func(a, b): return a["time"] < b["time"])
					# Emit signal to notify that global leaderboard was updated
					global_leaderboard_updated.emit()
				else:
					pass
			else:
				push_error("LeaderboardManager: Failed to parse Supabase response JSON. Parse error: %d" % parse_result)
		else:
			push_error("LeaderboardManager: Fetch failed. Response code: %d, Error: %s" % [response_code, response_text])

func get_top_scores(count: int = 3, use_global: bool = false) -> Array[Dictionary]:
	"""Get the top N scores. use_global=true for global leaderboard, false for local."""
	var source_data: Array
	if use_global:
		source_data = global_leaderboard_data
	else:
		var level = get_current_level_index()
		source_data = _get_local_data_for_level(level)
	if source_data.is_empty():
		return []
	
	var result: Array[Dictionary] = []
	var num = min(count, source_data.size())
	for i in range(num):
		result.append(source_data[i])
	return result

func get_best_score(use_global: bool = false) -> float:
	"""Get the best (lowest) time. use_global=true for global leaderboard."""
	var source_data: Array
	if use_global:
		source_data = global_leaderboard_data
	else:
		var level = get_current_level_index()
		source_data = _get_local_data_for_level(level)
	if source_data.is_empty():
		return -1.0
	return source_data[0]["time"]

func get_rank_for_time(time_taken: float, use_global: bool = false) -> int:
	"""Get the rank (1-based) for a given time."""
	var source_data: Array
	if use_global:
		source_data = global_leaderboard_data
	else:
		var level = get_current_level_index()
		source_data = _get_local_data_for_level(level)
	for i in range(source_data.size()):
		if abs(source_data[i]["time"] - time_taken) < 0.01:  # Float comparison
			return i + 1
	return -1

func save_local_leaderboard():
	"""Save local leaderboard data to file (per-level structure)."""
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("LeaderboardManager: Failed to save leaderboard to " + SAVE_PATH)
		return
	
	var json_string = JSON.stringify(all_local_leaderboard_data)
	file.store_string(json_string)
	file.close()

func load_local_leaderboard():
	"""Load local leaderboard data from file (per-level structure)."""
	all_local_leaderboard_data.clear()
	
	if not FileAccess.file_exists(SAVE_PATH):
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("LeaderboardManager: Failed to load leaderboard from " + SAVE_PATH)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("LeaderboardManager: Failed to parse leaderboard JSON")
		return
	
	var parsed_data = json.data
	if parsed_data is Dictionary:
		# New per-level format: {"0": [...], "1": [...], ...}
		all_local_leaderboard_data = parsed_data
		# Ensure each level's data is sorted
		for key in all_local_leaderboard_data:
			var level_data = all_local_leaderboard_data[key]
			if level_data is Array:
				level_data.sort_custom(func(a, b): return a["time"] < b["time"])
		var total = 0
		for key in all_local_leaderboard_data:
			if all_local_leaderboard_data[key] is Array:
				total += all_local_leaderboard_data[key].size()
	elif parsed_data is Array:
		# Legacy flat format — migrate to level 0
		var new_scores: Array = []
		for item in parsed_data:
			if item is Dictionary:
				new_scores.append(item)
		new_scores.sort_custom(func(a, b): return a["time"] < b["time"])
		all_local_leaderboard_data["0"] = new_scores
		# Save in new format
		save_local_leaderboard()
	else:
		push_error("LeaderboardManager: Leaderboard data is not a dictionary or array")

func clear_local_leaderboard():
	"""Clear all local leaderboard data (for testing/debugging)."""
	all_local_leaderboard_data.clear()
	save_local_leaderboard()

func _on_submission_delay_complete():
	"""Called after delay to fetch updated leaderboard."""
	fetch_global_leaderboard()

func get_player_id() -> String:
	"""Get the current player ID."""
	return player_id

func get_player_name() -> String:
	"""Get the current player name."""
	return player_name

func get_local_ip() -> String:
	"""Get the local IP address."""
	return local_ip_address

func _format_time_for_supabase(time_seconds: float) -> String:
	"""Convert time in seconds to MM:SS.SS format for Supabase."""
	var total_seconds = int(time_seconds)
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	var centiseconds = int((time_seconds - int(time_seconds)) * 100)
	return "%02d:%02d.%02d" % [minutes, seconds, centiseconds]

func _parse_time_from_supabase(time_string: String) -> float:
	"""Convert MM:SS.SS format from Supabase to seconds (float)."""
	# Expected format: "MM:SS.SS"
	var parts = time_string.split(":")
	if parts.size() != 2:
		push_error("LeaderboardManager: Invalid time format from Supabase: " + time_string)
		return 0.0
	
	var minutes = parts[0].to_int()
	var seconds_parts = parts[1].split(".")
	var seconds = 0
	var centiseconds = 0
	
	if seconds_parts.size() >= 1:
		seconds = seconds_parts[0].to_int()
	if seconds_parts.size() >= 2:
		centiseconds = seconds_parts[1].to_int()
	
	var total_seconds = minutes * 60.0 + seconds + centiseconds / 100.0
	return total_seconds
