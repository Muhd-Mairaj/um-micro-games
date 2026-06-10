extends Node
class_name ScoreManager

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var accuracy_counts: Dictionary = {
	"perfect": 0,
	"good": 0,
	"ok": 0,
	"miss": 0
}

# Scoring constants
const PERFECT_POINTS = 10
const GOOD_POINTS = 5
const OK_POINTS = 2
const MISS_POINTS = 0

func register_hit(accuracy: String) -> void:
	"""Register a hit and update score/combo."""
	if accuracy not in accuracy_counts:
		return
	
	accuracy_counts[accuracy] += 1
	
	if accuracy == "miss":
		combo = 0
	else:
		combo += 1
		max_combo = max(max_combo, combo)
		
		# Award points based on accuracy
		var points = 0
		match accuracy:
			"perfect":
				points = PERFECT_POINTS
			"good":
				points = GOOD_POINTS
			"ok":
				points = OK_POINTS
		
		# Apply combo multiplier
		var multiplier = 1.0 + (combo * 0.01)  # 1% increase per combo
		points = int(points * multiplier)
		score += points

func get_score() -> int:
	return score

func get_combo() -> int:
	return combo

func get_max_combo() -> int:
	return max_combo

func get_accuracy_counts() -> Dictionary:
	return accuracy_counts.duplicate()

func get_total_notes() -> int:
	return accuracy_counts.perfect + accuracy_counts.good + accuracy_counts.ok + accuracy_counts.miss

func get_clean_hits() -> int:
	"""Notes hit within any timing window (perfect + good + ok)."""
	return accuracy_counts.perfect + accuracy_counts.good + accuracy_counts.ok

## Weighted accuracy as a percentage (perfect=300, good=100, ok=50, miss=0).
## Single source of truth for both the HUD readout and the win/lose check.
func get_accuracy_pct() -> float:
	var total := get_total_notes()
	if total == 0:
		return 0.0
	var weighted: int = accuracy_counts.perfect * 300 + accuracy_counts.good * 100 + accuracy_counts.ok * 50
	return 100.0 * weighted / (total * 300.0)

func reset() -> void:
	"""Reset all stats for a new game."""
	score = 0
	combo = 0
	max_combo = 0
	accuracy_counts = {
		"perfect": 0,
		"good": 0,
		"ok": 0,
		"miss": 0
	}
