extends MiniGameBase

var hurdle_scene = preload("res://minigames/hurdle_rush/Hurdle.tscn")

const START_SPEED : float = 800.0
const MAX_SPEED : float = 1800.0
var current_speed : float = START_SPEED

var game_active : bool = false
var time_elapsed : float = 0.0

@onready var bg = $Bg
@onready var runner = $Runner
@onready var hurdle_timer = $HurdleTimer
@onready var lose_sound = $LoseSound

func setup() -> void:
	base_duration = 10.0
	instruction_text = "Jump & survive!"
	
	game_active = true
	runner.game_active = true
	
	# Start spawning hurdles - initial gap is quite large
	hurdle_timer.wait_time = 1.0
	hurdle_timer.start()

func _process(delta: float) -> void:
	if not game_active:
		return
		
	time_elapsed += delta * time_scale
	
	# Speed up much more aggressively (150px per second)
	current_speed = min(START_SPEED + (time_elapsed * 150.0), MAX_SPEED)
	
	# Move the parallax background
	bg.scroll_offset.x -= current_speed * delta * time_scale
	
	# Move active hurdles
	for child in get_children():
		if child.is_in_group("obstacles"):
			child.position.x -= current_speed * delta * time_scale
			if child.position.x < -100:
				child.queue_free()
				
	# Win condition. time_elapsed accumulates delta * time_scale, so this
	# threshold needs to scale with time_scale too in order to keep a
	# constant ~0.3s real-time margin before the HUD's own timeout fires
	# (otherwise that margin shrinks to near-zero in later faculties and
	# a last-moment HUD timeout can race this and turn a win into a loss).
	if time_elapsed >= base_duration - 0.3 * time_scale:
		_win_game()

func _on_hurdle_timer_timeout():
	if not game_active:
		return
		
	_spawn_hurdle()
	
	# Scaling chance of a "Double Hurdle" based on speed
	# 10% chance at START_SPEED, up to 50% chance at MAX_SPEED
	var double_chance = remap(current_speed, START_SPEED, MAX_SPEED, 0.1, 0.5)
	if randf() < double_chance:
		var quick_timer = get_tree().create_timer(0.3)
		quick_timer.timeout.connect(_spawn_hurdle)
	
	# Randomize next spawn - gap gets smaller as you go faster
	var spawn_rate = remap(current_speed, START_SPEED, MAX_SPEED, 1.2, 0.6)
	hurdle_timer.wait_time = randf_range(spawn_rate, spawn_rate + 0.5) / time_scale

func _spawn_hurdle():
	if not game_active: return
	var hurdle = hurdle_scene.instantiate()
	hurdle.position = Vector2(1400, 550)
	hurdle.hit_obstacle.connect(_on_obstacle_hit)
	add_child(hurdle)

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
