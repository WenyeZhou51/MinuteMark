extends CanvasLayer

# Level data is built from level block node metadata in the scene.
@export_group("Level Configuration")
@export var levels: Array[Dictionary] = []

const SAVE_FILE_PATH = "user://level_progress.cfg"
const PROGRESS_RESET_MARKER_PATH = "user://level_progress_reset_v1.marker"

@export_group("Lock Overlay")
@export var locked_overlay_node_name: NodePath = NodePath("LockedOverlay")  # Child of each level block; only visible when locked (add in scene or leave name to auto-create)
@export var sync_overlay_shape_from_paper: bool = false  # False by default so LockOverlay can be edited manually in the scene.
@export var lock_overlay_color: Color = Color(0.72, 0.72, 0.76, 0.36)
@export var lock_overlay_z_index: int = 4
@export var lock_icon_z_index: int = 5
@export var lock_icon_texture: Texture2D = preload("res://Sprites/lock.png")
@export var lock_icon_half_size: float = 28.0  # Half of icon size (center ± this = 56×56)
@export var use_scene_lock_icon_transform: bool = true  # If true, LockIcon Sprite2D position/scale from scene are preserved.
@export var lock_overlay_outset: float = 4.0  # Expand overlay slightly outside paper shape.

var level_blocks: Array[Control] = []
var hovered_block_index: int = -1
var block_original_scales: Array[Vector2] = []
var block_original_colors: Array[Color] = []
var level_unlocked_states: Array[bool] = []
# Keyboard navigation index; also kept in sync with mouse hover when not using keyboard priority.
var keyboard_focus_index: int = 0
var last_effective_highlight: int = -1
# When true (after arrow keys), highlight follows keyboard even if the cursor sits on another block.
var _using_keyboard_nav: bool = false

func _ready():
	# Stop background music, heartbeat, and occasional noise
	if AudioManager:
		if AudioManager.has_method("stop_music"):
			AudioManager.stop_music()
		if AudioManager.has_method("stop_heartbeat"):
			AudioManager.stop_heartbeat()
		if AudioManager.has_method("stop_occasional_noise"):
			AudioManager.stop_occasional_noise()
		if AudioManager.has_method("reset_to_default_music"):
			AudioManager.reset_to_default_music()
	
	# Build level blocks + defaults from scene nodes
	setup_level_blocks()
	# One-time cleanup: reset old progress once, then allow normal progression saves.
	var state_changed := _run_one_time_progress_reset()
	if not state_changed:
		load_level_progress()
	# Ensure progression always starts with level 1 available.
	if levels.size() > 0 and not _is_level_unlocked(0):
		_set_level_unlocked(0, true)
		state_changed = true
	# Keep progression contiguous (no later level unlocked while an earlier one is locked).
	if _enforce_sequential_unlocks():
		state_changed = true
	if state_changed:
		save_level_progress()
	# Apply loaded/default state to visuals
	_apply_level_states_to_blocks()
	_cache_block_original_colors()
	if level_blocks.size() > 0:
		keyboard_focus_index = clampi(keyboard_focus_index, 0, level_blocks.size() - 1)
	# After layout, ensure overlay/icon fill each block and locked state is applied (fixes Level 5 and position mismatch)
	call_deferred("_refresh_lock_overlays")
	
	# Setup audio
	setup_audio_players()
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func clear_saved_level_progress():
	"""Delete stored level progress so stale unlock data cannot leak into this run."""
	var absolute_path := ProjectSettings.globalize_path(SAVE_FILE_PATH)
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var err := DirAccess.remove_absolute(absolute_path)
		if err != OK:
			push_warning("LevelSelectMenu: Could not remove old save file: " + str(err))

func _run_one_time_progress_reset() -> bool:
	"""Reset progress only once so later level completions can unlock new levels."""
	if FileAccess.file_exists(PROGRESS_RESET_MARKER_PATH):
		return false
	clear_saved_level_progress()
	_reset_to_first_level_only()
	var marker_file := FileAccess.open(PROGRESS_RESET_MARKER_PATH, FileAccess.WRITE)
	if marker_file:
		marker_file.store_string("reset_applied=1\n")
	else:
		push_warning("LevelSelectMenu: Could not create reset marker file.")
	return true

