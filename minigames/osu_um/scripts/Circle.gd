extends Control
class_name Circle

@export var spawn_time_ms: float
@export var circle_radius: float = 40.0

# How far beyond the circle the approach ring starts (osu!-style telegraph).
const APPROACH_EXTRA: float = 70.0
# Fade-in duration (ms of game time) once the circle first appears.
const FADE_IN_MS: float = 250.0

var hit_state: String = "not_hit"  # not_hit, perfect, good, ok, miss, missed
var circle_color: Color = Color.WHITE
# Clickable radius. Kept generously larger than the visual radius (40) as a
# forgiveness margin so on-beat clicks near the edge still register (easier play).
var hit_circle_radius: float = 58.0

var particle_scene = preload("res://minigames/osu_um/ParticleBurst.tscn")
var ripple_scene = preload("res://minigames/osu_um/RippleEffect.tscn")

var button_default: Texture2D
var button_clicked: Texture2D
var shader_material: ShaderMaterial
var is_hit: bool = false

# 1.0 = approach ring is far out (just appeared); 0.0 = ring has converged onto
# the circle (the moment to click). Drives the shrinking-ring telegraph.
var approach_progress: float = 1.0
var approach_color: Color = Color(1.0, 0.84, 0.4)  # stage-gold ring

@onready var button: ColorRect = $Button
@onready var note_label: Label = $NoteLabel

func _ready() -> void:
	size = Vector2(circle_radius * 2, circle_radius * 2)
	button.size = size
	button.position = Vector2.ZERO

	# Load button textures.
	button_default = load("res://assets/PNG/Blue/Default/button_round_depth_flat.png")
	button_clicked = load("res://assets/PNG/Blue/Default/button_round_depth_line.png")

	# Circular-clip shader lives on the Button child so the root's _draw (rim +
	# approach ring) renders as clean unshaded lines.
	shader_material = ShaderMaterial.new()
	shader_material.shader = load("res://minigames/osu_um/CircleClip.gdshader")
	shader_material.set_shader_parameter("texture_sampler", button_default)
	shader_material.set_shader_parameter("circle_radius", 0.5)
	button.material = shader_material

	# Start invisible; update_approach() fades it in as its beat approaches.
	modulate.a = 0.0
	visible = false
	queue_redraw()

func _draw() -> void:
	var center := Vector2(circle_radius, circle_radius)
	# Thin gold rim so the circle reads as a stage note-medallion.
	draw_arc(center, circle_radius - 1.5, 0.0, TAU, 48, approach_color, 3.0, true)
	# Approach ring: shrinks toward the rim as the beat nears. Hidden once hit.
	if not is_hit and approach_progress > 0.0:
		var ring_radius := circle_radius + APPROACH_EXTRA * approach_progress
		draw_arc(center, ring_radius, 0.0, TAU, 48, approach_color, 4.0, true)

## Called every frame by OsuGame while the circle is pending.
## time_since_spawn_ms is negative before the hit beat, 0 at the beat.
func update_approach(time_since_spawn_ms: float, preempt_ms: float) -> void:
	if is_hit:
		return
	if not visible:
		visible = true
	approach_progress = clamp(-time_since_spawn_ms / preempt_ms, 0.0, 1.0)
	var appear_elapsed := time_since_spawn_ms + preempt_ms  # 0 at first appearance
	modulate.a = clamp(appear_elapsed / FADE_IN_MS, 0.0, 1.0)
	queue_redraw()

func is_clickable(click_pos: Vector2) -> bool:
	var circle_center := global_position + Vector2(circle_radius, circle_radius)
	return click_pos.distance_to(circle_center) <= hit_circle_radius

func set_spawn_time(time_ms: float) -> void:
	spawn_time_ms = time_ms

func set_combo_number(n: int) -> void:
	if note_label:
		note_label.text = str(n)

func set_hit_state(state: String) -> void:
	if is_hit:
		return  # Already hit, ignore subsequent calls

	is_hit = true
	hit_state = state
	modulate.a = 1.0

	match state:
		"perfect": circle_color = Color.GREEN
		"good": circle_color = Color.YELLOW
		"ok": circle_color = Color.ORANGE
		"miss", "missed": circle_color = Color.RED

	# Switch to the pressed button texture.
	shader_material.set_shader_parameter("texture_sampler", button_clicked)

	queue_redraw()
	_spawn_particles(circle_color)

func _spawn_particles(color: Color) -> void:
	var particle_burst = particle_scene.instantiate()
	particle_burst.position = global_position + Vector2(circle_radius, circle_radius)
	particle_burst.set_color(color)
	get_parent().add_child(particle_burst)

	var ripple_effect = ripple_scene.instantiate()
	# Position the ripple ON the circle. (Previously set_center(Vector2.ZERO)
	# reset this to screen origin, causing the stray "grey blob" in the corner.)
	ripple_effect.position = global_position + Vector2(circle_radius, circle_radius)
	ripple_effect.set_color(color)
	ripple_effect.set_circle_radius(circle_radius)
	get_parent().add_child(ripple_effect)
