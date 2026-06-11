extends Node

var can_move: bool = false

func enter() -> void:
	can_move = false
	# Play dead animation
	var tree = get_parent().get_parent().get_node("AnimationTree")
	var playback = tree.get("parameters/playback")
	playback.travel("dead")

	# Hide after animation finishes
	await get_tree().create_timer(0.5).timeout
	get_parent().get_parent().visible = false

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass
