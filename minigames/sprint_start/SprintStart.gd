# =============================================================================
# minigames/sprint_start/SprintStart.gd
# =============================================================================
# FACULTY: Faculty of Sports and Exercise Science
# PREMISE: Crouch at the blocks. React to the starter's gun (avoid false starts!).
#          Once you start, it becomes a high-speed side-scrolling runner
#          like the Google Chrome Dino game! Tap to jump over hurdles
#          and cross the finish line to win!
#
# SCENE SETUP (build this in the Godot editor):
# -----------------------------------------------
#   SprintStart  (Node2D)                          <- root, attach SprintStart.gd
#   ├── BackgroundSky  (TextureRect)               <- stadiumUm.png; Expand Mode: Ignore Size; Full Rect
#   │     Replaces the old stadium_bg.jpg + TrackClay + LaneLine1-4 ColorRects.
#   │     The UM stadium image has the track lanes already drawn in.
#   ├── StarterBubble  (Label)                     <- name MUST be "StarterBubble"
#   │     font_size=32; offset_left=140, right=1140, top=60, bottom=130
#   ├── SignalLights  (HBoxContainer)              <- name MUST be "SignalLights"; separation=40; centered
#   │     offset: left=490, top=150, right=790, bottom=220
#   │     ├── RedLight    (ColorRect)              <- name MUST be "RedLight";    min 50×50
#   │     │   └── LightGlow  (ReferenceRect)       <- border glow; anchors Full Rect; border 3px white
#   │     ├── YellowLight (ColorRect)              <- name MUST be "YellowLight"; min 50×50
#   │     │   └── LightGlow  (ReferenceRect)
#   │     └── GreenLight  (ColorRect)              <- name MUST be "GreenLight";  min 50×50
#   │         └── LightGlow  (ReferenceRect)
#   ├── ReactionLabel  (Label)                     <- name MUST be "ReactionLabel"; font_size=28; centered
#   │     offset: left=340, top=230, right=940, bottom=350
#   ├── RivalRunner  (Node2D)                      <- name MUST be "RivalRunner"; attach Runner.gd
#   │     position=(300, 440); size=(70,70)        <- starts AHEAD of player
#   │     ├── Sprite  (Sprite2D)                   <- name MUST be "Sprite"; west.png; flip_h=true
#   │     │     centered=true; scale=(3.0, 3.0)    <- pixel art scaled up
#   │     └── RivalLabel  (Label)                  <- "Rival (API)"; font_size=12; centered
#   ├── PlayerRunner  (Node2D)                     <- name MUST be "PlayerRunner"; attach Runner.gd
#   │     position=(160, 520); size=(75,75)
#   │     ├── Sprite  (Sprite2D)                   <- name MUST be "Sprite"; south-east.png initially
#   │     │     centered=true; scale=(3.0, 3.0)    <- pixel art scaled up; no hframes
#   │     └── PlayerLabel  (Label)                 <- "You (FSSS)"; font_size=13; centered; color cyan
#   ├── MuzzleFlash  (CPUParticles2D)              <- name MUST be "MuzzleFlash"
#   │     position=(160,390); one_shot=true; emitting=false; amount=40; spread=80
#   ├── SpeedStreaks  (CPUParticles2D)             <- name MUST be "SpeedStreaks"
#   │     position=(160,560); emitting=false; direction=(-1,0); amount=15; lifetime=0.5
#   └── AudioPlayer  (AudioStreamPlayer)           <- name MUST be "AudioPlayer"; volume_db=-2
# =============================================================================

extends MiniGameBase

# ---------------------------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------------------------
const TIME_MARKS: float = 1.0
const TIME_SET: float = 2.2
const WIN_REACTION_THRESHOLD: float = 400.0 # ms reaction window to start sprint

# Physics Constants
const GRAVITY: float = 1800.0
const JUMP_FORCE: float = -750.0
const GROUND_Y: float = 530.0 # Track floor Y matching stadiumUm.png lane position
const TRACK_SCROLL_SPEED: float = 900.0 # Horizontal scroll velocity (px/s)

const COLOR_SIGNAL_OFF: Color = Color(0.18, 0.18, 0.22, 1.0)
const COLOR_RED: Color = Color(0.95, 0.2, 0.2, 1.0)
const COLOR_YELLOW: Color = Color(0.95, 0.8, 0.1, 1.0)
const COLOR_GREEN: Color = Color(0.2, 0.85, 0.3, 1.0)

# ---------------------------------------------------------------------------
# GAME STATES
# ---------------------------------------------------------------------------
enum GameState {
	BEFORE_START,
	MARKS,
	SET,
	GUN_FIRED,
	SPRINTING,  # Side-scrolling runner active!
	TRIPPED,    # Hit a hurdle
	FINISHED
}

# ---------------------------------------------------------------------------
# RUNTIME STATE
# ---------------------------------------------------------------------------
var _elapsed_time: float = 0.0
var _state: GameState = GameState.BEFORE_START
var _gun_fire_time: float = 0.0
var _gun_fire_msec: int = 0
var _reaction_msec: int = 0

# Jump Physics
var _velocity_y: float = 0.0
var _is_grounded: bool = true

# Obstacle Spawning (relative to the scrolling map)
var _hurdle_positions: Array[float] = [1400.0, 2000.0, 2600.0] # Spawn X coordinates
var _hurdles: Array[ColorRect] = []
var _finish_line: ColorRect = null
var _finish_x: float = 3200.0 # Coordinate of the finish line

# Node references
@onready var starter_bubble: Label = $StarterBubble
@onready var signal_red: ColorRect = $SignalLights/RedLight
@onready var signal_yellow: ColorRect = $SignalLights/YellowLight
@onready var signal_green: ColorRect = $SignalLights/GreenLight
@onready var player_runner: Node2D = $PlayerRunner
@onready var rival_runner: Node2D = $RivalRunner
@onready var player_sprite: Sprite2D = $PlayerRunner/Sprite
@onready var rival_sprite: Sprite2D = $RivalRunner/Sprite
@onready var muzzle_flash: CPUParticles2D = $MuzzleFlash
@onready var speed_streaks: CPUParticles2D = $SpeedStreaks
@onready var reaction_label: Label = $ReactionLabel
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

# Pixel art sprite textures — loaded at runtime per the spec
var _tex_crouch: Texture2D    # south-east.png: player crouching at starting blocks
var _tex_sprint: Texture2D    # east.png:       player sprinting right
var _tex_rival:  Texture2D    # west.png:       rival running (displayed flip_h=true)

# Sound files
@onready var sfx_gun = preload("res://minigames/sprint_start/assets/gun_shot.wav")
@onready var sfx_marks = preload("res://minigames/sprint_start/assets/marks.wav")
@onready var sfx_set = preload("res://minigames/sprint_start/assets/set.wav")
@onready var sfx_false_start = preload("res://minigames/sprint_start/assets/false_start.wav")

# ---------------------------------------------------------------------------
# MINIGAMEBASE CONTRACT
# ---------------------------------------------------------------------------
func setup() -> void:
	base_duration = 7.5
	instruction_text = "React & Jump!"

	# Load pixel art textures
	_tex_crouch = load("res://minigames/sprint_start/assets/south-east.png")
	_tex_sprint = load("res://minigames/sprint_start/assets/east.png")
	_tex_rival  = load("res://minigames/sprint_start/assets/west.png")

	# Apply initial textures: player crouches, rival faces right (flip_h)
	player_sprite.texture = _tex_crouch
	player_sprite.flip_h  = false
	rival_sprite.texture  = _tex_rival
	rival_sprite.flip_h   = true   # west.png faces left; flip so rival runs rightward

	# Randomize gun shot interval (between 3.3 and 4.2 seconds)
	_gun_fire_time = randf_range(3.3, 4.2)

	# Initialize signals to off
	signal_red.color = COLOR_SIGNAL_OFF
	signal_yellow.color = COLOR_SIGNAL_OFF
	signal_green.color = COLOR_SIGNAL_OFF

	starter_bubble.text = "STARTER COOLS DOWN..."
	reaction_label.visible = false
	speed_streaks.emitting = false
	muzzle_flash.emitting = false

	# Position runners: rival starts one lane ahead
	player_runner.position = Vector2(160.0, GROUND_Y)
	rival_runner.position  = Vector2(300.0, GROUND_Y - 80.0)

	_spawn_hurdles_and_finish()

