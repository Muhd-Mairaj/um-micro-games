extends Area2D

signal hit_obstacle

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Dino":
		hit_obstacle.emit()
