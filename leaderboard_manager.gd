# leaderboard_manager.gd
extends Node

# Signals
signal global_leaderboard_updated

# Leaderboard data structure: Array of dictionaries with "time", "date", "player_id", "player_name", "ip_address" keys
# Lower times are better (faster completion)
var local_leaderboard_data: Array[Dictionary] = []
var global_leaderboard_data: Array[Dictionary] = []

const MAX_ENTRIES: int = 100  # Keep top 100 scores locally
const SAVE_PATH: String = "user://leaderboard.json"
const PLAYER_ID_PATH: String = "user://player_id.txt"
const PLAYER_NAME_PATH: String = "user://player_name.txt"

# Player identification
var player_id: String = ""
var player_name: String = "Player"
var local_ip_address: String = ""

# API Configuration (set these to your backend server)
# For local testing: "http://localhost:3000/api"
# For local network: "http://YOUR_IP_ADDRESS:3000/api"
# For cloud deployment: "https://your-api-server.com/api"
var api_base_url: String = "http://localhost:3000/api"  # Change this to your actual API endpoint
var api_enabled: bool = true  # Set to true when you have a backend server running
var api_submit_endpoint: String = "/leaderboard/submit"
var api_fetch_endpoint: String = "/leaderboard/top"

# HTTP request tracking
var http_request: HTTPRequest
var is_submitting: bool = false
var is_fetching: bool = false

func _ready():
	load_player_id()
	load_player_name()
	get_local_ip_address()
	load_local_leaderboard()
	
	# Setup HTTP request node
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)
	
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
			print("LeaderboardManager: Local IP address: " + local_ip_address)
			return
	
	# Fallback: use a generated identifier if we can't get IP
	if local_ip_address.is_empty():
		local_ip_address = "unknown_" + player_id.substr(0, 8)
		print("LeaderboardManager: Could not determine IP, using fallback: " + local_ip_address)

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
	
	print("LeaderboardManager: Player ID: " + player_id)

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
			player_name = file.get_as_text().strip_edges()
			file.close()
			if player_name.is_empty():
				player_name = "Player"
	
	print("LeaderboardManager: Player name: " + player_name)

func set_player_name(name: String):
	"""Set and save player name."""
	player_name = name
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

func add_score(time_taken: float) -> bool:
	"""Add a new score to the leaderboard. Returns true if it's a new best score."""
	var new_entry = {
		"time": time_taken,
		"date": Time.get_datetime_string_from_system(),
		"player_id": player_id,
		"player_name": player_name,
		"ip_address": local_ip_address
	}
	
	var is_new_best = false
	if local_leaderboard_data.is_empty() or time_taken < local_leaderboard_data[0]["time"]:
		is_new_best = true
	
	# Add to local leaderboard
	local_leaderboard_data.append(new_entry)
	
	# Sort by time (ascending - lower is better)
	local_leaderboard_data.sort_custom(func(a, b): return a["time"] < b["time"])
	
	# Keep only top MAX_ENTRIES
	if local_leaderboard_data.size() > MAX_ENTRIES:
		local_leaderboard_data = local_leaderboard_data.slice(0, MAX_ENTRIES)
	
	save_local_leaderboard()
	
	# Submit to global leaderboard if API is enabled
	if api_enabled:
		submit_score_to_api(new_entry)
	
	return is_new_best

func submit_score_to_api(score_data: Dictionary):
	"""Submit a score to the global leaderboard API."""
	if is_submitting:
		print("LeaderboardManager: Already submitting a score, skipping...")
		return
	
	if api_base_url == "https://your-api-server.com/api":
		print("LeaderboardManager: API URL not configured, skipping submission")
		return
	
	is_submitting = true
	var url = api_base_url + api_submit_endpoint
	
	# Prepare JSON payload
	var json_payload = JSON.stringify(score_data)
	var headers = ["Content-Type: application/json"]
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_payload)
	if error != OK:
		push_error("LeaderboardManager: Failed to submit score to API: " + str(error))
		is_submitting = false