func _reset_to_first_level_only():
	"""Lock every level except the first one."""
	for i in range(levels.size()):
		_set_level_unlocked(i, i == 0)
	keyboard_focus_index = 0

func setup_level_blocks():
	"""Find level blocks from scene nodes and build level data from node metadata."""
	level_blocks.clear()
	block_original_scales.clear()
	block_original_colors.clear()
	var container = get_node_or_null("MenuContainer/LevelsContainer")
	if not container:
		push_error("LevelSelectMenu: Could not find LevelsContainer")
		return

	var indexed_blocks: Array[Dictionary] = []
	for child in container.get_children():
		if child is Control:
			var child_name := str(child.name)
			if child_name.begins_with("Level") and child_name.ends_with("Block"):
				var level_num := _parse_level_number_from_block_name(child_name)
				indexed_blocks.append({"num": level_num, "block": child})

	indexed_blocks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("num", 0)) < int(b.get("num", 0))
	)

	for item in indexed_blocks:
		var block: Control = item.get("block")
		level_blocks.append(block)
		block.mouse_filter = Control.MOUSE_FILTER_STOP
		block_original_scales.append(block.scale)
		_add_lock_overlay_and_icon(block)

	levels = _build_level_data_from_blocks()
	_initialize_unlock_states_from_levels()

func _initialize_unlock_states_from_levels():
	level_unlocked_states.clear()
	for i in range(levels.size()):
		level_unlocked_states.append(bool(levels[i].get("unlocked", false)))

func _parse_level_number_from_block_name(block_name: String) -> int:
	var middle := block_name.trim_prefix("Level").trim_suffix("Block")
	if middle.is_valid_int():
		return int(middle)
	return 9999

func _build_level_data_from_blocks() -> Array[Dictionary]:
	var built_levels: Array[Dictionary] = []
	for i in range(level_blocks.size()):
		var block: Control = level_blocks[i]
		var label = block.get_node_or_null("LevelLabel")
		var level_name := "Level %d" % (i + 1)
		if label is Label and not (label as Label).text.strip_edges().is_empty():
			level_name = (label as Label).text.strip_edges()
		var scene_path := str(block.get_meta("scene_path", ""))
		var unlocked_default := bool(block.get_meta("default_unlocked", false))
		built_levels.append({
			"name": level_name,
			"scene_path": scene_path,
			"unlocked": unlocked_default
		})
	return built_levels

func _apply_level_states_to_blocks():
	for i in range(min(level_blocks.size(), levels.size())):
		update_level_block(level_blocks[i], i)

func _cache_block_original_colors():
	block_original_colors.clear()
	for i in range(level_blocks.size()):
		var polygon = level_blocks[i].get_node_or_null("PaperScrap")
		if polygon:
			block_original_colors.append(polygon.color)
		else:
			block_original_colors.append(Color.WHITE)

func _is_level_unlocked(level_index: int) -> bool:
	if level_index < 0 or level_index >= level_unlocked_states.size():
		return false
	return level_unlocked_states[level_index]

func _set_level_unlocked(level_index: int, unlocked: bool):
	if level_index < 0 or level_index >= level_unlocked_states.size():
		return
	level_unlocked_states[level_index] = unlocked
	if level_index >= 0 and level_index < levels.size():
		var level_data: Dictionary = levels[level_index]
		level_data["unlocked"] = unlocked
		levels[level_index] = level_data

func _enforce_sequential_unlocks() -> bool:
	"""Normalize unlock state so progression is contiguous from the first locked level onward."""
	var changed := false
	for i in range(1, level_unlocked_states.size()):
		if not level_unlocked_states[i - 1] and level_unlocked_states[i]:
			_set_level_unlocked(i, false)
			changed = true
	return changed