# ---------------------------------------------------------------------------
# DYNAMIC OBSTACLE SPAWNING
# ---------------------------------------------------------------------------
func _spawn_hurdles_and_finish() -> void:
	# Spawn athletic hurdles programmatically
	for x_pos in _hurdle_positions:
		var hurdle = ColorRect.new()
		# Bright athletics yellow — stands out clearly against the red clay track
		hurdle.size = Vector2(30.0, 55.0)
		hurdle.position = Vector2(x_pos, GROUND_Y + 20.0) # Placed on the track lane
		hurdle.color = Color(1.0, 0.85, 0.0, 1.0)  # athletics yellow

		# Black centre stripe for contrast
		var stripe = ColorRect.new()
		stripe.size = Vector2(30.0, 10.0)
		stripe.position = Vector2(0.0, 22.0)  # centred on the bar
		stripe.color = Color(0.05, 0.05, 0.05, 1.0)  # near-black
		hurdle.add_child(stripe)

		add_child(hurdle)
		_hurdles.append(hurdle)

	# Spawn checkered Finish Line
	_finish_line = ColorRect.new()
	_finish_line.size = Vector2(25.0, 180.0)
	_finish_line.position = Vector2(_finish_x, GROUND_Y - 80.0)
	_finish_line.color = Color(1, 1, 1) # base white

	# Add black checkers onto the finish line
	for i in range(6):
		if i % 2 == 0:
			var checker = ColorRect.new()
			checker.size = Vector2(25.0, 30.0)
			checker.position = Vector2(0.0, i * 30.0)
			checker.color = Color(0, 0, 0)
			_finish_line.add_child(checker)

	add_child(_finish_line)

# ---------------------------------------------------------------------------
# INPUT HANDLER
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if _finished:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 1. Starting Gun Phase Clicks
		if _state == GameState.BEFORE_START or _state == GameState.MARKS or _state == GameState.SET:
			_trigger_false_start()

		elif _state == GameState.GUN_FIRED:
			_trigger_sprint_start()

		# 2. Side-Scrolling Running Phase Clicks -> JUMP!
		elif _state == GameState.SPRINTING:
			if _is_grounded:
				_jump()

# ---------------------------------------------------------------------------
# PHYSICS & SPRINT MOTION LOOP
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	_elapsed_time += delta * time_scale

	# Update Runner Animations
	_update_runner_animations(delta)

	# A. Starter Sequence
	_update_starter_sequence()

	# B. Gravity and Jump Physics
	if not _is_grounded and (_state == GameState.SPRINTING or _state == GameState.TRIPPED):
		_velocity_y += GRAVITY * delta * time_scale
		player_runner.position.y += _velocity_y * delta * time_scale

		# Ground landing check
		if player_runner.position.y >= GROUND_Y:
			player_runner.position.y = GROUND_Y
			_velocity_y = 0.0
			_is_grounded = true

	# C. Scrolling Sprinter Runner Physics
	if _state == GameState.SPRINTING:
		# Scroll Hurdles to the left
		for hurdle in _hurdles:
			hurdle.position.x -= TRACK_SCROLL_SPEED * delta * time_scale

		# Scroll Finish Line
		_finish_line.position.x -= TRACK_SCROLL_SPEED * delta * time_scale

		# Rival runs at a steady pace (gradually moves across screen)
		rival_runner.position.x += 160.0 * delta * time_scale

		# Check Collisions with active hurdles
		_check_hurdle_collisions()

		# Check Finish Line cross
		if _finish_line.position.x <= player_runner.position.x:
			_trigger_victory_finish()

	# D. Timeout Safeguard
	if _elapsed_time >= base_duration - 0.15 and not _finished:
		if _state == GameState.SPRINTING:
			# Ran out of time, rival crossed first
			_trigger_too_slow_finish()
		else:
			lose()

