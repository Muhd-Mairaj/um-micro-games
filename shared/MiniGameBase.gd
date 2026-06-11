# =============================================================================
# shared/MiniGameBase.gd
# =============================================================================
# PURPOSE:
#   This is the BASE CLASS that every mini-game must extend.
#   Think of it like an abstract base class in Python.
#   It defines the "contract" — the methods and signals that the GameManager
#   relies on to work with every mini-game, no matter who wrote it.
#
# HOW TO USE (in your mini-game script):
#   extends MiniGameBase
#
#   func setup():
#       base_duration = 7.0
#       instruction_text = "Do the thing!"
#       # connect your buttons, randomise your scene, etc.
#
#   func _on_correct_answer():
#       win()   # That's it. GameManager handles everything else.
#
#   func _on_wrong_answer():
#       lose()
#
# DO NOT:
#   - Override _ready(). Override setup() instead.
#   - Call win() or lose() inside setup(). GameManager connects signals after
#     the scene enters the tree, so any emit during setup() will be missed.
#   - Call win() or lose() more than once - the guard handles it, but avoid it.
#   - Create your own timer. The HUD manages the countdown.
#   - Call get_tree().change_scene_to_*(). GameManager handles transitions.
# =============================================================================

# GDScript uses `class_name` to register this type globally in the project.
# This means teammates can write `extends MiniGameBase` without any import.
class_name MiniGameBase

# `extends Node2D` means this node can exist in 2D space and has a Transform.
# All mini-game root nodes should be Node2D (or a subclass).
extends Node2D

# ---------------------------------------------------------------------------
# SIGNALS
# Signals are Godot's event system — similar to callbacks or events in Python.
# When you call win() or lose(), these signals fire and GameManager responds.
# ---------------------------------------------------------------------------

# Emitted when the player completes the mini-game successfully.
signal game_won

# Emitted when the player fails (wrong input or time ran out).
signal game_lost

# ---------------------------------------------------------------------------
# EXPORTED VARIABLES
# `@export` makes a variable editable in the Godot Inspector panel.
# Teammates can tweak these in the editor without touching code.
# ---------------------------------------------------------------------------

## How long this mini-game lasts at normal speed (time_scale = 1.0).
## Set this in your setup() method. Recommended range 5.0 to 15.0 seconds
## (per README.md); several games use 12-15s.
@export var base_duration: float = 10.0

## One-line hint shown in the HUD before the mini-game starts.
## Override this string in setup() to tell the player what to do.
## Example: "Find the syntax error!" or "Find YOUR blue slippers!"
@export var instruction_text: String = "Complete the task!"

# ---------------------------------------------------------------------------
# INTERNAL / FRAMEWORK VARIABLES
# These are set by GameManager — do NOT set them yourself in your mini-game.
# ---------------------------------------------------------------------------

## Speed multiplier set by GameManager. Increases every 3 games.
## You read this via `actual_duration`; do not set it manually.
var time_scale: float = 1.0

## Guard flag: once win() or lose() fires, this becomes true.
## Any further calls to win()/lose() are silently ignored.
## This prevents double-emits from accidental double-taps.
var _finished: bool = false

# ---------------------------------------------------------------------------
# COMPUTED PROPERTY
# GDScript doesn't have Python-style properties, but we can simulate them
# with a function that acts like a getter.
# ---------------------------------------------------------------------------

## Returns the real duration after applying the speed multiplier.
## Formula: base_duration / time_scale
## (Higher time_scale = faster game = shorter actual time.)
## This is read-only — never assign to it.
func actual_duration() -> float:
	# Divide base_duration by the speed scale so faster rounds are shorter.
	return base_duration / time_scale

# ---------------------------------------------------------------------------
# LIFECYCLE METHODS
# ---------------------------------------------------------------------------

## Called automatically by Godot when this node enters the scene tree.
## We call setup() here so teammates override setup(), not _ready().
## This keeps the framework boundary clean and predictable.
func _ready() -> void:
	# Delegate all initialisation to setup(), which teammates override.
	# This way, GameManager's node wiring happens before setup() runs.
	setup()

# ---------------------------------------------------------------------------
# VIRTUAL METHODS — Override these in your mini-game
# ---------------------------------------------------------------------------

## Called once when the scene loads. Put ALL your initialisation here:
##   - Set base_duration (e.g., base_duration = 7.0)
##   - Set instruction_text (e.g., instruction_text = "Find the error!")
##   - Connect button signals to your handler functions
##   - Randomise your scene layout
##
## In Python terms, think of this as your __init__ but for Godot.
func setup() -> void:
	# Empty on purpose — subclasses override this.
	# GDScript virtual methods don't need `pass` but it's fine to add it.
	pass

# ---------------------------------------------------------------------------
# WIN / LOSE — Call these from your mini-game when the outcome is decided
# ---------------------------------------------------------------------------

## Call this when the player succeeds.
## GameManager will hear `game_won`, update the score, flash the result,
## then load the next mini-game automatically.
func win() -> void:
	# Guard: if win() or lose() was already called, do nothing.
	# This prevents a second button tap from firing a second signal.
	if _finished:
		return

	# Mark as done so no further calls get through.
	_finished = true

	# Fire the signal. GameManager is listening and will handle the rest.
	# `emit_signal` is one way; `game_won.emit()` is the modern Godot 4 way.
	game_won.emit()

## Call this when the player fails (wrong choice, time expired, etc.).
## GameManager will hear `game_lost`, flash the failure result,
## then load the next mini-game automatically.
func lose() -> void:
	# Guard: if already finished, ignore this call.
	if _finished:
		return

	# Mark as done.
	_finished = true

	# Emit the loss signal for GameManager to handle.
	game_lost.emit()