func _add_lock_overlay_and_icon(block: Control):
	"""Use or create the 'locked overlay' container under the block (visible only when locked). If empty, add default overlay + icon; else use whatever you put in the scene."""
	var container = block.get_node_or_null(locked_overlay_node_name)
	if container == null:
		container = Node2D.new()
		container.name = str(locked_overlay_node_name)
		block.add_child(container)
	container.visible = false

	var paper = block.get_node_or_null("PaperScrap")
	if paper == null or not (paper is Polygon2D):
		return
	var poly: Polygon2D = paper as Polygon2D
	# Add overlay shape only when container has no Polygon2D child (so you can edit shape in scene)
	if container.get_node_or_null("LockOverlay") == null:
		var overlay = Polygon2D.new()
		overlay.name = "LockOverlay"
		overlay.z_as_relative = false
		overlay.z_index = lock_overlay_z_index
		overlay.polygon = _safe_overlay_polygon(poly.polygon)
		overlay.position = poly.position
		overlay.scale = poly.scale
		overlay.color = lock_overlay_color
		container.add_child(overlay)
	# Add lock icon when missing (so scene can have shape-only and we add icon at runtime)
	if container.get_node_or_null("LockIcon") == null:
		var icon = Sprite2D.new()
		icon.name = "LockIcon"
		icon.z_as_relative = false
		icon.z_index = lock_icon_z_index
		icon.centered = true
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.texture = lock_icon_texture
		icon.set_meta("auto_created", true)
		container.add_child(icon)

func _get_paper_centroid_in_block(block: Control) -> Vector2:
	"""Center of the PaperScrap polygon in block local space (for lock icon)."""
	var paper = block.get_node_or_null("PaperScrap")
	if not paper is Polygon2D:
		return Vector2(block.offset_right - block.offset_left, block.offset_bottom - block.offset_top) * 0.5
	var poly: Polygon2D = paper as Polygon2D
	var pts = poly.polygon
	if pts.size() == 0:
		return poly.position
	var sum := Vector2.ZERO
	for p in pts:
		sum += p
	var local_center: Vector2 = sum / float(pts.size())
	return poly.position + local_center * poly.scale

func _refresh_lock_overlays():
	"""Called deferred: keep overlay same shape as PaperScrap, position lock icon at paper center."""
	for i in range(level_blocks.size()):
		if i >= levels.size():
			break
		var block = level_blocks[i]
		var container = block.get_node_or_null(locked_overlay_node_name)
		if container == null:
			update_level_block(block, i)
			continue
		var paper = block.get_node_or_null("PaperScrap")
		var overlay = container.get_node_or_null("LockOverlay")
		var lock_icon = container.get_node_or_null("LockIcon")
		if paper is Polygon2D and overlay is Polygon2D:
			var poly: Polygon2D = paper as Polygon2D
			var over: Polygon2D = overlay as Polygon2D
			if sync_overlay_shape_from_paper:
				over.polygon = _safe_overlay_polygon(poly.polygon)
				over.position = poly.position
				over.scale = poly.scale
			over.z_as_relative = false
			over.color = lock_overlay_color
			over.z_index = lock_overlay_z_index
		var center := _get_paper_centroid_in_block(block)
		if lock_icon:
			lock_icon.z_as_relative = false
			lock_icon.z_index = lock_icon_z_index
			_position_and_scale_lock_icon(lock_icon, center)
		update_level_block(block, i)