# ---------------------------------------------------------------------------
# STARTER TIMELINE SEQUENCE
# ---------------------------------------------------------------------------
func _update_starter_sequence() -> void:
	if _finished:
		return

	# State A: Move to starting blocks (ON YOUR MARKS)
	if _state == GameState.BEFORE_START and _elapsed_time >= TIME_MARKS:
		_state = GameState.MARKS
		starter_bubble.text = "ON YOUR MARKS..."
		signal_red.color = COLOR_RED
		audio_player.stream = sfx_marks
		audio_player.play()

	# State B: Get ready on starting blocks (SET)
	elif _state == GameState.MARKS and _elapsed_time >= TIME_SET:
		_state = GameState.SET
		starter_bubble.text = "SET..."
		signal_yellow.color = COLOR_YELLOW

		# Crouch tilt animation
		create_tween().tween_property(player_runner, "rotation_degrees", -5.0, 0.3)
		create_tween().tween_property(rival_runner, "rotation_degrees", -5.0, 0.3)

		audio_player.stream = sfx_set
		audio_player.play()

	# State C: Fire starting gun! (BANG!)
	elif _state == GameState.SET and _elapsed_time >= _gun_fire_time:
		_state = GameState.GUN_FIRED
		_gun_fire_msec = Time.get_ticks_msec()

		starter_bubble.text = "💥 BANG!!! 💥"
		signal_green.color = COLOR_GREEN

		# Reset rotation
		player_runner.rotation_degrees = 0
		rival_runner.rotation_degrees = 0

		# Muzzle flash particle burst
		muzzle_flash.emitting = true

		# Play gun shot
		audio_player.stream = sfx_gun
		audio_player.play()

		# Rival immediately takes off with a standard reaction delay
		var rival_delay: float = randf_range(0.15, 0.22)
		create_tween().tween_callback(func():
			if _state == GameState.GUN_FIRED or _state == GameState.SPRINTING:
				# Rival sprinters takes off
				rival_runner.position.x = 220.0
		).set_delay(rival_delay)

# ---------------------------------------------------------------------------
# SPRINTING MECHANICAL LOGIC
# ---------------------------------------------------------------------------

func _jump() -> void:
	_is_grounded = false
	_velocity_y = JUMP_FORCE

	# Keep the sprint texture while airborne (single-frame sprite, no frame cycling)
	player_sprite.texture = _tex_sprint

	# Play spring sound
	audio_player.stream = sfx_marks
	audio_player.play()

func _check_hurdle_collisions() -> void:
	# Define player bounding box
	var player_box = Rect2(player_runner.position, player_runner.size)

	for hurdle in _hurdles:
		# Define hurdle bounding box
		var hurdle_box = Rect2(hurdle.position, hurdle.size)

		# Check overlap (AABB intersection)
		if player_box.intersects(hurdle_box):
			_trigger_trip()
			return

# ---------------------------------------------------------------------------
# SPRINT OUTCOMES
# ---------------------------------------------------------------------------

## Clicked before gun (False Start DQ)
func _trigger_false_start() -> void:
	_state = GameState.FINISHED
	starter_bubble.text = "🚫 FALSE START! DISQUALIFIED! 🚫"
	reaction_label.text = "TOO EARLY! 🟥"
	reaction_label.add_theme_color_override("font_color", COLOR_RED)
	reaction_label.visible = true

	signal_red.color = COLOR_RED
	signal_yellow.color = COLOR_RED
	signal_green.color = COLOR_SIGNAL_OFF

	audio_player.stream = sfx_false_start
	audio_player.play()

	# Shake player
	var shake: Tween = create_tween()
	for i in range(8):
		shake.tween_property(player_runner, "position:x", player_runner.position.x + randf_range(-10, 10), 0.03)

	lose()

