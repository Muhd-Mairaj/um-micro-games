extends Node
class_name HitZone

# Timing windows in milliseconds (generous for casual rhythm gameplay).
# Widened per review so on-beat clicks comfortably count as perfect, keeping the
# weighted accuracy above the 60% pass line achievable for casual players.
const PERFECT_WINDOW = 300    # ±300ms
const GOOD_WINDOW = 500       # ±500ms
const OK_WINDOW = 700         # ±700ms

func get_accuracy(time_difference_ms: float) -> String:
	"""
	Determine accuracy based on time difference between circle spawn and click.
	time_difference_ms: difference in milliseconds (negative if early, positive if late)
	"""
	var abs_diff = abs(time_difference_ms)
	
	if abs_diff <= PERFECT_WINDOW:
		return "perfect"
	elif abs_diff <= GOOD_WINDOW:
		return "good"
	elif abs_diff <= OK_WINDOW:
		return "ok"
	else:
		return "miss"

func is_within_hit_window(time_difference_ms: float) -> bool:
	"""Check if hit is within any valid window."""
	return abs(time_difference_ms) <= OK_WINDOW
