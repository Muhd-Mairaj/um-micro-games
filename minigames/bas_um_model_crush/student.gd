extends CharacterBody2D

var is_dead   = false
var game_over = false

@onready var state_machine = $StateMachine
@onready var damageable    = $Damageable
@onready var anim_tree     = $AnimationTree
@onready var sprite        = $Sprite2D

func _ready() -> void:
	sprite.flip_h = false
	damageable.on_hit.connect(_on_hit)
	SignalBus.on_student_dead.connect(_on_dead)
	var playback = anim_tree.get("parameters/playback")
	playback.travel("walk")

func _on_hit() -> void:
	if is_dead:
		return
	state_machine.change_state($StateMachine/HitState)

func _on_dead(entity) -> void:
	if entity != self:
		return
	is_dead = true
	state_machine.change_state($StateMachine/DeadState)

func stop_student() -> void:
	game_over = true
	var playback = anim_tree.get("parameters/playback")
	playback.travel("dead")

func reset_student(new_x: float, base_y: float) -> void:
	is_dead   = false
	game_over = false
	visible   = true
	modulate  = Color(1, 1, 1, 1)
	position  = Vector2(new_x, base_y)
	damageable.health = 1
	var playback = anim_tree.get("parameters/playback")
	playback.travel("walk")
	state_machine.change_state($StateMachine/WalkState)
