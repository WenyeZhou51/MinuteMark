extends CharacterBody2D

# ====================================
# ELEVATOR
# ====================================
# A vertical elevator that waits for player, then falls down

# CONFIGURATION
@export_group("Elevator Properties")
@export var elevator_size: Vector2 = Vector2(300, 400)  ## Size of the elevator
@export var door_width: float = 200.0  ## Width of the opening on the right side
@export var wall_thickness: float = 20.0  ## Thickness of the elevator frame walls
@export var wait_time: float = 2.0  ## Time to wait after player enters before falling
@export var fall_speed: float = 10000.0  ## Speed at which elevator falls

@export_group("Visual")
@export var elevator_color: Color = Color(0.5, 0.5, 0.5, 1.0)  ## Elevator color

# Internal state
var player_inside: bool = false
var wait_timer: float = 0.0
var is_falling: bool = false
var has_landed: bool = false

# Visual references
@onready var left_wall_visual: Polygon2D = $LeftWallVisual
@onready var top_wall_visual: Polygon2D = $TopWallVisual
@onready var bottom_wall_visual: Polygon2D = $BottomWallVisual
@onready var right_top_wall_visual: Polygon2D = $RightTopWallVisual
@onready var right_bottom_wall_visual: Polygon2D = $RightBottomWallVisual
@onready var detection_area: Area2D = $DetectionArea
@onready var left_wall_shape: CollisionShape2D = $LeftWallShape
@onready var top_wall_shape: CollisionShape2D = $TopWallShape
@onready var bottom_wall_shape: CollisionShape2D = $BottomWallShape
@onready var right_top_wall_shape: CollisionShape2D = $RightTopWallShape
@onready var right_bottom_wall_shape: CollisionShape2D = $RightBottomWallShape


func _ready() -> void:
	# Setup collision layers
	# Layer 1 (value 1) for walls/platforms - elevator acts as a wall
	collision_layer = 1
	collision_mask = 1  # Collide with walls/platforms
	
	# Setup detection area for player entry
	if detection_area:
		detection_area.body_entered.connect(_on_player_entered)
		detection_area.body_exited.connect(_on_player_exited)
		detection_area.collision_layer = 0
		detection_area.collision_mask = 1  # Detect player (layer 1, default for CharacterBody2D)
		detection_area.monitoring = true
		detection_area.monitorable = false
		print("[ELEVATOR] Detection area setup: collision_mask = ", detection_area.collision_mask)
	
	# Update visuals
	_update_visuals()


func _update_visuals() -> void:
	"""Update visual polygons for hollow elevator frame."""
	var half_size = elevator_size / 2.0
	var half_thickness = wall_thickness / 2.0
	var door_half_width = door_width / 2.0
	
	# Left wall (full height)
	if left_wall_visual:
		left_wall_visual.polygon = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(-half_size.x + wall_thickness, -half_size.y),
			Vector2(-half_size.x + wall_thickness, half_size.y),
			Vector2(-half_size.x, half_size.y)
		])
		left_wall_visual.color = elevator_color
	
	# Top wall (full width)
	if top_wall_visual:
		top_wall_visual.polygon = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, -half_size.y + wall_thickness),
			Vector2(-half_size.x, -half_size.y + wall_thickness)
		])
		top_wall_visual.color = elevator_color
	
	# Bottom wall (full width)
	if bottom_wall_visual:
		bottom_wall_visual.polygon = PackedVector2Array([
			Vector2(-half_size.x, half_size.y - wall_thickness),
			Vector2(half_size.x, half_size.y - wall_thickness),
			Vector2(half_size.x, half_size.y),
			Vector2(-half_size.x, half_size.y)
		])
		bottom_wall_visual.color = elevator_color
	
	# Right top wall (above door opening - full height since door is at bottom)
	if right_top_wall_visual:
		var door_top = half_size.y - door_width
		right_top_wall_visual.polygon = PackedVector2Array([
			Vector2(half_size.x - wall_thickness, -half_size.y),
			Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, door_top),
			Vector2(half_size.x - wall_thickness, door_top)
		])
		right_top_wall_visual.color = elevator_color
	
	# Right bottom wall (below door opening - this should be empty now since door is at bottom)
	# Actually, we don't need this anymore, but keep it for consistency
	if right_bottom_wall_visual:
		right_bottom_wall_visual.polygon = PackedVector2Array()  # Empty - door is at bottom
		right_bottom_wall_visual.color = elevator_color
	
	# Update collision shapes - create shapes with opening on the right
	_update_collision_shapes()
	
	# Update detection area shape
	if detection_area:
		var detection_shape = detection_area.get_node_or_null("CollisionShape2D")
		if detection_shape:
			var shape = RectangleShape2D.new()
			shape.size = elevator_size
			detection_shape.shape = shape