func update_level_block(block: Control, level_index: int):
	"""Update block appearance based on unlock status"""
	if level_index >= levels.size():
		return
		
	var is_unlocked = _is_level_unlocked(level_index)
	
	# Show or hide the locked overlay container (only visible when locked)
	var container = block.get_node_or_null(locked_overlay_node_name)
	if container:
		# Keep container alive and explicitly toggle children so state cannot drift.
		container.visible = true
		var lock_overlay = container.get_node_or_null("LockOverlay")
		var lock_icon = container.get_node_or_null("LockIcon")
		if lock_overlay:
			lock_overlay.visible = not is_unlocked
			if lock_overlay is Polygon2D:
				var over: Polygon2D = lock_overlay as Polygon2D
				var paper = block.get_node_or_null("PaperScrap")
				if sync_overlay_shape_from_paper and paper is Polygon2D:
					var poly: Polygon2D = paper as Polygon2D
					over.polygon = _safe_overlay_polygon(poly.polygon)
					over.position = poly.position
					over.scale = poly.scale
				over.z_as_relative = false
				over.z_index = lock_overlay_z_index
				over.color = lock_overlay_color
		if lock_icon:
			lock_icon.visible = not is_unlocked
			lock_icon.z_as_relative = false
			lock_icon.z_index = lock_icon_z_index
			_position_and_scale_lock_icon(lock_icon, _get_paper_centroid_in_block(block))
	
	# Label text is taken from the scene (.tscn); we only update label colors for locked/unlocked.
	var label = block.get_node_or_null("LevelLabel")
	if not is_unlocked:
		if label:
			# High contrast white text on locked blocks.
			label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
			label.add_theme_color_override("font_outline_color", Color(0.2, 0.2, 0.2, 1))
			label.modulate = Color(0.7, 0.7, 0.7, 1)
	else:
		if label:
			# High contrast black text on unlocked blocks.
			label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
			label.add_theme_color_override("font_outline_color", Color(0.95, 0.95, 0.95, 1))
			label.modulate = Color(1, 1, 1, 1)

func _safe_overlay_polygon(points: PackedVector2Array) -> PackedVector2Array:
	"""Return a polygon guaranteed to render; fallback to convex hull for problematic shapes."""
	if points.size() < 3:
		return points
	var hull := Geometry2D.convex_hull(points)
	var base := points
	if hull.size() >= 3:
		base = hull
	return _expand_polygon_from_centroid(base, lock_overlay_outset)

