extends Juicy_effect

@export var audioClip : AudioStream

func Play_Enter():
	if audioClip:
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = audioClip
		audio_player.autoplay = false
		audio_player.bus = "Master"
		get_tree().root.add_child(audio_player)
		audio_player.play()
		audio_player.finished.connect(func(): audio_player.queue_free())
	pass