func _update_collision_shapes() -> void:
	"""Create collision shapes for hollow frame with opening on the right side."""
	var half_size = elevator_size / 2.0
	var door_half_width = door_width / 2.0
	
	# Left wall (full height)
	if left_wall_shape:
		var left_shape = RectangleShape2D.new()
		left_shape.size = Vector2(wall_thickness, elevator_size.y)
		left_wall_shape.shape = left_shape
		left_wall_shape.position = Vector2(-half_size.x + wall_thickness / 2.0, 0)
	
	# Top wall (full width)
	if top_wall_shape:
		var top_shape = RectangleShape2D.new()
		top_shape.size = Vector2(elevator_size.x, wall_thickness)
		top_wall_shape.shape = top_shape
		top_wall_shape.position = Vector2(0, -half_size.y + wall_thickness / 2.0)
	
	# Bottom wall (full width)
	if bottom_wall_shape:
		var bottom_shape = RectangleShape2D.new()
		bottom_shape.size = Vector2(elevator_size.x, wall_thickness)
		bottom_wall_shape.shape = bottom_shape
		bottom_wall_shape.position = Vector2(0, half_size.y - wall_thickness / 2.0)
	
	# Right top wall (above door opening - door is at bottom now)
	if right_top_wall_shape:
		var door_top = half_size.y - door_width
		var top_wall_height = door_top - (-half_size.y)  # From top (-half_size.y) to door top
		var top_shape = RectangleShape2D.new()
		top_shape.size = Vector2(wall_thickness, top_wall_height)
		right_top_wall_shape.shape = top_shape
		# Position: x at right side, y at center of the top wall section
		right_top_wall_shape.position = Vector2(half_size.x - wall_thickness / 2.0, (-half_size.y + door_top) / 2.0)
	
	# Right bottom wall (below door opening - empty now since door is at bottom)
	if right_bottom_wall_shape:
		# No collision needed - door is at the bottom
		var bottom_shape = RectangleShape2D.new()
		bottom_shape.size = Vector2(0, 0)  # Empty shape
		right_bottom_wall_shape.shape = bottom_shape


func _physics_process(delta: float) -> void:
	# Wait for player and countdown
	if player_inside and not is_falling and not has_landed:
		wait_timer += delta
		if wait_timer >= wait_time:
			print("[ELEVATOR] Wait time elapsed! Starting to fall...")
			is_falling = true
			# Start falling
			velocity.y = fall_speed
	
	# Apply gravity and move if falling
	if is_falling and not has_landed:
		# For high-speed movement, split into multiple steps to prevent tunneling
		var remaining_distance = velocity.y * delta
		var max_step_size = 50.0  # Maximum distance per step to prevent tunneling
		var steps = max(1, int(ceil(abs(remaining_distance) / max_step_size)))
		var step_distance = remaining_distance / steps
		
		for i in range(steps):
			velocity.y = step_distance / delta if delta > 0 else 0
			move_and_slide()
			
			# Check if we've hit the ground
			if is_on_floor():
				has_landed = true
				velocity = Vector2.ZERO
				is_falling = false
				break


func _on_player_entered(body: Node2D) -> void:
	"""Called when player enters the detection area."""
	print("[ELEVATOR] Body entered: ", body.name, " is_in_group('player'): ", body.is_in_group("player"))
	if body.is_in_group("player"):
		print("[ELEVATOR] Player entered! Starting wait timer...")
		player_inside = true
		wait_timer = 0.0


func _on_player_exited(body: Node2D) -> void:
	"""Called when player exits the detection area."""
	if body.is_in_group("player"):
		# Only reset if we haven't started falling yet
		if not is_falling:
			player_inside = false
			wait_timer = 0.0
