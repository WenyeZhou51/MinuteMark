extends Area2D
## Kickable fire (torch/candle). Lights a small area; when kicked it flies and on landing expands (bigger light).

@export_group("Kick")
@export var kick_speed: float = 1800.0
@export var rotation_speed_min: float = -8.0
@export var rotation_speed_max: float = 8.0

@export_group("Light")
@export var base_light_radius: float = 120.0
@export var expanded_light_radius: float = 220.0
@export var expand_duration: float = 0.5

@export_group("Collision")
@export var object_size: Vector2 = Vector2(24, 32)

var is_kicked: bool = false
var kick_velocity: Vector2 = Vector2.ZERO
var rotation_speed: float = 0.0
var has_collided: bool = false
var expansion_count: int = 0  # how many times we've landed and expanded
var raycast: RayCast2D = null

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Node2D = $Visual
@onready var light: PointLight2D = $PointLight2D
@onready var glow_sprite: Sprite2D = $GlowSprite if has_node("GlowSprite") else null


func _ready() -> void:
	collision_layer = 32
	collision_mask = 5
	add_to_group("kickable_objects")
	add_to_group("fire_lights")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	raycast = RayCast2D.new()
	raycast.enabled = false
	raycast.collide_with_areas = true
	raycast.collide_with_bodies = true
	raycast.exclude_parent = true
	add_child(raycast)
	raycast.set_collision_mask_value(1, true)
	raycast.set_collision_mask_value(3, true)

	_setup_light_texture()
	_update_light_radius(_get_current_max_radius())


func _setup_light_texture() -> void:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var max_d := center.length()
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(center) / max_d
			var a := 1.0 - clampf(d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	var tex := ImageTexture.create_from_image(img)
	if light:
		light.texture = tex
	if glow_sprite:
		var glow_img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var d := Vector2(x, y).distance_to(center) / max_d
				var a := (1.0 - clampf(d, 0.0, 1.0)) * 0.5
				a = a * a
				glow_img.set_pixel(x, y, Color(1.0, 0.5, 0.2, a))
		glow_sprite.texture = ImageTexture.create_from_image(glow_img)
		glow_sprite.z_index = -1


func _get_current_max_radius() -> float:
	return base_light_radius + (expanded_light_radius - base_light_radius) * min(expansion_count, 3) * 0.33


func _update_light_radius(radius: float) -> void:
	if light:
		light.texture_scale = radius / 64.0
	if glow_sprite:
		glow_sprite.scale = Vector2(radius / 64.0, radius / 64.0) * 2.0


func _physics_process(delta: float) -> void:
	if not is_kicked or has_collided:
		return
	raycast.target_position = kick_velocity.normalized() * kick_velocity.length() * delta * 1.5
	raycast.force_raycast_update()
	if raycast.is_colliding():
		_handle_collision(raycast.get_collider())
	else:
		global_position += kick_velocity * delta
		rotation += rotation_speed * delta


func kick(direction: Vector2, speed: float = 0.0) -> void:
	if is_kicked:
		return
	is_kicked = true
	var final_speed = speed if speed > 0 else kick_speed
	kick_velocity = direction.normalized() * final_speed
	rotation_speed = randf_range(rotation_speed_min, rotation_speed_max)
	raycast.enabled = true
	set_collision_mask_value(2, false)
	if visual:
		visual.modulate = Color(1.2, 0.7, 0.5)


func can_be_kicked() -> bool:
	return not is_kicked


func _handle_collision(collider: Node) -> void:
	if has_collided:
		return
	has_collided = true
	raycast.enabled = false
	is_kicked = false
	kick_velocity = Vector2.ZERO
	if visual:
		visual.modulate = Color.WHITE
	set_collision_mask_value(2, true)
	_land_and_expand()


func _land_and_expand() -> void:
	var from_radius = _get_current_max_radius()
	expansion_count += 1
	var target_radius = _get_current_max_radius()
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_method(_update_light_radius, from_radius, target_radius, expand_duration)


func _on_body_entered(body: Node2D) -> void:
	if is_kicked and not has_collided and not body.is_in_group("player"):
		_handle_collision(body)


func _on_area_entered(area: Area2D) -> void:
	if is_kicked and not has_collided:
		_handle_collision(area)
