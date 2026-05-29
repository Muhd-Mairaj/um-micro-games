extends ColorRect
class_name Circle

var spawn_time_ms: float = 0.0
var hit_state: String = "not_hit"  # Options: not_hit, perfect, good, ok, miss, missed
var circle_radius: float = 40.0
var hit_circle_radius: float = 50.0  # Clickable area is slightly larger

func _ready() -> void:
	"""Initialize circle appearance."""
	size = Vector2(circle_radius * 2, circle_radius * 2)
	color = Color.from_string("#4da6ff", Color.LIGHT_BLUE)  # osu! blue
	custom_minimum_size = size

func set_spawn_time(time_ms: float) -> void:
	"""Set when this circle should appear."""
	spawn_time_ms = time_ms

func is_clickable(click_pos: Vector2) -> bool:
	"""Check if click position is within hit area."""
	var center = global_position + size / 2
	var distance = center.distance_to(click_pos)
	return distance <= hit_circle_radius

func set_hit_state(state: String) -> void:
	"""Update hit state and visual feedback."""
	hit_state = state
	match state:
		"perfect":
			color = Color.GREEN
		"good":
			color = Color.YELLOW
		"ok":
			color = Color.ORANGE
		"miss":
			color = Color.RED
		"missed":
			color = Color.GRAY
