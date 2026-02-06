extends CanvasLayer

# Level data structure
@export_group("Level Configuration")
@export var levels: Array[Dictionary] = [
	{"name": "Tutorial", "scene_path": "res://level.tscn", "unlocked": true},
	{"name": "Level 2", "scene_path": "res://level1.tscn", "unlocked": false},
	{"name": "Level 3", "scene_path": "res://level.tscn", "unlocked": false},
	{"name": "Level 4", "scene_path": "res://level1.tscn", "unlocked": false},
	{"name": "Level 5", "scene_path": "res://level.tscn", "unlocked": false}
]

const SAVE_FILE_PATH = "user://level_progress.cfg"

var level_blocks: Array[Control] = []
var hovered_block_index: int = -1
var detected_hover_index: int = -1  # What we detect this frame
var stable_hover_index: int = -1   # What we've detected consistently
var hover_stability_time: float = 0.0
const HOVER_STABILITY_DELAY: float = 0.03  # Time before hover is considered stable (reduced for better responsiveness)
var block_original_scales: Array[Vector2] = []
var block_original_colors: Array[Color] = []

func _ready():
	# Stop background music
	if AudioManager and AudioManager.has_method("stop_music"):
		AudioManager.stop_music()
	
	# Load saved progress
	load_level_progress()
	
	# Setup level blocks
	setup_level_blocks()
	
	# Setup audio
	setup_audio_players()
	
	# Ensure mouse is visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func setup_level_blocks():
	"""Find and setup all level blocks from the scene"""
	level_blocks.clear()
	block_original_scales.clear()
	block_original_colors.clear()
	
	# Find all level blocks (Level1Block, Level2Block, etc.)
	for i in range(levels.size()):
		var block_name = "Level%dBlock" % (i + 1)
		var block = get_node_or_null("MenuContainer/LevelsContainer/" + block_name)
		if block:
			level_blocks.append(block)
			# Make it process input
			block.mouse_filter = Control.MOUSE_FILTER_STOP
			
			# Store original scale for hover effects
			block_original_scales.append(block.scale)
			
			# Update block state based on unlock status (this sets the color)
			update_level_block(block, i)
			
			# Store original color AFTER it's been set by update_level_block
			var polygon = block.get_node_or_null("PaperScrap")
			if polygon:
				block_original_colors.append(polygon.color)
			else:
				block_original_colors.append(Color.WHITE)
		else:
			push_warning("LevelSelectMenu: Could not find block: " + block_name)

func update_level_block(block: Control, level_index: int):
	"""Update block appearance based on unlock status"""
	if level_index >= levels.size():
		return
		
	var level_data = levels[level_index]
	var is_unlocked = level_data.get("unlocked", false)
	
	# Set level name label
	var label = block.get_node_or_null("LevelLabel")
	if label:
		label.text = level_data.get("name", "Level %d" % (level_index + 1))
	
	# Update paper scrap color based on unlock status
	var polygon = block.get_node_or_null("PaperScrap")
	if polygon:
		if not is_unlocked:
			# Darkened paper for locked levels
			polygon.color = Color(0.5, 0.48, 0.45, 0.9)
			if label:
				# High contrast white text on dark paper background
				label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
				label.add_theme_color_override("font_outline_color", Color(0.2, 0.2, 0.2, 1))
				label.modulate = Color(0.7, 0.7, 0.7, 1)
		else:
			# Use paper-like colors with slight variations for unlocked levels
			var colors = [
				Color(0.98, 0.96, 0.92, 0),   # Tutorial - transparent to show background image
				Color(0.95, 0.93, 0.88, 1),   # Level 2 - slightly warmer paper
				Color(0.92, 0.90, 0.85, 1),   # Level 3 - slightly aged paper
				Color(0.96, 0.94, 0.89, 1),   # Level 4 - cream paper
				Color(0.94, 0.92, 0.87, 1)    # Level 5 - warm paper
			]
			if level_index < colors.size():
				polygon.color = colors[level_index]
			if label:
				# High contrast: black text on light paper backgrounds
				label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
				label.add_theme_color_override("font_outline_color", Color(0.95, 0.95, 0.95, 1))
				label.modulate = Color(1, 1, 1, 1)

