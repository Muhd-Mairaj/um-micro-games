class_name Damageable
extends Node

# ── Health ──────────────────────────────────
var health: int = 1 : # students only need 1 tap to die!
	set(new_health):
		var old_health = health
		health = new_health
		# Tell everyone health changed
		SignalBus.on_health_changed.emit(owner, old_health, health)

# Signal for when THIS student gets hit
signal on_hit

# ── Called when player taps student ─────────
func hit() -> void:
	health -= 1
	on_hit.emit()

	# Check if dead
	if health <= 0:
		SignalBus.on_student_dead.emit(owner)
