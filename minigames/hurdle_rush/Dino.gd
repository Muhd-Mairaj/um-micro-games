extends CharacterBody2D

const GRAVITY : float = 4200.0
const JUMP_SPEED : float = -1400.0

var game_active : bool = false

@onready var jump_sound: AudioStreamPlayer = $JumpSound

func _physics_process(delta: float) -> void:
	if not game_active and is_on_floor():
		return
		
	velocity.y += GRAVITY * delta
	
	if game_active and is_on_floor():
		if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			velocity.y = JUMP_SPEED
			jump_sound.play()
	
	move_and_slide()
