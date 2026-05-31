extends Node

var can_move: bool = false

func enter() -> void:
	can_move = false
	# Flash red to show hit
	get_parent().get_parent().modulate = Color(1.0, 0.3, 0.3, 1.0)
	
	# Wait 0.25 seconds then go back to walk
	await get_tree().create_timer(0.25).timeout
	get_parent().get_parent().modulate = Color(1.0, 1.0, 1.0, 1.0)
	get_parent().change_state(get_parent().get_node("WalkState"))

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass
