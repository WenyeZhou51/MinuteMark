extends Node2D

## A lamp that glows and occasionally pops out fire particles.

@export var glow_radius: float = 500.0
@export var pop_interval_min: float = 2.0
@export var pop_interval_max: float = 5.0
@export var particle_count: int = 3

@onready var light: PointLight2D = $PointLight2D
@onready var visual: Node2D = $Visual

var pop_timer: float = 0.0
var next_pop_time: float = 0.0
var fire_sim_ref: Node2D = null
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	next_pop_time = rng.randf_range(pop_interval_min, pop_interval_max)
	if light:
		light.texture_scale = glow_radius / 32.0 # GradientTexture2D is 64x64 by default
	
	call_deferred("_find_fire_sim")

func _find_fire_sim() -> void:
	var sims = get_tree().get_nodes_in_group("fire_simulation")
	if sims.size() > 0:
		fire_sim_ref = sims[0]

func _process(delta: float) -> void:
	pop_timer += delta
	if pop_timer >= next_pop_time:
		pop_timer = 0.0
		next_pop_time = rng.randf_range(pop_interval_min, pop_interval_max)
		_pop_particles()

func _pop_particles() -> void:
	if not fire_sim_ref:
		_find_fire_sim()
		if not fire_sim_ref: return

	for i in range(particle_count):
		var angle = rng.randf_range(-PI, PI)
		var speed = rng.randf_range(50, 150)
		var vel = Vector2(cos(angle) * speed, sin(angle) * speed - 50) # Slight upward bias
		
		var particle = {
			"pos": global_position + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4)),
			"vel": vel,
			"life": rng.randf_range(0.5, 1.2),
			"max_life": 1.2,
			"heat": rng.randf_range(0.7, 1.0),
			"size": rng.randf_range(6.0, 14.0),
		}
		fire_sim_ref.particles.append(particle)
	
	# Visual feedback for the pop
	if light:
		var tween = create_tween()
		var original_energy = light.energy
		tween.tween_property(light, "energy", original_energy * 1.5, 0.1)
		tween.tween_property(light, "energy", original_energy, 0.3)
