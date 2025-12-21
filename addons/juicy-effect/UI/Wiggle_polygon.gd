extends Polygon2D


var origin_polygons : PackedVector2Array
@export var polygon_color : Color = Color(1, 1, 1, 1)
@export var intensity : float = 1.0
@export var duration : float = 1.0
var curtime : float

var target_offset : Array[Vector2]
# Called when the node enters the scene tree for the first time.
func _ready():
	# print("[WIGGLE_POLYGON DEBUG] ===== INITIALIZING: ", name, " in ", get_parent().name, " =====")
	# print("[WIGGLE_POLYGON DEBUG] BEFORE changes:")
	# print("  - self_modulate: ", self_modulate)
	# print("  - color: ", color)
	# print("  - polygon_color (export): ", polygon_color)
	
	# USE the polygon_color export variable - this is what you set in the inspector!
	color = polygon_color
	self_modulate = Color(1, 1, 1, 1)  # Keep modulation white so color is pure
	
	# print("[WIGGLE_POLYGON DEBUG] AFTER changes:")
	# print("  - self_modulate: ", self_modulate)
	# print("  - color: ", color)
	# print("  - FINAL VISUAL COLOR should be: ", color * self_modulate)
	# print("[WIGGLE_POLYGON DEBUG] =====================================")
	
	origin_polygons = polygon
	

	prepos = origin_polygons
	frompos = prepos
	target_offset = add_vector2array_offset(prepos , random_vector2array_offset(intensity))
	pass # Replace with function body.

var prepos 
var frompos

var debug_frame_count = 0
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	# Debug first few frames
	if debug_frame_count < 5:
		# print("[WIGGLE_POLYGON DEBUG] Frame ", debug_frame_count, " - ", name, ": self_modulate=", self_modulate, ", color=", color)
		debug_frame_count += 1
	
	#target_offset = add_vector2array_offset(prepos , random_vector2array_offset(intensity))
	

	curtime += delta
	if curtime >= duration :
		frompos = target_offset
		target_offset = add_vector2array_offset(prepos , random_vector2array_offset(intensity))
		curtime = 0

	for i in range(polygon.size()) :
		var tar =  prepos[i] + target_offset[i]
		var t = curtime/duration
		polygon[i] =  lerp(frompos[i],target_offset[i],t) 

	
		

	
	pass


func add_vector2array_offset(base : Array[Vector2], add : Array[Vector2]) -> Array[Vector2]:
	var ret : Array[Vector2]
	
	for i in base.size():
		ret.insert(i,(base[i] + add[i]))
	
	return ret
	

func random_vector2array_offset(max:float) -> Array[Vector2]:
	var arrVector2 : Array[Vector2]
	
	for i in origin_polygons.size() :
		arrVector2.insert(i,random_offset(max))
		pass
	
	return arrVector2

func random_offset(max : float) -> Vector2 :
	return Vector2(randf_range(-max, max), randf_range(-max, max))

