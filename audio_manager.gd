extends Node

@export var bgm_volume_db: float = 2.0 ## Background music volume in dB

var music_player: AudioStreamPlayer
var _is_rewinding: bool = false
var _rewind_speed: float = 1.0
var _manual_playback_pos: float = 0.0
var _is_stopped: bool = false # Flag to track if music was explicitly stopped

# Level-specific music support
const DEFAULT_MUSIC_PATH: String = "res://audio/Second Chance.wav"
var _current_music_path: String = DEFAULT_MUSIC_PATH

# Heartbeat system (driven by _process instead of Timer for reliability)
var _heartbeat_player: AudioStreamPlayer
var _heartbeat_active: bool = false
var _heartbeat_elapsed: float = 0.0  # Total seconds since heartbeat started
var _heartbeat_tick_accumulator: float = 0.0  # Accumulates delta to trigger every 1 second
const HEARTBEAT_START_DB: float = 0.0  # Starting volume
const HEARTBEAT_MAX_DB: float = 00.0  # Full volume at end
const HEARTBEAT_RAMP_DURATION: float = 300.0  # Seconds to reach max volume

# Occasional noise system
var _occasional_noise_player: AudioStreamPlayer
var _occasional_noise_timer: Timer
var _occasional_noise_stop_timer: Timer
var _occasional_noise_active: bool = false
const OCCASIONAL_NOISE_DB: float = -5.0
const OCCASIONAL_NOISE_PLAY_DURATION: float = 2.0  # Play for 2 seconds
const OCCASIONAL_NOISE_MIN_INTERVAL: float = 5.0
const OCCASIONAL_NOISE_MAX_INTERVAL: float = 10.0

func _ready() -> void:
	# Ensure music keeps playing even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Create the player simply
	music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusic"
	music_player.bus = "Master"
	music_player.volume_db = bgm_volume_db
	add_child(music_player)
	
	# Create heartbeat player
	_heartbeat_player = AudioStreamPlayer.new()
	_heartbeat_player.name = "HeartbeatPlayer"
	_heartbeat_player.bus = "Master"
	_heartbeat_player.volume_db = HEARTBEAT_START_DB
	add_child(_heartbeat_player)
	
	# Load heartbeat audio
	var heartbeat_stream = load("res://audio/Heartbeat.wav")
	if heartbeat_stream:
		_heartbeat_player.stream = heartbeat_stream
	
	# Create occasional noise player
	_occasional_noise_player = AudioStreamPlayer.new()
	_occasional_noise_player.name = "OccasionalNoisePlayer"
	_occasional_noise_player.bus = "Master"
	_occasional_noise_player.volume_db = OCCASIONAL_NOISE_DB
	add_child(_occasional_noise_player)
	
	# Load occasional noise audio
	var noise_stream = load("res://audio/Occasional noise.wav")
	if noise_stream:
		_occasional_noise_player.stream = noise_stream
	
	# Timer to trigger occasional noise at random intervals
	_occasional_noise_timer = Timer.new()
	_occasional_noise_timer.name = "OccasionalNoiseTimer"
	_occasional_noise_timer.one_shot = true
	_occasional_noise_timer.timeout.connect(_on_occasional_noise_trigger)
	add_child(_occasional_noise_timer)
	
	# Timer to stop the noise after 2 seconds of playing
	_occasional_noise_stop_timer = Timer.new()
	_occasional_noise_stop_timer.name = "OccasionalNoiseStopTimer"
	_occasional_noise_stop_timer.wait_time = OCCASIONAL_NOISE_PLAY_DURATION
	_occasional_noise_stop_timer.one_shot = true
	_occasional_noise_stop_timer.timeout.connect(_on_occasional_noise_stop)
	add_child(_occasional_noise_stop_timer)
	
	# If heartbeat/noise were requested before _ready (e.g. from level_manager._enter_tree),
	# the players didn't exist yet. Now they do, so set initial volume.
	if _heartbeat_active and _heartbeat_player:
		_heartbeat_player.volume_db = HEARTBEAT_START_DB
	
	if _occasional_noise_active:
		_schedule_next_occasional_noise()
	
	# Start music playback
	_setup_and_play.call_deferred()

func _process(delta: float) -> void:
	if _is_rewinding and music_player and music_player.playing:
		# delta is already scaled by Engine.time_scale in Godot 4
		_manual_playback_pos -= delta * _rewind_speed
		
		if _manual_playback_pos < 0:
			# If it's a loop, we might want to wrap around, but for now just stay at 0
			_manual_playback_pos = 0
			
		music_player.seek(_manual_playback_pos)
	
	# Heartbeat system - tick every 1 second
	if _heartbeat_active and _heartbeat_player and _heartbeat_player.stream:
		_heartbeat_tick_accumulator += delta
		if _heartbeat_tick_accumulator >= 1.0:
			_heartbeat_tick_accumulator -= 1.0
			_heartbeat_elapsed += 1.0
			
			# Calculate volume: linear interpolation from START to MAX over RAMP_DURATION
			var progress = clampf(_heartbeat_elapsed / HEARTBEAT_RAMP_DURATION, 0.0, 1.0)
			var current_db = lerpf(HEARTBEAT_START_DB, HEARTBEAT_MAX_DB, progress)
			_heartbeat_player.volume_db = current_db
			
			# Play the heartbeat sound
			_heartbeat_player.play()