## Explode off blocks (Transition to Side-scroller!)
func _trigger_sprint_start() -> void:
	_state = GameState.SPRINTING
	_reaction_msec = Time.get_ticks_msec() - _gun_fire_msec

	# Swap player to full sprint sprite
	player_sprite.texture = _tex_sprint

	starter_bubble.text = "🏃 SPRINT!!! JUMP OVER HURDLES! 🏃"
	instruction_text = "Jump!"

	# Formulate reaction feedback
	var rank_text: String = ""
	if _reaction_msec < 130:
		rank_text = "GODLIKE SPEED! ⚡"
	elif _reaction_msec < 250:
		rank_text = "PERFECT START! 🔥"
	else:
		rank_text = "GOOD START! 👍"

	reaction_label.text = "Reaction: %d ms\n%s" % [_reaction_msec, rank_text]
	reaction_label.add_theme_color_override("font_color", COLOR_GREEN)
	reaction_label.visible = true

	# Emit speed particles
	speed_streaks.emitting = true

	# Hide reaction label after a brief moment to clear the screen
	create_tween().tween_property(reaction_label, "modulate:a", 0.0, 1.2).set_delay(1.0)

## Player tripped on a hurdle (Lose)
func _trigger_trip() -> void:
	_state = GameState.FINISHED
	speed_streaks.emitting = false

	starter_bubble.text = "💥 TRIPPED! CRASHED! 💥"
	reaction_label.text = "CRASH! 🟥"
	reaction_label.modulate.a = 1.0 # Reveal
	reaction_label.add_theme_color_override("font_color", COLOR_RED)
	reaction_label.visible = true

	# Play trip/buzzer sound
	audio_player.stream = sfx_false_start
	audio_player.play()

	# Spin player runner and slide backwards
	var spin: Tween = create_tween()
	spin.set_parallel(true)
	spin.tween_property(player_runner, "rotation_degrees", 90.0, 0.4)
	spin.tween_property(player_runner, "position:x", player_runner.position.x - 120.0, 0.4)
	spin.tween_property(player_runner, "position:y", GROUND_Y + 25.0, 0.4)

	# Transition to lose
	create_tween().tween_callback(func(): lose()).set_delay(0.9)

## Crossed Checkered Line (Win)
func _trigger_victory_finish() -> void:
	_state = GameState.FINISHED
	speed_streaks.emitting = false

	starter_bubble.text = "🏆 WINNER!!! 🏆"
	reaction_label.text = "CROSS FINISH LINE! ✓"
	reaction_label.modulate.a = 1.0
	reaction_label.add_theme_color_override("font_color", COLOR_GREEN)
	reaction_label.visible = true

	# Sprint past the rival off-screen!
	var sprint: Tween = create_tween()
	sprint.tween_property(player_runner, "position:x", 1300.0, 0.6)

	# Victory cheer sound
	audio_player.stream = sfx_gun
	audio_player.play()

	create_tween().tween_callback(func(): win()).set_delay(0.9)

## Too Slow (Timeout Safeguard)
func _trigger_too_slow_finish() -> void:
	_state = GameState.FINISHED
	speed_streaks.emitting = false

	starter_bubble.text = "🐢 TOO SLOW! RIVAL WON! 🐢"
	reaction_label.text = "TOO SLOW! 🟥"
	reaction_label.modulate.a = 1.0
	reaction_label.add_theme_color_override("font_color", COLOR_RED)
	reaction_label.visible = true

	# Rival sprints off screen
	create_tween().tween_property(rival_runner, "position:x", 1300.0, 0.6)

	audio_player.stream = sfx_false_start
	audio_player.play()

	create_tween().tween_callback(func(): lose()).set_delay(0.8)

# ---------------------------------------------------------------------------
# ANIMATION UPDATES
# Single-frame pixel art sprites: swap textures per state instead of frame cycling.
# ---------------------------------------------------------------------------
func _update_runner_animations(_delta: float) -> void:
	# --- Player sprite ---
	match _state:
		GameState.BEFORE_START, GameState.MARKS, GameState.SET:
			# Crouching at starting blocks
			player_sprite.texture = _tex_crouch
		GameState.GUN_FIRED, GameState.SPRINTING, GameState.TRIPPED, GameState.FINISHED:
			# Full sprint (also used while airborne and after finish)
			player_sprite.texture = _tex_sprint

	# --- Rival sprite ---
	# Rival always uses west.png flipped — texture never changes, only position moves
	# (texture was set once in setup(); nothing to update here)
	pass