func _expand_polygon_from_centroid(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	if amount <= 0.0 or points.size() < 3:
		return points
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= float(points.size())

	var expanded := PackedVector2Array()
	for p in points:
		var dir := p - center
		var len := dir.length()
		if len > 0.0001:
			expanded.append(p + (dir / len) * amount)
		else:
			expanded.append(p)
	return expanded

func _position_and_scale_lock_icon(lock_icon: Node, center: Vector2):
	if lock_icon is Sprite2D:
		var icon: Sprite2D = lock_icon as Sprite2D
		if icon.texture != lock_icon_texture:
			icon.texture = lock_icon_texture
		var auto_created := bool(icon.get_meta("auto_created", false))
		if use_scene_lock_icon_transform and not auto_created:
			return
		icon.position = center
		var tex_size := icon.texture.get_size() if icon.texture else Vector2.ZERO
		if tex_size.x > 0.0 and tex_size.y > 0.0 and lock_icon_half_size > 0.0:
			var target_full := lock_icon_half_size * 2.0
			icon.scale = Vector2(target_full / tex_size.x, target_full / tex_size.y)
		else:
			icon.scale = Vector2.ONE
	elif lock_icon is Control:
		# Backward compatibility with old Label-based icons.
		var c: Control = lock_icon as Control
		var hs: float = lock_icon_half_size
		c.offset_left = center.x - hs
		c.offset_top = center.y - hs
		c.offset_right = center.x + hs
		c.offset_bottom = center.y + hs

func _input(event):
	"""Handle input for level blocks"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
			return
		if not event.echo and level_blocks.size() > 0:
			var n = level_blocks.size()
			if event.keycode in [KEY_LEFT, KEY_A]:
				_using_keyboard_nav = true
				keyboard_focus_index = (keyboard_focus_index - 1 + n) % n
			elif event.keycode in [KEY_RIGHT, KEY_D]:
				_using_keyboard_nav = true
				keyboard_focus_index = (keyboard_focus_index + 1) % n
			elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_using_keyboard_nav = true
				_on_level_block_clicked(keyboard_focus_index)

	if event is InputEventMouseMotion:
		_using_keyboard_nav = false

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_using_keyboard_nav = false
		var idx := _get_block_index_at_global_pos(event.position)
		if idx >= 0:
			_on_level_block_clicked(idx)
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()


func _get_block_index_at_global_pos(global_point: Vector2) -> int:
	for i in range(level_blocks.size()):
		if _is_point_in_block(global_point, level_blocks[i]):
			return i
	return -1

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
	"""Handle level block click / Enter key. Locked levels can be focused but not entered."""
	if level_index >= levels.size():
		return
		
	var level_data = levels[level_index]
	
	# Locked: allow hover/focus with keyboard but do not open level on Enter
	if not _is_level_unlocked(level_index):
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
		
	_set_level_unlocked(level_index, true)
	save_level_progress()
	
	# Update block appearance
	if level_index < level_blocks.size():
		update_level_block(level_blocks[level_index], level_index)

func save_level_progress():
	"""Save level unlock status to file"""
	var config = ConfigFile.new()
	
	for i in range(levels.size()):
		var key = "level_%d_unlocked" % (i + 1)
		config.set_value("progress", key, _is_level_unlocked(i))
	
	var error = config.save(SAVE_FILE_PATH)
	if error != OK:
		push_error("LevelSelectMenu: Failed to save progress: " + str(error))
	else:
		pass

func load_level_progress():
	"""Load level unlock status from file"""
	var config = ConfigFile.new()
	var error = config.load(SAVE_FILE_PATH)
	
	if error != OK:
		# No save file: keep scene node defaults.
		return
	
	# Load saved progress only for keys that exist.
	for i in range(levels.size()):
		var key = "level_%d_unlocked" % (i + 1)
		var has_key := config.has_section_key("progress", key)
		var loaded_value := bool(config.get_value("progress", key, false))
		if has_key:
			_set_level_unlocked(i, loaded_value)

	# Temporary design lock: keep levels 3, 4, 5 locked regardless of save file state.
	for i in range(2, levels.size()):
		levels[i]["unlocked"] = false
	

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
	if ResourceLoader.exists("res://audio/Menu transition.ogg"):
		menu_transition_player.stream = load("res://audio/Menu transition.ogg")
	elif ResourceLoader.exists("res://audio/menu_transition.ogg"):
		menu_transition_player.stream = load("res://audio/menu_transition.ogg")
	
	if ResourceLoader.exists("res://audio/menu select.ogg"):
		menu_select_player.stream = load("res://audio/menu select.ogg")
	elif ResourceLoader.exists("res://audio/menu_select.ogg"):
		menu_select_player.stream = load("res://audio/menu_select.ogg")

func _process(_delta):
	"""Highlight from mouse hover, or keyboard when arrow keys have priority over the cursor."""
	var mouse_pos := get_viewport().get_mouse_position()
	var mouse_hover_idx := _get_block_index_at_global_pos(mouse_pos)

	if not _using_keyboard_nav and mouse_hover_idx >= 0:
		keyboard_focus_index = mouse_hover_idx

	var effective_highlight: int
	if _using_keyboard_nav:
		effective_highlight = keyboard_focus_index
	else:
		effective_highlight = mouse_hover_idx if mouse_hover_idx >= 0 else keyboard_focus_index

	if effective_highlight >= level_blocks.size():
		effective_highlight = 0

	# Apply/remove hover so exactly one block is highlighted
	if effective_highlight != last_effective_highlight:
		if last_effective_highlight >= 0 and last_effective_highlight < level_blocks.size():
			_apply_hover_effect(last_effective_highlight, false)
		if effective_highlight >= 0 and effective_highlight < level_blocks.size():
			_apply_hover_effect(effective_highlight, true)
			# Play sound when highlight changes (not on initial focus)
			if last_effective_highlight >= 0:
				play_menu_select_sound()
		last_effective_highlight = effective_highlight
	
	hovered_block_index = effective_highlight

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
		var target_scale = block_original_scales[block_index] * 1.05
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
