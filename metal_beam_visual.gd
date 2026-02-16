extends Node2D

## Draws a metal beam visual that automatically matches a given size.
## Used by WrapPlatform and configured by LeverPlatformSystem.

var beam_size: Vector2 = Vector2(160, 24)

# Colors
const BODY_COLOR := Color(0.38, 0.40, 0.44, 1.0)       # Main steel body
const TOP_HIGHLIGHT := Color(0.55, 0.58, 0.62, 1.0)     # Top edge highlight
const BOTTOM_SHADOW := Color(0.22, 0.23, 0.26, 1.0)     # Bottom edge shadow
const EDGE_COLOR := Color(0.18, 0.19, 0.22, 1.0)        # Outer border
const RIVET_COLOR := Color(0.50, 0.52, 0.56, 1.0)       # Rivet fill
const RIVET_SHADOW := Color(0.28, 0.29, 0.32, 1.0)      # Rivet shadow
const GROOVE_COLOR := Color(0.30, 0.32, 0.36, 1.0)      # Horizontal groove lines
const FLANGE_COLOR := Color(0.33, 0.35, 0.39, 1.0)      # Top/bottom flange


func set_beam_size(new_size: Vector2) -> void:
	beam_size = new_size
	queue_redraw()


func _draw() -> void:
	var half := beam_size / 2.0
	var rect := Rect2(-half, beam_size)
	
	# --- Outer border ---
	draw_rect(rect, EDGE_COLOR, true)
	
	# --- Main body (slightly inset) ---
	var body_inset := 1.5
	var body_rect := Rect2(
		rect.position + Vector2(body_inset, body_inset),
		rect.size - Vector2(body_inset * 2, body_inset * 2)
	)
	draw_rect(body_rect, BODY_COLOR, true)
	
	# --- Top and bottom flanges (I-beam style) ---
	var flange_height := clampf(beam_size.y * 0.2, 2.0, 8.0)
	
	# Top flange
	var top_flange := Rect2(
		Vector2(-half.x + body_inset, -half.y + body_inset),
		Vector2(beam_size.x - body_inset * 2, flange_height)
	)
	draw_rect(top_flange, FLANGE_COLOR, true)
	
	# Bottom flange
	var bottom_flange := Rect2(
		Vector2(-half.x + body_inset, half.y - body_inset - flange_height),
		Vector2(beam_size.x - body_inset * 2, flange_height)
	)
	draw_rect(bottom_flange, FLANGE_COLOR, true)
	
	# --- Top highlight line ---
	var highlight_y := -half.y + body_inset + 1.0
	draw_line(
		Vector2(-half.x + body_inset + 2, highlight_y),
		Vector2(half.x - body_inset - 2, highlight_y),
		TOP_HIGHLIGHT, 1.0
	)
	
	# --- Bottom shadow line ---
	var shadow_y := half.y - body_inset - 1.0
	draw_line(
		Vector2(-half.x + body_inset + 2, shadow_y),
		Vector2(half.x - body_inset - 2, shadow_y),
		BOTTOM_SHADOW, 1.0
	)
	
	# --- Horizontal groove lines (web detail) ---
	var groove_count := clampi(int(beam_size.y / 10.0), 1, 4)
	var groove_spacing := (beam_size.y - flange_height * 2 - body_inset * 2) / float(groove_count + 1)
	for i in range(1, groove_count + 1):
		var gy := -half.y + body_inset + flange_height + groove_spacing * i
		draw_line(
			Vector2(-half.x + body_inset + 4, gy),
			Vector2(half.x - body_inset - 4, gy),
			GROOVE_COLOR, 1.0
		)
	
	# --- Rivets ---
	var rivet_radius := clampf(beam_size.y * 0.08, 1.5, 4.0)
	var rivet_spacing := clampf(beam_size.x * 0.08, 20.0, 80.0)
	var rivet_y_top := -half.y + body_inset + flange_height * 0.5
	var rivet_y_bot := half.y - body_inset - flange_height * 0.5
	
	var num_rivets := int(beam_size.x / rivet_spacing)
	if num_rivets < 2:
		num_rivets = 2
	var actual_spacing := (beam_size.x - body_inset * 4) / float(num_rivets)
	
	for i in range(num_rivets + 1):
		var rx := -half.x + body_inset * 2 + actual_spacing * i
		# Top row rivets
		draw_circle(Vector2(rx, rivet_y_top) + Vector2(0.5, 0.5), rivet_radius, RIVET_SHADOW)
		draw_circle(Vector2(rx, rivet_y_top), rivet_radius, RIVET_COLOR)
		# Bottom row rivets
		draw_circle(Vector2(rx, rivet_y_bot) + Vector2(0.5, 0.5), rivet_radius, RIVET_SHADOW)
		draw_circle(Vector2(rx, rivet_y_bot), rivet_radius, RIVET_COLOR)
