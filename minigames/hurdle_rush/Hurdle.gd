extends Area2D

signal hit_obstacle

func _ready() -> void:
	# Add a dark tint to the sprite to make it stand out against bright backgrounds
	$Sprite2D.modulate = Color("#4a3528")

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Runner":
		hit_obstacle.emit()