func fetch_global_leaderboard():
	"""Fetch the global leaderboard from the API."""
	if is_fetching:
		print("LeaderboardManager: Already fetching leaderboard, skipping...")
		return
	
	if api_base_url == "https://your-api-server.com/api":
		print("LeaderboardManager: API URL not configured, skipping fetch")
		return
	
	is_fetching = true
	var url = api_base_url + api_fetch_endpoint + "?limit=100"
	
	var error = http_request.request(url, [], HTTPClient.METHOD_GET)
	if error != OK:
		push_error("LeaderboardManager: Failed to fetch global leaderboard: " + str(error))
		is_fetching = false

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	"""Handle HTTP request completion."""
	if is_submitting:
		is_submitting = false
		if response_code == 200 or response_code == 201:
			print("LeaderboardManager: Score submitted successfully")
			# Wait a moment for server to process, then refresh global leaderboard
			# Create a one-shot timer to fetch after delay
			var timer = get_tree().create_timer(0.8)
			timer.timeout.connect(_on_submission_delay_complete)
		else:
			push_error("LeaderboardManager: Failed to submit score. Response code: " + str(response_code))
	
	if is_fetching:
		is_fetching = false
		if response_code == 200:
			var json = JSON.new()
			var parse_result = json.parse(body.get_string_from_utf8())
			if parse_result == OK:
				var parsed_data = json.data
				var new_scores: Array[Dictionary] = []
				
				if parsed_data is Array:
					# Convert to Array[Dictionary] by ensuring each element is a Dictionary
					for item in parsed_data:
						if item is Dictionary:
							new_scores.append(item)
				elif parsed_data is Dictionary and parsed_data.has("scores"):
					# Handle API response with wrapper object
					var scores_array = parsed_data["scores"]
					if scores_array is Array:
						for item in scores_array:
							if item is Dictionary:
								new_scores.append(item)
				
				# Only update if we got valid scores
				if new_scores.size() > 0:
					global_leaderboard_data = new_scores
					# Ensure data is sorted
					global_leaderboard_data.sort_custom(func(a, b): return a["time"] < b["time"])
					print("LeaderboardManager: Fetched %d global scores" % global_leaderboard_data.size())
					# Emit signal to notify that global leaderboard was updated
					global_leaderboard_updated.emit()
			else:
				push_error("LeaderboardManager: Failed to parse global leaderboard JSON")
		else:
			push_error("LeaderboardManager: Failed to fetch global leaderboard. Response code: " + str(response_code))

func get_top_scores(count: int = 3, use_global: bool = false) -> Array[Dictionary]:
	"""Get the top N scores. use_global=true for global leaderboard, false for local."""
	var source_data = global_leaderboard_data if use_global else local_leaderboard_data
	if source_data.is_empty():
		return []
	
	var top_scores = source_data.slice(0, min(count, source_data.size()))
	return top_scores

func get_best_score(use_global: bool = false) -> float:
	"""Get the best (lowest) time. use_global=true for global leaderboard."""
	var source_data = global_leaderboard_data if use_global else local_leaderboard_data
	if source_data.is_empty():
		return -1.0
	return source_data[0]["time"]

func get_rank_for_time(time_taken: float, use_global: bool = false) -> int:
	"""Get the rank (1-based) for a given time."""
	var source_data = global_leaderboard_data if use_global else local_leaderboard_data
	for i in range(source_data.size()):
		if abs(source_data[i]["time"] - time_taken) < 0.01:  # Float comparison
			return i + 1
	return -1

func save_local_leaderboard():
	"""Save local leaderboard data to file."""
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("LeaderboardManager: Failed to save leaderboard to " + SAVE_PATH)
		return
	
	var json_string = JSON.stringify(local_leaderboard_data)
	file.store_string(json_string)
	file.close()

func load_local_leaderboard():
	"""Load local leaderboard data from file."""
	local_leaderboard_data.clear()
	
	if not FileAccess.file_exists(SAVE_PATH):
		print("LeaderboardManager: No existing leaderboard file, starting fresh")
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
	if parsed_data is Array:
		# Convert to Array[Dictionary] by ensuring each element is a Dictionary
		var new_scores: Array[Dictionary] = []
		for item in parsed_data:
			if item is Dictionary:
				new_scores.append(item)
		local_leaderboard_data = new_scores
		# Ensure data is sorted
		local_leaderboard_data.sort_custom(func(a, b): return a["time"] < b["time"])
		print("LeaderboardManager: Loaded %d local scores" % local_leaderboard_data.size())
	else:
		push_error("LeaderboardManager: Leaderboard data is not an array")

func clear_local_leaderboard():
	"""Clear all local leaderboard data (for testing/debugging)."""
	local_leaderboard_data.clear()
	save_local_leaderboard()
	print("LeaderboardManager: Local leaderboard cleared")

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
