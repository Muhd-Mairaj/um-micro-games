# =============================================================================
# shared/GameManager.gd
# =============================================================================
# PURPOSE:
#   GameManager is the state machine and brain of the game:
#     TITLE -> INTRO -> MAP -> (play any game) -> MAP -> ... -> GRADUATION
#
#   Instead of a random survival run, the player picks games from a faculty MAP
#   in any order. Winning a game marks that faculty cleared; losing just returns
#   to the map to retry (no lives / no drop-out). Clearing all 12 -> Graduation.
#   The map also has a TEST button that jumps straight to Graduation.
#
# THIS IS THE STARTUP SCENE (Project -> Run -> Main Scene = GameManager.tscn).
# SCENE SETUP (already built - do not restructure):
#   GameManager  (Node)
#   |-- HUD      (instance of HUD.tscn)
#   `-- MiniGameContainer  (Node2D)
# =============================================================================

extends Node

@onready var hud: CanvasLayer = $HUD
@onready var minigame_container: Node2D = $MiniGameContainer

const RESULT_PAUSE_DURATION: float = 0.9
const TOTAL_GAMES: int = 12
const STARTING_LIVES: int = 3

## Shared hearts for the whole run. A lost game costs one; reaching 0 drops out.
var lives: int = STARTING_LIVES
## Scene paths that have been cleared (won). path -> true. The MAP reads this to
## show ticks; clearing all TOTAL_GAMES triggers graduation.
var completed: Dictionary = {}
## The scene path currently being played (so a win marks the right faculty).
var current_path: String = ""
var current_minigame: MiniGameBase = null
## Guard: true while a win/lose result is being processed.
var _result_pending: bool = false

# ---------------------------------------------------------------------------
# LIFECYCLE
# ---------------------------------------------------------------------------

func _ready() -> void:
	hud.visible = false
	hud.timed_out.connect(_on_hud_timed_out)
	_show_title_screen()

func _on_hud_timed_out() -> void:
	# Survival games override lose() to turn a timeout into a win.
	if current_minigame != null:
		current_minigame.lose()

# ---------------------------------------------------------------------------
# TITLE / INTRO
# ---------------------------------------------------------------------------

func _show_title_screen() -> void:
	var scene: PackedScene = load("res://shared/TitleScreen.tscn")
	if scene == null:
		_show_intro_screen()
		return
	var screen: Node = scene.instantiate()
	add_child(screen)
	screen.started.connect(func() -> void:
		screen.queue_free()
		_show_intro_screen()
	)

func _show_intro_screen() -> void:
	var scene: PackedScene = load("res://shared/IntroScreen.tscn")
	if scene == null:
		_show_map_screen()
		return
	var screen: Node = scene.instantiate()
	add_child(screen)
	screen.done.connect(func() -> void:
		screen.queue_free()
		_start_run()
	)

# ---------------------------------------------------------------------------
# MAP (faculty select)
# ---------------------------------------------------------------------------

## Begin a fresh run: full hearts, nothing cleared yet.
func _start_run() -> void:
	lives = STARTING_LIVES
	completed.clear()
	_show_map_screen()

func _show_map_screen() -> void:
	hud.visible = false
	var scene: PackedScene = load("res://shared/MapScreen.tscn")
	if scene == null:
		push_error("[GameManager] MapScreen.tscn not found.")
		return
	var screen: Node = scene.instantiate()
	# Pass current hearts + which games are cleared so the map shows them (set
	# BEFORE add_child so the screen's _ready() can read them).
	screen.set("completed", completed)
	screen.set("lives", lives)
	add_child(screen)
	screen.game_selected.connect(func(path: String) -> void:
		screen.queue_free()
		_start_minigame(path)
	)
	screen.graduate_now.connect(func() -> void:
		screen.queue_free()
		_show_graduation_screen()
	)

# ---------------------------------------------------------------------------
# PLAY A SELECTED GAME
# ---------------------------------------------------------------------------

func _start_minigame(path: String) -> void:
	var res: PackedScene = load(path)
	if res == null:
		push_error("[GameManager] Could not load scene: " + path)
		_show_map_screen()
		return
	var instance: Node = res.instantiate()
	current_minigame = instance as MiniGameBase
	if current_minigame == null:
		push_error("[GameManager] Scene does not extend MiniGameBase: " + path)
		instance.queue_free()
		_show_map_screen()
		return

	current_path = path
	_result_pending = false
	# Map mode plays every game at normal speed (no escalating time_scale).
	current_minigame.time_scale = 1.0
	minigame_container.add_child(current_minigame)
	current_minigame.game_won.connect(_on_won)
	current_minigame.game_lost.connect(_on_lost)

	hud.visible = true
	hud.update_lives(lives)
	hud.update_progress(completed.size(), TOTAL_GAMES)

	# Freeze game logic during the GET READY flash, then start the timer.
	current_minigame.set_process(false)
	current_minigame.set_physics_process(false)
	hud.set_instruction(current_minigame.instruction_text)
	await hud.show_get_ready(current_minigame.instruction_text)
	if not is_instance_valid(current_minigame):
		return
	current_minigame.set_process(true)
	current_minigame.set_physics_process(true)
	hud.start(current_minigame.actual_duration())

func _on_won() -> void:
	if _result_pending:
		return
	_result_pending = true
	completed[current_path] = true
	hud.show_result(true)
	hud.update_progress(completed.size(), TOTAL_GAMES)
	await get_tree().create_timer(RESULT_PAUSE_DURATION).timeout
	if not is_instance_valid(self):
		return
	_after_game()

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
	_cleanup_current_minigame()
	if lives <= 0:
		_show_dropout_screen()   # out of hearts -> game over
	else:
		_show_map_screen()       # still alive -> back to the map to retry

func _after_game() -> void:
	_cleanup_current_minigame()
	if completed.size() >= TOTAL_GAMES:
		_show_graduation_screen()
	else:
		_show_map_screen()

# ---------------------------------------------------------------------------
# GRADUATION
# ---------------------------------------------------------------------------

func _show_graduation_screen() -> void:
	hud.visible = false
	var scene: PackedScene = load("res://shared/GraduationScreen.tscn")
	if scene == null:
		push_error("[GameManager] GraduationScreen.tscn not found.")
		return
	var screen: Node = scene.instantiate()
	# Grade reflects the hearts left after clearing all 12.
	screen.set("lives_remaining", clampi(lives, 1, 3))
	add_child(screen)
	screen.play_again.connect(func() -> void:
		screen.queue_free()
		_start_run()
	)

func _show_dropout_screen() -> void:
	hud.visible = false
	var scene: PackedScene = load("res://shared/DropOutScreen.tscn")
	if scene == null:
		push_error("[GameManager] DropOutScreen.tscn not found.")
		return
	var screen: Node = scene.instantiate()
	add_child(screen)
	screen.play_again.connect(func() -> void:
		screen.queue_free()
		_start_run()
	)

func _cleanup_current_minigame() -> void:
	if current_minigame != null:
		current_minigame.queue_free()
		current_minigame = null
	current_path = ""
