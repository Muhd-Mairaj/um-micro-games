extends Control
class_name Circle

@export var spawn_time_ms: float
@export var circle_radius: float = 40.0

var hit_state: String = "not_hit"  # not_hit, perfect, good, ok, miss, missed
var circle_color: Color = Color.WHITE
var hit_circle_radius: float = 50.0

var particle_scene = preload("res://minigames/osu_um/ParticleBurst.tscn")
var ripple_scene = preload("res://minigames/osu_um/RippleEffect.tscn")

var button_default: Texture2D
var button_clicked: Texture2D
var shader_material: ShaderMaterial
var is_hit: bool = false

func _ready() -> void:
	size = Vector2(circle_radius * 2, circle_radius * 2)
	
	# Load button textures
	button_default = load("res://assets/PNG/Blue/Default/button_round_depth_flat.png")
	button_clicked = load("res://assets/PNG/Blue/Default/button_round_depth_line.png")
	
	# Create shader material for circular clipping
	shader_material = ShaderMaterial.new()
	shader_material.shader = load("res://minigames/osu_um/CircleClip.gdshader")
	shader_material.set_shader_parameter("texture_sampler", button_default)
	shader_material.set_shader_parameter("circle_radius", 0.5)
	
	material = shader_material
	queue_redraw()

func _draw() -> void:
	# Draw rect that shader will texture with circular clipping
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
	
	# Draw clickable area indicator (white circle outline)
	draw_circle(Vector2(circle_radius, circle_radius), circle_radius, Color.WHITE)

func is_clickable(click_pos: Vector2) -> bool:
	# Calculate circle center in global space
	var circle_center = global_position + Vector2(circle_radius, circle_radius)
	var distance = click_pos.distance_to(circle_center)
	print("DEBUG: Checking click (%.0f, %.0f) vs circle at (%.0f, %.0f), distance: %.0f, radius: %.0f" % [click_pos.x, click_pos.y, circle_center.x, circle_center.y, distance, hit_circle_radius])
	return distance <= hit_circle_radius

func set_spawn_time(time_ms: float) -> void:
	spawn_time_ms = time_ms

func set_hit_state(state: String) -> void:
	if is_hit:
		return  # Already hit, ignore subsequent calls
	
	is_hit = true
	hit_state = state
	
	match state:
		"perfect": circle_color = Color.GREEN
		"good": circle_color = Color.YELLOW
		"ok": circle_color = Color.ORANGE
		"miss": circle_color = Color.RED
	
	# Switch to clicked button state
	shader_material.set_shader_parameter("texture_sampler", button_clicked)
	
	queue_redraw()
	_spawn_particles(circle_color)

func _spawn_particles(color: Color) -> void:
	var particle_burst = particle_scene.instantiate()
	particle_burst.position = global_position + Vector2(circle_radius, circle_radius)
	particle_burst.set_color(color)
	get_parent().add_child(particle_burst)
	
	var ripple_effect = ripple_scene.instantiate()
	ripple_effect.position = global_position + Vector2(circle_radius, circle_radius)
	ripple_effect.set_color(color)
	ripple_effect.set_center(Vector2.ZERO)
	ripple_effect.set_circle_radius(circle_radius)
	get_parent().add_child(ripple_effect)
