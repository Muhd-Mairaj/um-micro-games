# =============================================================================
# shared/GameManager.gd
# =============================================================================
# PURPOSE:
#   GameManager is the state machine and brain of the game. It runs through:
#     TITLE → INTRO → PLAYING → (DROPOUT | GRADUATION)
#
#   It shuffles and sequences mini-games, manages lives (3♥) and faculty
#   progress (0/12), injects time_scale, and transitions to result screens.
#
# THIS IS THE STARTUP SCENE. Set GameManager.tscn as the Main Scene in:
#   Project → Project Settings → Application → Run → Main Scene
#
# SCENE SETUP (already built - do not restructure):
# -----------------------------------------------
#   GameManager  (Node)
#   ├── HUD      (instance of HUD.tscn)
#   └── MiniGameContainer  (Node2D)
# =============================================================================

extends Node

# ---------------------------------------------------------------------------
# NODE REFERENCES
# @onready resolves these the moment _ready() fires.
# $NodeName is Godot shorthand for get_node("NodeName").
# ---------------------------------------------------------------------------

## The HUD overlay child (instanced from HUD.tscn).
@onready var hud: CanvasLayer = $HUD

## Container where mini-game instances are added as children at runtime.
@onready var minigame_container: Node2D = $MiniGameContainer

# ---------------------------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------------------------

const SPEED_INCREMENT: float = 0.15
const SPEED_STEP_INTERVAL: int = 3
const RESULT_PAUSE_DURATION: float = 0.9
const STARTING_LIVES: int = 3

# ---------------------------------------------------------------------------
# MINI-GAME REGISTRY
# THE STITCHER: In Week 12, add each finished mini-game path here.
# ---------------------------------------------------------------------------
var minigame_scenes: Array[String] = [
	"res://minigames/syntax_saviour/SyntaxSaviour.tscn",
	"res://minigames/cavity_chase/CavityChase.tscn",
	"res://minigames/phone_down/PhoneDown.tscn",
	# --- THE STITCHER ADDS LINES HERE IN WEEK 12 ---
]

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------

## Index into minigame_scenes for the current game.
var current_index: int = 0

## Speed multiplier. Starts at 1.0, increases over time.
## actual_duration = base_duration / time_scale.
var time_scale: float = 1.0
var lives: int = STARTING_LIVES
var faculty_progress: int = 0
var total_games: int = 0
var current_minigame: MiniGameBase = null
# Guard: true while a win/lose result is being processed. Prevents a second
# signal from the same mini-game starting a concurrent _on_won/_on_lost coroutine.
var _result_pending: bool = false

# ---------------------------------------------------------------------------
# LIFECYCLE
# ---------------------------------------------------------------------------

func _ready() -> void:
	hud.visible = false
	hud.timed_out.connect(_on_hud_timed_out)
	_show_title_screen()

func _on_hud_timed_out() -> void:
	if current_minigame != null:
		current_minigame.lose()

# ---------------------------------------------------------------------------
# SCREEN TRANSITIONS
# Each helper loads a screen scene, adds it as a child, and connects its
# signal. If the .tscn hasn't been built yet, it falls back gracefully.
# ---------------------------------------------------------------------------

func _show_title_screen() -> void:
	var scene: PackedScene = load("res://shared/TitleScreen.tscn")
	if scene == null:
		# TitleScreen not built yet - skip straight to intro.
		_show_intro_screen()
		return
	var screen: Node = scene.instantiate()
	add_child(screen)
	screen.started.connect(func():
		screen.queue_free()
		_show_intro_screen()
	)

func _show_intro_screen() -> void:
	var scene: PackedScene = load("res://shared/IntroScreen.tscn")
	if scene == null:
		# IntroScreen not built yet - start immediately.
		_start_game_loop()
		return
	var screen: Node = scene.instantiate()
	add_child(screen)
	screen.done.connect(func():
		screen.queue_free()
		_start_game_loop()
	)

