extends Area2D

@export var target_system_path: NodePath
@export var one_shot: bool = true
@export var debug_logs: bool = false
@export var show_connection_line: bool = true ## Draw a line to the target system in editor

var player_in_range: bool = false
var has_triggered: bool = false
var _pulse_time: float = 0.0 # For pulsing animation when player is near

@onready var lever_visual: Node2D = $LeverVisual

# Colors
const OFF_HANDLE_COLOR := Color(0.80, 0.25, 0.25, 1.0)
const OFF_KNOB_COLOR := Color(0.90, 0.30, 0.30, 1.0)
const OFF_LIGHT_COLOR := Color(0.80, 0.15, 0.15, 1.0)
const OFF_GLOW_COLOR := Color(0.80, 0.10, 0.10, 0.3)

const ON_HANDLE_COLOR := Color(0.20, 0.75, 0.25, 1.0)
const ON_KNOB_COLOR := Color(0.25, 0.85, 0.30, 1.0)
const ON_LIGHT_COLOR := Color(0.15, 0.85, 0.15, 1.0)
const ON_GLOW_COLOR := Color(0.10, 0.85, 0.10, 0.4)

const PROMPT_COLOR := Color(1.0, 1.0, 1.0, 0.8)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()


func _process(delta: float) -> void:
	# Pulse animation when player is near and lever is not yet triggered
	if player_in_range and not has_triggered:
		_pulse_time += delta
		_update_pulse()
		queue_redraw() # Redraw every frame for shake animation
	
	if not player_in_range:
		return
	if one_shot and has_triggered:
		return
	if Input.is_action_just_pressed("melee_attack"):
		_activate()


func _activate() -> void:
	if one_shot and has_triggered:
		return
	
	var target = get_node_or_null(target_system_path)
	if target and target.has_method("start_motion"):
		target.start_motion()
		has_triggered = true
		_flip_lever()
		queue_redraw()


func _update_pulse() -> void:
	"""Pulse the lever glow when player is nearby to hint interaction."""
	if not lever_visual:
		return
	var glow = lever_visual.get_node_or_null("StatusGlow") as Polygon2D
	if glow and not has_triggered:
		var pulse := 0.2 + 0.25 * (0.5 + 0.5 * sin(_pulse_time * 4.0))
		glow.color = Color(OFF_GLOW_COLOR.r, OFF_GLOW_COLOR.g, OFF_GLOW_COLOR.b, pulse)


func _flip_lever() -> void:
	"""Flip the lever handle down and change colors to ON state."""
	if not lever_visual:
		return
	
	var handle = lever_visual.get_node_or_null("Handle") as Polygon2D
	var knob = lever_visual.get_node_or_null("Knob") as Polygon2D
	var status_light = lever_visual.get_node_or_null("StatusLight") as Polygon2D
	var status_glow = lever_visual.get_node_or_null("StatusGlow") as Polygon2D
	
	# Flip handle downward
	if handle:
		handle.polygon = PackedVector2Array([
			Vector2(-3, 0), Vector2(3, 0), Vector2(5, 38), Vector2(-5, 38)
		])
		handle.color = ON_HANDLE_COLOR
	
	# Move knob to bottom
	if knob:
		knob.polygon = PackedVector2Array([
			Vector2(-6, 38), Vector2(6, 38), Vector2(6, 44), Vector2(-6, 44)
		])
		knob.color = ON_KNOB_COLOR
	
	# Change status light to green
	if status_light:
		status_light.color = ON_LIGHT_COLOR
	if status_glow:
		status_glow.color = ON_GLOW_COLOR


func _draw() -> void:
	# --- "OFF" / "ON" status text indicator ---
	var label_y := 60.0
	if has_triggered:
		_draw_text_label("ON", Vector2(0, label_y), ON_LIGHT_COLOR, 18)
	else:
		_draw_text_label("OFF", Vector2(0, label_y), OFF_LIGHT_COLOR, 18)
	
	# --- Interaction prompt when nearby (red, shaking) ---
	if player_in_range and not has_triggered:
		var prompt_y := -130.0
		var shake_x := randf_range(-4.0, 4.0)
		var shake_y := randf_range(-3.0, 3.0)
		var alpha := 0.7 + 0.3 * sin(_pulse_time * 3.0)
		var prompt_color := Color(0.95, 0.2, 0.2, alpha)
		_draw_text_label("ATTACK", Vector2(shake_x, prompt_y + shake_y), prompt_color, 20)
	
	# --- Connection line to target system ---
	if not show_connection_line:
		return
	
	var target = get_node_or_null(target_system_path)
	if target and target is Node2D:
		var target_pos := (target as Node2D).global_position - global_position
		var color := Color(0.8, 0.8, 0.2, 0.3)
		if has_triggered:
			color = Color(0.3, 0.9, 0.3, 0.3)
		
		# Draw dashed line from lever to target system
		var dir := target_pos.normalized()
		var total_length := target_pos.length()
		var dash_len := 12.0
		var drawn := 0.0
		var drawing := true
		
		while drawn < total_length:
			var segment_end := minf(drawn + dash_len, total_length)
			if drawing:
				draw_line(dir * drawn, dir * segment_end, color, 1.5)
			drawn = segment_end
			drawing = not drawing
		
		# Draw a small diamond at the target
		var ds := 8.0
		draw_colored_polygon(PackedVector2Array([
			target_pos + Vector2(0, -ds),
			target_pos + Vector2(ds, 0),
			target_pos + Vector2(0, ds),
			target_pos + Vector2(-ds, 0),
		]), color)


func _draw_text_label(text: String, pos: Vector2, color: Color, size: int = 14) -> void:
	"""Draw centered text at a position."""
	var font := ThemeDB.fallback_font
	if not font:
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	var offset := Vector2(-text_size.x / 2.0, text_size.y / 4.0)
	draw_string(font, pos + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		player_in_range = true
		queue_redraw()


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		player_in_range = false
		_pulse_time = 0.0
		# Reset glow
		if lever_visual and not has_triggered:
			var glow = lever_visual.get_node_or_null("StatusGlow") as Polygon2D
			if glow:
				glow.color = OFF_GLOW_COLOR
		queue_redraw()


func _is_player(body: Node2D) -> bool:
	return body and (body.is_in_group("player") or body.name == "Player")
