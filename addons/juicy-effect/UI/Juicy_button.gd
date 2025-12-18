extends Button
class_name Juicy_button
## The Juicy effect you wanted to be interact with must be a child of the button

@export var juicy_focus_name : String = "Focus"
@export var juicy_unfocus_name : String = "Unfocus"
@export var juicy_pressed_name : String = "Confirm"
var select_effect : Juicy_player;
var unselect_effect : Juicy_player;
var pressed_effect : Juicy_player;
@export var isFocus : bool

# set pivot at center, good for if you want to scale the button
@export var auto_pivot_center: bool 

# Called when the node enters the scene tree for the first time.
func _ready():
	# print("[JUICY_BUTTON DEBUG] Initializing button: ", name)
	select_effect = get_node_or_null(juicy_focus_name)
	unselect_effect = get_node_or_null(juicy_unfocus_name)
	pressed_effect = get_node_or_null(juicy_pressed_name)
	
	if select_effect:
		focus_entered.connect(func():
			# print("[JUICY_BUTTON DEBUG] %s - FOCUS ENTERED - Playing select effect" % name)
			_debug_polygon_colors()
			select_effect.Play()
		)
	if unselect_effect:
		focus_exited.connect(func():
			# print("[JUICY_BUTTON DEBUG] %s - FOCUS EXITED - Playing unselect effect" % name)
			unselect_effect.Play()
		)
	if pressed_effect:
		button_down.connect(func():
			# print("[JUICY_BUTTON DEBUG] %s - BUTTON PRESSED" % name)
			pressed_effect.Play()
		)
	

	
	if auto_pivot_center :
		pivot_offset = size/2
	
	# Defer focus grab to next frame to ensure all effects are initialized
	if isFocus :
		call_deferred("grab_focus")
		
	
	
	
	
	pass # Replace with function body.
	
	
func _set_focus():
	grab_focus()

func _debug_polygon_colors():
	var indicator = get_node_or_null("SelectingIndicator")
	if indicator:
		var red_poly = indicator.get_node_or_null("RedPolygon")
		var cyan_poly = indicator.get_node_or_null("CyanPolygon")
		if red_poly:
			# print("[JUICY_BUTTON DEBUG]   RedPolygon - color: %s, self_modulate: %s" % [red_poly.color, red_poly.self_modulate])
			pass
		if cyan_poly:
			# print("[JUICY_BUTTON DEBUG]   CyanPolygon - color: %s, self_modulate: %s" % [cyan_poly.color, cyan_poly.self_modulate])
			pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	pass

