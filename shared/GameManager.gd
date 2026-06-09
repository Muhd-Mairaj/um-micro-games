# =============================================================================
# shared/GameManager.gd
# =============================================================================
# PURPOSE:
#   GameManager is the brain of the game. It:
#     - Shuffles and sequences all mini-games
#     - Injects the correct time_scale before each mini-game loads
#     - Listens for game_won / game_lost signals and reacts
#     - Increases speed every 3 games
#     - Ends the run and shows the result screen
#
# THIS IS THE STARTUP SCENE. Set GameManager.tscn as the Main Scene in:
#   Project → Project Settings → Application → Run → Main Scene
#
# SCENE SETUP (build this in the Godot editor):
# -----------------------------------------------
#   GameManager  (Node)                        <- root node, attach GameManager.gd
#   ├── HUD      (instance of HUD.tscn)        <- drag HUD.tscn into the scene
#   └── MiniGameContainer  (Node2D)            <- empty; games are added here at runtime
#
# Node names must match exactly (case-sensitive).
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
# CONSTANTS — no magic numbers
# ---------------------------------------------------------------------------

## Amount added to time_scale every SPEED_STEP_INTERVAL games.
const SPEED_INCREMENT: float = 0.15

## Games between each speed increase.
const SPEED_STEP_INTERVAL: int = 3

## Seconds to wait after win/lose flash before loading the next game.
const RESULT_PAUSE_DURATION: float = 0.9

# ---------------------------------------------------------------------------
# MINI-GAME REGISTRY
# THE STITCHER: In Week 12, add each finished mini-game path here.
# Paths are case-sensitive on Linux/Mac. Must match the file on disk exactly.
# ---------------------------------------------------------------------------
var minigame_scenes: Array[String] = [
	"res://minigames/bas_um_model_crush/BasUmModelCrush.tscn",
	#"res://minigames/syntax_saviour/SyntaxSaviour.tscn",
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

## Games won this run.
var score: int = 0

## Total games in this run (for the result screen).
var total_played: int = 0

## The currently active mini-game instance.
var current_minigame: MiniGameBase = null

# ---------------------------------------------------------------------------
# LIFECYCLE
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Shuffle so each run plays games in a different order.
	# shuffle() modifies the array in-place.
	minigame_scenes.shuffle()

	# Record total count for the final score screen.
	total_played = minigame_scenes.size()

	# Start the first game.
	_load_next_game()

# ---------------------------------------------------------------------------
# CORE FLOW
# ---------------------------------------------------------------------------

## Loads and starts the next mini-game, or ends the run if all are done.
func _load_next_game() -> void:
	# If we've played everything, show the result screen.
	if current_index >= minigame_scenes.size():
		_end_run()
		return

	var scene_path: String = minigame_scenes[current_index]

	# load() (not preload()) so new scene paths can be added to the registry
	# without any code changes in this file.
	var scene_resource: PackedScene = load(scene_path)

	# Safety: bad path → print error, skip this game.
	if scene_resource == null:
		push_error("[GameManager] Could not load scene: " + scene_path)
		current_index += 1
		_load_next_game()
		return

	# instantiate() is the Godot 4 equivalent of Godot 3's instance().
	var instance: Node = scene_resource.instantiate()

	# Cast to MiniGameBase for typed access to its properties.
	current_minigame = instance as MiniGameBase

	if current_minigame == null:
		push_error("[GameManager] Scene does not extend MiniGameBase: " + scene_path)
		instance.queue_free()
		current_index += 1
		_load_next_game()
		return

	# Inject time_scale BEFORE adding to the scene tree so setup() sees it.
	current_minigame.time_scale = time_scale

	# Add to the container so it becomes part of the scene tree.
	minigame_container.add_child(current_minigame)

	# Connect signals — GameManager reacts to win/lose from the mini-game.
	current_minigame.game_won.connect(_on_won)
	current_minigame.game_lost.connect(_on_lost)

	# Start the HUD timer with the speed-adjusted duration.
	hud.start(current_minigame.actual_duration())

	# Show the instruction hint for this game.
	hud.set_instruction(current_minigame.instruction_text)

## Called when the active mini-game emits game_won.
func _on_won() -> void:
	score += 1
	hud.show_result(true)
	# await pauses this coroutine until the timer fires, without blocking other nodes.
	await get_tree().create_timer(RESULT_PAUSE_DURATION).timeout
	_next()

## Called when the active mini-game emits game_lost.
func _on_lost() -> void:
	hud.show_result(false)
	await get_tree().create_timer(RESULT_PAUSE_DURATION).timeout
	_next()

## Cleans up the current mini-game, advances the counter, speeds up if needed,
## then loads the next game.
func _next() -> void:
	# queue_free() defers deletion to the end of the frame (safer than free()).
	if current_minigame != null:
		current_minigame.queue_free()
		current_minigame = null

	current_index += 1

	# Speed up every SPEED_STEP_INTERVAL games.
	# `%` is modulo — when remainder is 0, we've hit a step boundary.
	if current_index % SPEED_STEP_INTERVAL == 0:
		time_scale += SPEED_INCREMENT
		print("[GameManager] Speed up! time_scale = ", time_scale)

	_load_next_game()

## Called after all mini-games have been played.
func _end_run() -> void:
	print("[GameManager] Run complete! Score: ", score, " / ", total_played)

	# TODO (Week 12 / The Stitcher): Replace print with a real ResultScreen transition.
	# Uncomment and adapt when ResultScreen.tscn is ready:
	#
	#   var result_scene = load("res://shared/ResultScreen.tscn").instantiate()
	#   result_scene.set_score(score, total_played)
	#   get_tree().root.add_child(result_scene)
	#   queue_free()
	pass
