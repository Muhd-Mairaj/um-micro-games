extends Node

var can_move: bool = true

func enter() -> void:
	can_move = true
	# Play walk animation
	var tree = get_parent().get_parent().get_node("AnimationTree")
	var playback = tree.get("parameters/playback")
	playback.travel("walk")

func exit() -> void:
	can_move = false

func update(_delta: float) -> void:
	pass  # movement handled in main script
