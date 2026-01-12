extends Node

var music_player: AudioStreamPlayer
var _is_rewinding: bool = false
var _rewind_speed: float = 1.0
var _manual_playback_pos: float = 0.0

func _ready() -> void:
	# Ensure music keeps playing even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Create the player simply
	music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusic"
	music_player.bus = "Master"
	add_child(music_player)
	
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
	
	var music_path = "res://audio/Second Chance.wav"
	var stream = load(music_path)
	
	if stream:
		music_player.stream = stream
		
		# CRITICAL: Wait 2 frames for Godot to register the large WAV resource
		await get_tree().process_frame
		await get_tree().process_frame
		
		music_player.play()
		
		if music_player.playing:
			pass
		else:
			# Final attempt: try playing on a fresh player
			_retry_play(stream)

func _retry_play(stream):
	var new_player = AudioStreamPlayer.new()
	new_player.bus = "Master"
	add_child(new_player)
	new_player.stream = stream
	await get_tree().process_frame
	new_player.play()
	if new_player.playing:
		music_player.queue_free()
		music_player = new_player

func stop_music():
	if music_player:
		music_player.stop()

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
	if music_player:
		music_player.stop()
		music_player.stream = new_stream
		music_player.play()
