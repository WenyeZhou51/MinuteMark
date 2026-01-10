extends Area2D

const PendulumScene = preload("res://pendulum_story.tscn")

var triggered := false
var transition_layer: CanvasLayer
var transition_rect: ColorRect

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Setup transition layer
	transition_layer = CanvasLayer.new()
	transition_layer.layer = 128 # Very high layer to cover everything
	transition_layer.visible = false
	add_child(transition_layer)
	
	transition_rect = ColorRect.new()
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.color = Color.WHITE
	transition_rect.modulate.a = 0.0
	transition_layer.add_child(transition_rect)

func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return
	
	if body.is_in_group("player"):
		triggered = true
		start_transition()

func start_transition():
	# 1. Fade out game (Fade in white rect)
	transition_layer.visible = true
	var tween = create_tween()
	tween.tween_property(transition_rect, "modulate:a", 1.0, 0.5)
	
	# Fade out music
	if AudioManager:
		AudioManager.fade_music(-80.0, 0.5)
	
	await tween.finished
	
	# 2. Pause game and switch context
	get_tree().paused = true
	if AudioManager:
		AudioManager.pause_music()
		# Reset volume for when we resume, but keep paused
		# Actually, we should probably set volume back to normal (0) but paused
		# so resume works instantly? Or fade in on resume.
		# Let's handle resume fade-in later.
	
	# Instantiate pendulum story
	var pendulum_instance = PendulumScene.instantiate()
	pendulum_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.add_child(pendulum_instance)
	get_tree().root.add_child(canvas_layer)
	
	# 3. Fade in pendulum (Fade out white rect)
	# The pendulum scene has a white background, so this should be seamless
	var tween_in = create_tween()
	tween_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # Allow tweening while paused
	tween_in.tween_property(transition_rect, "modulate:a", 0.0, 0.5)
	
	await tween_in.finished
	transition_layer.visible = false
	
	# Connect to finished signal
	pendulum_instance.story_finished.connect(func():
		end_transition(canvas_layer)
	)

func end_transition(pendulum_layer: CanvasLayer):
	# 1. Fade out pendulum (Fade in white rect)
	transition_layer.visible = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(transition_rect, "modulate:a", 1.0, 0.5)
	
	await tween.finished
	
	# 2. Remove pendulum and unpause
	pendulum_layer.queue_free()
	get_tree().paused = false
	
	if AudioManager:
		AudioManager.resume_music()
		AudioManager.fade_music(0.0, 1.0) # Fade back to normal volume
	
	# 3. Fade in game (Fade out white rect)
	var tween_out = create_tween()
	# No need for pause mode here strictly as game is unpaused, but harmless
	tween_out.tween_property(transition_rect, "modulate:a", 0.0, 0.5)
	
	await tween_out.finished
	transition_layer.visible = false
