extends CharacterBody2D

const GRAVITY : float = 4200.0
const JUMP_SPEED : float = -1400.0

var game_active : bool = false:
	set(value):
		game_active = value
		if game_active and is_inside_tree():
			animated_sprite.play("run")

@onready var animated_sprite = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer = $JumpSound

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	if game_active:
		if is_on_floor():
			# If we are on floor, we should be running unless we just started a jump
			if animated_sprite.animation == "jump":
				# Landed! Switch back to run
				animated_sprite.play("run")
			elif not animated_sprite.is_playing():
				animated_sprite.play("run")
				
			if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				velocity.y = JUMP_SPEED
				animated_sprite.play("jump")
				jump_sound.play()
	else:
		if is_on_floor() and animated_sprite.is_playing():
			animated_sprite.stop()
			animated_sprite.frame = 0 # Idle frame
	
	move_and_slide()
