extends CanvasLayer

@onready var background = $Control/ColorRect
@onready var main_label = $Control/CenterContainer/MainLabel
@onready var sub_label = $Control/VBoxContainer/RestartLabel

const MESSAGES = [
	"WASTED",
	"CRUSHED",
	"SPLAT!",
	"OOPS...",
	"DENIED",
	"WIPEOUT",
	"FATAL",
	"THE END"
]

var input_allowed = false
var reload_triggered = false
var state = 0 # 0: Waiting, 1: Fading, 2: Animation
var fade_timer = 0.0
var fade_duration = 0.3

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Stop or pause music when Death UI opens
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		if audio_manager.has_method("pause_music"):
			audio_manager.pause_music()
		elif audio_manager.has_method("stop_music"):
			audio_manager.stop_music()
	
	# Initial state
	background.color.a = 0.0
	main_label.text = MESSAGES.pick_random()
	main_label.pivot_offset = main_label.size / 2
	main_label.scale = Vector2(5.0, 5.0)
	main_label.modulate.a = 0.0
	main_label.rotation_degrees = randf_range(-20, 20)
	sub_label.modulate.a = 0.0
	
	# Start the sequence using a coroutine that respects real time
	_run_sequence()

func _run_sequence():
	# 1. Let slow-mo shatter play for a bit (0.5s real time)
	# create_timer with ignore_time_scale=true
	await get_tree().create_timer(0.5, true, false, true).timeout
	
	# 2. Start manual fade to black (handled in _process)
	state = 1
	await get_tree().create_timer(fade_duration, true, false, true).timeout
	state = 2 # Fade done
	
	# 3. Reset Time Scale (Now that screen is black, we can snap back to normal speed)
	Engine.time_scale = 1.0
	
	# 4. Start UI Animations (Tween)
	var tween = create_tween()
	
	# Slam text
	tween.set_parallel(true)
	tween.tween_property(main_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(main_label, "modulate:a", 1.0, 0.2)
	tween.tween_property(main_label, "rotation_degrees", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	
	# 5. Trigger Reload (Wait a tiny bit so text is readable before freeze)
	# tween.tween_interval(0.3)
	# tween.tween_callback(func(): _trigger_background_reload())
	
	# 6. Show Restart Prompt (Only after reload starts)
	# We add a delay to ensure the freeze has likely happened
	tween.tween_interval(0.5)
	tween.tween_property(sub_label, "modulate:a", 1.0, 0.5)
	tween.tween_callback(func(): input_allowed = true)
	
	# Blink loop
	var blink_tween = create_tween().set_loops()
	blink_tween.tween_property(sub_label, "modulate:a", 0.2, 0.7)
	blink_tween.tween_property(sub_label, "modulate:a", 1.0, 0.7)

func _process(delta):
	# Manual fade handling to ignore time scale
	if state == 1:
		# Calculate real delta approximation
		var real_delta = delta
		if Engine.time_scale > 0.0:
			real_delta = delta / Engine.time_scale
		else:
			# Fallback if time scale is 0, assume 60fps
			real_delta = 1.0 / 60.0
			
		fade_timer += real_delta
		var progress = clamp(fade_timer / fade_duration, 0.0, 1.0)
		background.color.a = progress

func _trigger_background_reload():
	if reload_triggered:
		return
	reload_triggered = true
	
	# Explicitly reset Time Scale before reload
	Engine.time_scale = 1.0
	
	# Unpause to allow reload to process cleanly
	get_tree().paused = false
	
	# Try to do a soft reset first (much faster than full reload)
	# The current scene root should be the Level node with level_manager.gd script
	var level_manager = get_tree().current_scene
	
	if level_manager and level_manager.has_method("soft_reset_level"):
		# Use fast soft reset instead of slow full scene reload
		print("DeathUI: Using fast soft reset")
		level_manager.soft_reset_level()
		queue_free() # Remove the death UI
	else:
		# Fallback to full reload if soft reset not available
		print("DeathUI: LevelManager not found, falling back to full scene reload")
		get_tree().reload_current_scene()

func _input(event):
	if not input_allowed:
		return
		
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		_trigger_background_reload()

