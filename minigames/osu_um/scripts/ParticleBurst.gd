extends Node2D
class_name ParticleBurst

var particle_count: int = 8
var particle_speed: float = 300.0
var particle_lifetime: float = 0.6
var burst_color: Color = Color.WHITE

func _ready() -> void:
	"""Spawn particles in a burst pattern."""
	for i in range(particle_count):
		var angle = (TAU / particle_count) * i
		var direction = Vector2(cos(angle), sin(angle))
		_create_particle(direction)
	
	# Remove burst after particles finish
	await get_tree().create_timer(particle_lifetime).timeout
	queue_free()

func _create_particle(direction: Vector2) -> void:
	"""Create a single particle."""
	var particle = ColorRect.new()
	particle.size = Vector2(6, 6)
	particle.color = burst_color
	particle.position = Vector2.ZERO
	particle.modulate.a = 0.8
	add_child(particle)
	
	# Animate particle
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(particle, "position", direction * particle_speed * particle_lifetime, particle_lifetime)
	tween.tween_property(particle, "modulate:a", 0.0, particle_lifetime)

func set_color(color: Color) -> void:
	"""Set the particle color based on accuracy."""
	burst_color = color
