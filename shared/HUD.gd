# =============================================================================
# shared/HUD.gd
# =============================================================================
# PURPOSE:
#   CanvasLayer overlay shown during every mini-game. Owns five UI elements:
#     1. LivesLabel       : remaining lives shown as hearts (e.g. "♥♥♡")
#     2. ProgressLabel    : faculty progress count (e.g. "3/12")
#     3. TimerBar         : countdown progress bar (green > yellow > red)
#     4. InstructionLabel : one-line hint text for the current mini-game
#     5. ResultLabel      : brief "NICE! ✓" or "TOO SLOW! ✗" flash
#
# SCENE SETUP (HUD.tscn node tree):
# -----------------------------------------------
#   HUD  (CanvasLayer)                       <- root; Layer: 10
#   └── MarginContainer                      <- Anchor Preset: Full Rect
#       ├── VBoxContainer                    <- stacks children top-to-bottom
#       │   ├── TopBar  (HBoxContainer)      <- name exactly "TopBar"
#       │   │   ├── LivesLabel  (Label)      <- name exactly "LivesLabel"
#       │   │   │     horizontal_alignment: LEFT; font size: 24
#       │   │   └── ProgressLabel  (Label)   <- name exactly "ProgressLabel"
#       │   │         horizontal_alignment: RIGHT; font size: 24
#       │   │         Container Sizing > Horizontal: Expand + Fill
#       │   ├── TimerBar  (ProgressBar)      <- name exactly "TimerBar"
#       │   │     min_value: 0.0  max_value: 1.0  show_percentage: false
#       │   └── InstructionLabel  (Label)    <- name exactly "InstructionLabel"
#       │         Anchor Preset: Top Center; offset_top: 24
#       │         horizontal_alignment: CENTER; font size: ~20
#       └── ResultLabel  (Label)             <- name exactly "ResultLabel"
#             Anchor Preset: Center (NOT inside VBoxContainer)
#             horizontal_alignment: CENTER; vertical_alignment: CENTER
#             visible: false (shown only on win/lose); font size: ~72, bold
# =============================================================================

extends CanvasLayer

# Emitted when the countdown reaches zero. GameManager listens and calls
# lose() on the current mini-game so the game never hangs on a dead timer.
signal timed_out

# ---------------------------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------------------------

const THRESHOLD_GREEN: float = 0.5
const THRESHOLD_RED:   float = 0.25

const COLOR_GREEN:  Color = Color(0.2,  0.85, 0.3,  1.0)
const COLOR_YELLOW: Color = Color(0.95, 0.8,  0.1,  1.0)
const COLOR_RED:    Color = Color(0.95, 0.2,  0.15, 1.0)
const COLOR_WIN:    Color = Color(0.2,  0.9,  0.3,  1.0)
const COLOR_LOSE:   Color = Color(0.95, 0.2,  0.15, 1.0)
const TEXT_WIN:     String = "NICE! ✓"
const TEXT_LOSE:    String = "TOO SLOW! ✗"

const HEART_FULL:  String = "♥"
const HEART_EMPTY: String = "♡"
const MAX_LIVES:   int    = 3

# ---------------------------------------------------------------------------
# NODE REFERENCES
# @onready runs the right-hand expression the moment _ready() fires.
# `$NodeName` is Godot's shorthand for get_node("NodeName").
# ---------------------------------------------------------------------------

@onready var timer_bar:         ProgressBar = $MarginContainer/VBoxContainer/TimerBar
@onready var result_label:      Label       = $ResultLabel
@onready var instruction_label: Label       = $MarginContainer/VBoxContainer/InstructionLabel
@onready var lives_label:       Label       = $MarginContainer/VBoxContainer/TopBar/LivesLabel
@onready var progress_label:    Label       = $MarginContainer/VBoxContainer/TopBar/ProgressLabel

# ---------------------------------------------------------------------------
# PRIVATE STATE
# ---------------------------------------------------------------------------

var _duration:  float = 0.0
var _elapsed:   float = 0.0
var _running:   bool  = false
var _timed_out: bool  = false

# ---------------------------------------------------------------------------
# PUBLIC API - called by GameManager
# ---------------------------------------------------------------------------

## Begin a new countdown.
## duration - the total time for this round (already adjusted for speed).
func start(duration: float) -> void:
	_duration  = duration
	_elapsed   = 0.0
	_timed_out = false
	timer_bar.value           = 1.0
	result_label.visible      = false
	instruction_label.visible = true
	_set_bar_color(COLOR_GREEN)
	_running = true

## Set the one-line hint text shown below the timer bar.
func set_instruction(text: String) -> void:
	instruction_label.text    = text
	instruction_label.visible = true

## Called by GameManager after win() or lose() fires on the mini-game.
## Stops the timer visually and displays the appropriate result message.
func show_result(won: bool) -> void:
	_running                  = false
	instruction_label.visible = false
	if won:
		result_label.text = TEXT_WIN
		result_label.add_theme_color_override("font_color", COLOR_WIN)
	else:
		result_label.text = TEXT_LOSE
		result_label.add_theme_color_override("font_color", COLOR_LOSE)
	result_label.visible = true

func update_lives(lives_remaining: int) -> void:
	var text: String = ""
	for i in range(MAX_LIVES):
		text += HEART_FULL if i < lives_remaining else HEART_EMPTY
	lives_label.text = text

func update_progress(progress: int, total: int) -> void:
	progress_label.text = "%d/%d" % [progress, total]

# ---------------------------------------------------------------------------
# PROCESS LOOP
# ---------------------------------------------------------------------------

## _process is called every frame by Godot (like a game loop tick).
## `delta` is the time in seconds since the last frame - use it to stay
## frame-rate independent (don't just subtract a fixed number each frame).
func _process(delta: float) -> void:
	if not _running:
		return

	# Accumulate elapsed time.
	_elapsed += delta

	# Calculate how much time is left as a 0.0–1.0 fraction.
	# Clamp prevents it going below 0 if a frame overshoots.
	var fraction: float = clamp(1.0 - (_elapsed / _duration), 0.0, 1.0)

	# Update the progress bar display.
	timer_bar.value = fraction

	# Update the bar colour based on how much time remains.
	if fraction > THRESHOLD_GREEN:
		_set_bar_color(COLOR_GREEN)
	elif fraction > THRESHOLD_RED:
		_set_bar_color(COLOR_YELLOW)
	else:
		_set_bar_color(COLOR_RED)

	# Check if time has run out.
	if _elapsed >= _duration:
		_on_timeout()

# ---------------------------------------------------------------------------
# PRIVATE HELPERS
# ---------------------------------------------------------------------------

## Visually stop the timer. Does NOT call lose() - GameManager handles that
## by listening directly to the mini-game's game_lost signal.
## HUD's job is purely visual: stop ticking and optionally show red bar.
func _on_timeout() -> void:
	if _timed_out:
		return
	_timed_out = true
	_running   = false
	timer_bar.value = 0.0
	_set_bar_color(COLOR_RED)
	timed_out.emit()

## Helper: sets the timer bar's fill colour using Godot's theme override system.
## `add_theme_color_override` lets us change a specific theme property at runtime
## without touching the actual Theme resource.
func _set_bar_color(color: Color) -> void:
	# "fill" is the internal name for the filled portion of a ProgressBar.
	timer_bar.add_theme_color_override("fill", color)
