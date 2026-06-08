extends Control
class_name RippleEffect

var start_radius: float = 150.0  # Starts large
var circle_radius: float = 40.0  # Contracts toward this
var duration: float = 0.6
var ripple_color: Color = Color.WHITE
var elapsed_time: float = 0.0
var is_animating: bool = true

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	if not is_animating:
		return
	
	elapsed_time += delta
	if elapsed_time >= duration:
		is_animating = false
		queue_free()
		return
	
	queue_redraw()

func _draw() -> void:
	if not is_animating:
		return
	
	# Calculate progress (0 to 1)
	var progress = elapsed_time / duration
	
	# Lerp from start_radius down to circle_radius
	var current_radius = lerp(start_radius, circle_radius, progress)
	
	# Calculate alpha fade (starts opaque, fades out)
	var alpha = 1.0 - progress
	
	# Draw contracting ring (outline, not filled)
	var ring_color = ripple_color
	ring_color.a = alpha
	
	# Draw ring by drawing multiple circles with decreasing radius
	for i in range(0, 3):
		var ring_offset = float(i) * 2.0
		draw_circle(Vector2.ZERO, current_radius - ring_offset, ring_color)

func set_color(color: Color) -> void:
	ripple_color = color

func set_center(pos: Vector2) -> void:
	position = pos

func set_circle_radius(radius: float) -> void:
	circle_radius = radius
