extends RigidBody2D

## A piece of paper that actually ROLLS UP.

@export var life_time: float = 2.5
var timer: float = 0.0
var roll_speed: float = 1.2
var sprite: Sprite2D

func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    gravity_scale = 1.2
    
    if not sprite:
        sprite = Sprite2D.new()
        add_child(sprite)
    
    var mat = ShaderMaterial.new()
    mat.shader = load("res://shaders/paper_scrap_roll.gdshader")
    sprite.material = mat
    
    get_tree().create_timer(life_time).timeout.connect(queue_free)

func set_texture_from_capture(full_screen_tex: Texture2D, global_pos: Vector2):
    if not sprite: 
        sprite = Sprite2D.new()
        add_child(sprite)
        
    sprite.texture = full_screen_tex
    sprite.region_enabled = true
    
    var viewport = get_viewport()
    var screen_pos = viewport.get_canvas_transform() * global_pos
    
    # Square chunk of the screen
    sprite.region_rect = Rect2(screen_pos.x - 25, screen_pos.y - 25, 50, 50)
    sprite.position = Vector2.ZERO

func _process(delta: float) -> void:
    timer += delta
    if sprite and sprite.material:
        # Increase roll amount over time
        var roll = clamp(timer * roll_speed, 0.0, 1.0)
        sprite.material.set_shader_parameter("roll_amount", roll)
    
    if timer > life_time - 0.5:
        modulate.a = (life_time - timer) / 0.5