func start_rewind(speed_multiplier: float = 1.0):
	if music_player and music_player.playing:
		_is_rewinding = true
		_rewind_speed = speed_multiplier
		_manual_playback_pos = music_player.get_playback_position()
		# Slightly increase pitch for a "rewind" feel if desired, 
		# but manual seeking already sounds like a rewind.
		# music_player.pitch_scale = 1.1 

func stop_rewind():
	if _is_rewinding:
		_is_rewinding = false
		# music_player.pitch_scale = 1.0
		# When stopping, we just let it play from where it is

func _setup_and_play():
	# Wait for the engine to be fully stable
	await get_tree().create_timer(1.0).timeout
	
	if _is_stopped:
		return
	
	# If gameplay already started music (e.g. via restart_music in Player._ready),
	# don't replay from 0 here.
	if music_player and (music_player.playing or music_player.stream_paused):
		return
	
	var stream = load(_current_music_path)
	
	if stream:
		music_player.stream = stream
		
		# CRITICAL: Wait 2 frames for Godot to register the large WAV resource
		await get_tree().process_frame
		await get_tree().process_frame
		
		if _is_stopped:
			return
		
		music_player.play()
		
		if music_player.playing:
			pass
		else:
			# Final attempt: try playing on a fresh player
			_retry_play(stream)

func _retry_play(stream):
	if _is_stopped:
		return
		
	var new_player = AudioStreamPlayer.new()
	new_player.bus = "Master"
	new_player.volume_db = bgm_volume_db
	add_child(new_player)
	new_player.stream = stream
	await get_tree().process_frame
	
	if _is_stopped:
		new_player.queue_free()
		return
		
	new_player.play()
	if new_player.playing:
		music_player.queue_free()
		music_player = new_player

func stop_music():
	_is_stopped = true
	if music_player:
		music_player.stop()
	# Also stop heartbeat and occasional noise when music stops
	stop_heartbeat()
	stop_occasional_noise()

func pause_music():
	if music_player:
		music_player.stream_paused = true

func resume_music():
	if music_player:
		music_player.stream_paused = false

func fade_music(target_db: float, duration: float):
	if music_player:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", target_db, duration)

func play_music(new_stream: AudioStream):
	_is_stopped = false
	if music_player:
		music_player.stop()
		music_player.stream = new_stream
		music_player.play()

func restart_music() -> void:
	"""Restart the music from the beginning (used for game restart)."""
	_is_stopped = false
	if music_player:
		# Stop any rewinding
		if _is_rewinding:
			stop_rewind()
			
		# Check if the music stream needs to change (level-specific music)
		var expected_stream = load(_current_music_path)
		if expected_stream and music_player.stream != expected_stream:
			music_player.stream = expected_stream
			
		# Reset pitch and other properties
		music_player.pitch_scale = 1.0
		music_player.stream_paused = false
		
		# Stop first to ensure clean state
		music_player.stop()
		# Play from start
		music_player.play(0.0)

# ---- Level-Specific Music ----

func set_level_music(music_path: String) -> void:
	"""Set the music track for the current level. Call before restart_music()."""
	_current_music_path = music_path

func reset_to_default_music() -> void:
	"""Reset music back to the default track."""
	_current_music_path = DEFAULT_MUSIC_PATH

# ---- Heartbeat System ----

func start_heartbeat() -> void:
	"""Start the heartbeat system - plays heartbeat every second with increasing volume."""
	_heartbeat_active = true
	_heartbeat_elapsed = 0.0
	_heartbeat_tick_accumulator = 0.0
	if _heartbeat_player:
		_heartbeat_player.volume_db = HEARTBEAT_START_DB

func stop_heartbeat() -> void:
	"""Stop the heartbeat system."""
	_heartbeat_active = false
	_heartbeat_tick_accumulator = 0.0
	if _heartbeat_player:
		_heartbeat_player.stop()
	_heartbeat_elapsed = 0.0

# ---- Occasional Noise System ----

func start_occasional_noise() -> void:
	"""Start the occasional noise system - plays noise for 2s every 5-10s."""
	_occasional_noise_active = true
	_schedule_next_occasional_noise()

func stop_occasional_noise() -> void:
	"""Stop the occasional noise system."""
	_occasional_noise_active = false
	if _occasional_noise_timer:
		_occasional_noise_timer.stop()
	if _occasional_noise_stop_timer:
		_occasional_noise_stop_timer.stop()
	if _occasional_noise_player:
		_occasional_noise_player.stop()

func _schedule_next_occasional_noise() -> void:
	"""Schedule the next occasional noise trigger at a random interval."""
	if not _occasional_noise_active or not _occasional_noise_timer:
		return
	var delay = randf_range(OCCASIONAL_NOISE_MIN_INTERVAL, OCCASIONAL_NOISE_MAX_INTERVAL)
	_occasional_noise_timer.wait_time = delay
	_occasional_noise_timer.start()

func _on_occasional_noise_trigger() -> void:
	"""Called when it's time to play the occasional noise."""
	if not _occasional_noise_active or not _occasional_noise_player:
		return
	
	# Play the noise
	_occasional_noise_player.play()
	
	# Start the stop timer to cut it off after 2 seconds
	if _occasional_noise_stop_timer:
		_occasional_noise_stop_timer.start()

func _on_occasional_noise_stop() -> void:
	"""Called after 2 seconds to stop the noise and schedule the next one."""
	if _occasional_noise_player:
		_occasional_noise_player.stop()
	
	# Schedule the next occurrence
	_schedule_next_occasional_noise()