func _show_dropout_screen() -> void:
	hud.visible = false
	var scene: PackedScene = load("res://shared/DropOutScreen.tscn")
	if scene == null:
		push_error("[GameManager] DROPOUT - no lives remaining. DropOutScreen.tscn not found.")
		return
	var screen: Node = scene.instantiate()
	add_child(screen)
	screen.play_again.connect(func():
		screen.queue_free()
		_show_intro_screen()
	)

func _show_graduation_screen() -> void:
	hud.visible = false
	var scene: PackedScene = load("res://shared/GraduationScreen.tscn")
	if scene == null:
		push_error("[GameManager] GRADUATION - GraduationScreen.tscn not found.")
		return
	var screen: Node = scene.instantiate()
	# Set lives_remaining BEFORE add_child so setup() can read it.
	screen.set("lives_remaining", lives)
	add_child(screen)
	screen.play_again.connect(func():
		screen.queue_free()
		_show_intro_screen()
	)

# ---------------------------------------------------------------------------
# GAME LOOP
# ---------------------------------------------------------------------------

func _start_game_loop() -> void:
	lives = STARTING_LIVES
	faculty_progress = 0
	time_scale = 1.0
	current_index = 0
	minigame_scenes.shuffle()
	total_games = minigame_scenes.size()
	hud.visible = true
	hud.update_lives(lives)
	hud.update_progress(faculty_progress, total_games)
	_load_next_game()

func _load_next_game() -> void:
	# Loop instead of recursing so a run of bad entries can't overflow the stack.
	while current_index < minigame_scenes.size():
		var scene_path: String = minigame_scenes[current_index]
		var scene_resource: PackedScene = load(scene_path)

		if scene_resource == null:
			push_error("[GameManager] Could not load scene: " + scene_path)
			current_index += 1
			continue

		var instance: Node = scene_resource.instantiate()
		current_minigame = instance as MiniGameBase

		if current_minigame == null:
			push_error("[GameManager] Scene does not extend MiniGameBase: " + scene_path)
			instance.queue_free()
			current_index += 1
			continue

		# Inject time_scale BEFORE adding to tree so setup() sees it.
		_result_pending = false
		current_minigame.time_scale = time_scale
		minigame_container.add_child(current_minigame)
		current_minigame.game_won.connect(_on_won)
		current_minigame.game_lost.connect(_on_lost)
		# Freeze game logic while instruction is shown, then start timer.
		current_minigame.set_process(false)
		current_minigame.set_physics_process(false)
		hud.set_instruction(current_minigame.instruction_text)
		await hud.show_get_ready(current_minigame.instruction_text)
		if not is_instance_valid(current_minigame):
			return
		current_minigame.set_process(true)
		current_minigame.set_physics_process(true)
		hud.start(current_minigame.actual_duration())
		return

	_end_run()

func _on_won() -> void:
	if _result_pending:
		return
	_result_pending = true
	faculty_progress += 1
	hud.show_result(true)
	hud.update_progress(faculty_progress, total_games)
	await get_tree().create_timer(RESULT_PAUSE_DURATION).timeout
	if not is_instance_valid(self):
		return
	_next()

func _on_lost() -> void:
	if _result_pending:
		return
	_result_pending = true
	lives -= 1
	hud.show_result(false)
	hud.update_lives(lives)
	await get_tree().create_timer(RESULT_PAUSE_DURATION).timeout
	if not is_instance_valid(self):
		return
	if lives <= 0:
		_cleanup_current_minigame()
		_show_dropout_screen()
	else:
		_next()

func _next() -> void:
	_cleanup_current_minigame()
	current_index += 1
	if current_index % SPEED_STEP_INTERVAL == 0:
		time_scale += SPEED_INCREMENT
		print("[GameManager] Speed up! time_scale = ", time_scale)
	_load_next_game()

func _end_run() -> void:
	# All games played with lives > 0 → graduation.
	_show_graduation_screen()

func _cleanup_current_minigame() -> void:
	if current_minigame != null:
		current_minigame.queue_free()
		current_minigame = null
