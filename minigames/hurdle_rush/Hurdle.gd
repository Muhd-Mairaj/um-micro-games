extends Area2D

signal hit_obstacle

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Runner":
		hit_obstacle.emit()