func _input(event):
	"""Handle input for level blocks"""
	# Handle ESC key to quit game
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
			return
	
	# Handle mouse clicks on level blocks
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_viewport().get_mouse_position()
		
		# Check each level block
		for i in range(level_blocks.size()):
			var block = level_blocks[i]
			if block.visible and _is_point_in_block(mouse_pos, block):
				_on_level_block_clicked(i)
				break

func _is_point_in_block(point: Vector2, block: Control) -> bool:
	"""Check if a point is inside the paper scrap polygon"""
	var polygon = block.get_node_or_null("PaperScrap")
	if not polygon:
		return false
	
	# Get polygon points
	var polygon_points = polygon.polygon
	if polygon_points.size() < 3:
		return false
	
	# Transform point to polygon's local space (accounting for polygon's position and scale)
	var block_transform = block.get_global_transform()
	var polygon_transform = polygon.get_global_transform()
	var local_point = polygon_transform.affine_inverse() * point
	
	# Use ray casting algorithm to check if point is inside polygon
	var inside = false
	var j = polygon_points.size() - 1
	for i in range(polygon_points.size()):
		var pi = polygon_points[i]
		var pj = polygon_points[j]
		if ((pi.y > local_point.y) != (pj.y > local_point.y)) and (local_point.x < (pj.x - pi.x) * (local_point.y - pi.y) / (pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	
	return inside

func _on_level_block_clicked(level_index: int):
	"""Handle level block click"""
	if level_index >= levels.size():
		return
		
	var level_data = levels[level_index]
	
	# Check if unlocked
	if not level_data.get("unlocked", false):
		play_menu_select_sound()
		return
	
	# Play transition sound
	play_menu_transition_sound()
	
	# Load the level scene
	var scene_path = level_data.get("scene_path", "")
	if scene_path != "" and ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("LevelSelectMenu: Scene path not found: " + scene_path)

func unlock_level(level_index: int):
	"""Unlock a level and save progress"""
	if level_index < 0 or level_index >= levels.size():
		return
		
	levels[level_index]["unlocked"] = true
	save_level_progress()
	
	# Update block appearance
	if level_index < level_blocks.size():
		update_level_block(level_blocks[level_index], level_index)

func save_level_progress():
	"""Save level unlock status to file"""
	var config = ConfigFile.new()
	
	for i in range(levels.size()):
		var key = "level_%d_unlocked" % (i + 1)
		config.set_value("progress", key, levels[i].get("unlocked", false))
	
	var error = config.save(SAVE_FILE_PATH)
	if error != OK:
		push_error("LevelSelectMenu: Failed to save progress: " + str(error))
	else:
		print("LevelSelectMenu: Progress saved")

func load_level_progress():
	"""Load level unlock status from file"""
	var config = ConfigFile.new()
	var error = config.load(SAVE_FILE_PATH)
	
	if error != OK:
		# File doesn't exist or error loading - use defaults
		# First level is always unlocked
		levels[0]["unlocked"] = true
		for i in range(1, levels.size()):
			levels[i]["unlocked"] = false
		return
	
	# Load saved progress
	for i in range(levels.size()):
		var key = "level_%d_unlocked" % (i + 1)
		var unlocked = config.get_value("progress", key, i == 0)  # First level defaults to unlocked
		levels[i]["unlocked"] = unlocked
	
	print("LevelSelectMenu: Progress loaded")

# Audio setup
var menu_transition_player: AudioStreamPlayer
var menu_select_player: AudioStreamPlayer

func setup_audio_players():
	"""Create audio players for menu sounds"""
	menu_transition_player = AudioStreamPlayer.new()
	menu_transition_player.name = "MenuTransitionPlayer"
	menu_transition_player.bus = "Master"
	add_child(menu_transition_player)
	
	menu_select_player = AudioStreamPlayer.new()
	menu_select_player.name = "MenuSelectPlayer"
	menu_select_player.bus = "Master"
	add_child(menu_select_player)
	
	# Load audio files
	if ResourceLoader.exists("res://audio/Menu transition.wav"):
		menu_transition_player.stream = load("res://audio/Menu transition.wav")
	elif ResourceLoader.exists("res://audio/menu_transition.wav"):
		menu_transition_player.stream = load("res://audio/menu_transition.wav")
	
	if ResourceLoader.exists("res://audio/menu select.ogg"):
		menu_select_player.stream = load("res://audio/menu select.ogg")
	elif ResourceLoader.exists("res://audio/menu_select.wav"):
		menu_select_player.stream = load("res://audio/menu_select.wav")

func _process(_delta):
	"""Check for mouse hover on level blocks"""
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Detect what block we're hovering over this frame
	var current_hovered = -1
	for i in range(level_blocks.size()):
		var block = level_blocks[i]
		if block.visible and _is_point_in_block(mouse_pos, block):
			current_hovered = i
			break
	
	# Check if the detected hover has changed
	if current_hovered != detected_hover_index:
		# Detection changed - exit previous stable hover immediately if switching blocks
		if detected_hover_index != -1 and detected_hover_index != current_hovered:
			if stable_hover_index == detected_hover_index and stable_hover_index < level_blocks.size():
				_apply_hover_effect(stable_hover_index, false)
				stable_hover_index = -1
		
		detected_hover_index = current_hovered
		
		# If moving off (no hover), exit immediately
		if current_hovered == -1:
			if stable_hover_index != -1 and stable_hover_index < level_blocks.size():
				_apply_hover_effect(stable_hover_index, false)
				stable_hover_index = -1
			hover_stability_time = 0.0
		else:
			# Moving to a new block - reset timer but keep checking
			hover_stability_time = 0.0
	else:
		# Same detection, accumulate stability time
		hover_stability_time += _delta
		
		# Apply hover effects when stable
		if current_hovered != -1 and hover_stability_time >= HOVER_STABILITY_DELAY:
			# Stable hover - apply effects if state changed
			if stable_hover_index != current_hovered:
				# Exit previous hover
				if stable_hover_index != -1 and stable_hover_index < level_blocks.size():
					_apply_hover_effect(stable_hover_index, false)
				
				# Enter new hover
				_apply_hover_effect(current_hovered, true)
				play_menu_select_sound()
				stable_hover_index = current_hovered
	
	hovered_block_index = stable_hover_index

func _apply_hover_effect(block_index: int, is_hovering: bool):
	"""Apply hover effect to a level block"""
	if block_index < 0 or block_index >= level_blocks.size():
		return
	
	var block = level_blocks[block_index]
	if not block:
		return
	
	# Check if already in the desired state to prevent redundant tweens
	var is_already_hovering = block.get_meta("is_hovering", false)
	if is_hovering == is_already_hovering:
		return
	
	# Mark the hover state
	block.set_meta("is_hovering", is_hovering)
	
	# Get the polygon for color changes
	var polygon = block.get_node_or_null("PaperScrap")
	
	if is_hovering:
		# Hover effect: scale up and brighten
		var target_scale = block_original_scales[block_index] * 1.1
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(block, "scale", target_scale, 0.2)
		
		if polygon and block_index < block_original_colors.size():
			var original_color = block_original_colors[block_index]
			var brightened_color = Color(
				min(original_color.r * 1.2, 1.0),
				min(original_color.g * 1.2, 1.0),
				min(original_color.b * 1.2, 1.0),
				original_color.a
			)
			tween.parallel().tween_property(polygon, "color", brightened_color, 0.2)
	else:
		# Reset to original
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(block, "scale", block_original_scales[block_index], 0.2)
		
		if polygon and block_index < block_original_colors.size():
			tween.parallel().tween_property(polygon, "color", block_original_colors[block_index], 0.2)

func play_menu_transition_sound():
	"""Play the menu transition sound effect"""
	if menu_transition_player and menu_transition_player.stream:
		menu_transition_player.play()

func play_menu_select_sound():
	"""Play the menu select sound effect"""
	if menu_select_player and menu_select_player.stream:
		menu_select_player.play()
