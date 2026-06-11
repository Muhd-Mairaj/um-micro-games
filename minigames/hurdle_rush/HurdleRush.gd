extends MiniGameBase

var hurdle_scene = preload("res://minigames/hurdle_rush/Hurdle.tscn")

const START_SPEED : float = 800.0
const MAX_SPEED : float = 1800.0
## How far past the right edge a hurdle spawns so it scrolls into view.
const SPAWN_MARGIN : float = 120.0

## Extra audio added during hub integration. hurdle_rush already references the
## 400 Sounds Pack directly for its other SFX, so the bg track does too; the win
## sting reuses the shared root sting like the rest of the collection.
const BG_MUSIC_PATH : String = "res://400 Sounds Pack/Musical Effects/8_bit_inn.wav"
const WIN_SFX_PATH : String = "res://win v1.0.wav"

var current_speed : float = START_SPEED

var game_active : bool = false
var time_elapsed : float = 0.0
## Set true on the first real frame (AFTER GameManager's ~2.2s GET_READY freeze).
## GameManager only set_process(false)'s the root, so without this gate the child
## HurdleTimer + Runner would tick during the countdown and hurdles would pile up.
var _started : bool = false

@onready var bg = $Bg
@onready var runner = $Runner
@onready var hurdle_timer = $HurdleTimer
@onready var lose_sound = $LoseSound

var _bg_music : AudioStreamPlayer = null
var _win_sound : AudioStreamPlayer = null

func setup() -> void:
	base_duration = 10.0
	instruction_text = "Jump & survive!"
	hurdle_timer.wait_time = 1.0

	# Optional audio (null-safe). Looping bg track sits low under the SFX.
	if ResourceLoader.exists(BG_MUSIC_PATH):
		_bg_music = AudioStreamPlayer.new()
		_bg_music.stream = load(BG_MUSIC_PATH) as AudioStream
		_bg_music.volume_db = -14.0
		_bg_music.finished.connect(func() -> void: _bg_music.play())
		add_child(_bg_music)
		_bg_music.play()
	if ResourceLoader.exists(WIN_SFX_PATH):
		_win_sound = AudioStreamPlayer.new()
		_win_sound.stream = load(WIN_SFX_PATH) as AudioStream
		add_child(_win_sound)

	# Do NOT start the round here: GameManager freezes our _process for the
	# GET_READY flash. We begin on the first real frame (see _process) so the
	# timer and runner never run during the countdown.

func _process(delta: float) -> void:
	# First unfrozen frame after GET_READY: actually begin the round.
	if not _started:
		_started = true
		game_active = true
		runner.game_active = true
		hurdle_timer.start()

	if not game_active:
		return

	time_elapsed += delta * time_scale

	# Speed up aggressively (150px per second).
	current_speed = min(START_SPEED + (time_elapsed * 150.0), MAX_SPEED)

	# Move the parallax background.
	bg.scroll_offset.x -= current_speed * delta * time_scale

	# Move active hurdles.
	for child in get_children():
		if child.is_in_group("obstacles"):
			child.position.x -= current_speed * delta * time_scale
			if child.position.x < -100:
				child.queue_free()

	# WIN is the survival timeout (see the lose() override) — we no longer end
	# the round from here, so there is no race against the shared HUD timer.

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
	# Spawn just past the right edge so the hurdle scrolls in, at any window width.
	hurdle.position = Vector2(get_viewport_rect().size.x + SPAWN_MARGIN, 550)
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

	lose()  # -> override -> super.lose() (game_active already false = a real crash)

## SURVIVAL override: outlasting the shared HUD timer is a WIN. GameManager calls
## lose() when the timer runs out; if we have NOT crashed (game_active still true)
## we convert it into a win. (Same pattern as phone_down / order_in_the_court, so
## the whole collection drives off the one shared HUD timer instead of racing it.)
func lose() -> void:
	if _finished:
		return
	if game_active:
		_win_game()
	else:
		super.lose()

func _win_game():
	game_active = false
	runner.game_active = false
	hurdle_timer.stop()
	if _win_sound != null:
		_win_sound.play()

	# Sprint off screen
	runner.velocity.x = 800

	win()
