extends MiniGameBase

var hurdle_scene = preload("res://minigames/hurdle_rush/Hurdle.tscn")

const START_SPEED : float = 800.0
const MAX_SPEED : float = 1200.0
var current_speed : float = START_SPEED

var game_active : bool = false
var time_elapsed : float = 0.0

@onready var bg = $Bg
@onready var runner = $Runner
@onready var hurdle_timer = $HurdleTimer
@onready var lose_sound = $LoseSound

func setup() -> void:
	base_duration = 7.0
	instruction_text = "Jump & survive!"
	
	game_active = true
	runner.game_active = true
	
	# Start spawning hurdles
	hurdle_timer.wait_time = randf_range(0.8, 1.2)
	hurdle_timer.start()

func _process(delta: float) -> void:
	if not game_active:
		return
		
	time_elapsed += delta * time_scale
	
	# Speed up gradually
	current_speed = min(START_SPEED + (time_elapsed * 50.0), MAX_SPEED)
	
	# Move the parallax background. ParallaxBackground automatically handles scrolling 
	# based on the ParallaxLayer's motion_mirroring, but we have to manually update its scroll_offset.
	bg.scroll_offset.x -= current_speed * delta * time_scale
	
	# Move active hurdles
	for child in get_children():
		if child.is_in_group("obstacles"):
			child.position.x -= current_speed * delta * time_scale
			if child.position.x < -100:
				child.queue_free()
				
	# Win condition: survive the timer
	if time_elapsed >= base_duration - 0.2 and not _finished:
		_win_game()

func _on_hurdle_timer_timeout():
	if not game_active:
		return
		
	var hurdle = hurdle_scene.instantiate()
	
	# Spawn off screen to the right, sitting on the floor (Y=550 is right above Floor at 600)
	hurdle.position = Vector2(1400, 550)
	
	hurdle.hit_obstacle.connect(_on_obstacle_hit)
	
	add_child(hurdle)
	
	# Randomize next spawn
	hurdle_timer.wait_time = randf_range(0.8, 1.6) / time_scale

func _on_obstacle_hit():
	if not game_active:
		return
	
	game_active = false
	runner.game_active = false
	hurdle_timer.stop()
	
	lose_sound.play()
	
	# Knockback effect
	runner.velocity.x = -400
	runner.velocity.y = -600
	
	lose()

func _win_game():
	game_active = false
	runner.game_active = false
	hurdle_timer.stop()
	
	# Sprint off screen
	runner.velocity.x = 800
	
	win()
