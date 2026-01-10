extends Node

var music_player: AudioStreamPlayer

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
			print("[AudioManager] SUCCESS: 'Second Chance' is playing.")
		else:
			# Final attempt: try playing on a fresh player
			print("[AudioManager] First attempt failed. Retrying with fresh player...")
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
		print("[AudioManager] SUCCESS: Music playing on secondary player.")

func stop_music():
	if music_player:
		music_player.stop()

func play_music(new_stream: AudioStream):
	if music_player:
		music_player.stop()
		music_player.stream = new_stream
		music_player.play()
