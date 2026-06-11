extends Node

var current_state: Node = null

func _ready() -> void:
	# Start in walk state
	change_state($WalkState)

func change_state(new_state: Node) -> void:
	if current_state:
		current_state.exit()
	current_state = new_state
	current_state.enter()

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)
