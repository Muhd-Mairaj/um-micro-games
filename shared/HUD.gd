# =============================================================================
# shared/HUD.gd
# =============================================================================
# PURPOSE:
#   The HUD (Heads-Up Display) is a CanvasLayer that floats above every
#   mini-game scene. It owns three pieces of UI:
#     1. TimerBar    — a ProgressBar at the top of the screen counting down.
#     2. ResultLabel — a large centred label showing "NICE! ✓" or "TOO SLOW! ✗"
#     3. InstructionLabel — a smaller label below the bar giving the player a hint.
#
# SCENE SETUP (build this in the Godot editor):
# -----------------------------------------------
#   HUD  (CanvasLayer)                      ← root node, attach HUD.gd here
#   └── MarginContainer                     ← fills entire viewport (anchors: Full Rect)
#       ├── VBoxContainer                   ← stacks children top-to-bottom
#       │   ├── TimerBar  (ProgressBar)     ← name must be exactly "TimerBar"
#       │   └── InstructionLabel  (Label)   ← name must be exactly "InstructionLabel"
#       └── ResultLabel  (Label)            ← name must be exactly "ResultLabel"
#                                              anchors: Center, NOT inside VBoxContainer
#
# DETAILED NODE PROPERTIES:
#   CanvasLayer (root):
#     - Layer: 10  (renders on top of everything)
#
#   TimerBar (ProgressBar):
#     - Anchor Preset: Full Rect → then manually set:
#         anchor_left=0, anchor_right=1, anchor_top=0, anchor_bottom=0
#         offset_bottom = 20   (bar is 20px tall)
#     - min_value = 0.0, max_value = 1.0, value = 1.0
#     - show_percentage = false  (don't display "100%" text)
#
#   InstructionLabel (Label):
#     - Anchor Preset: Top Center
#     - offset_top = 24  (just below the timer bar)
#     - horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
#     - Text: "Complete the task!"  (overridden at runtime)
#     - Theme override: font size ~20
#
#   ResultLabel (Label):
#     - Anchor Preset: Center
#     - horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
#     - vertical_alignment = VERTICAL_ALIGNMENT_CENTER
#     - visible = false  (hidden until win/lose)
#     - Theme override: font size ~72, bold
# =============================================================================

extends CanvasLayer

# ---------------------------------------------------------------------------
# CONSTANTS — no magic numbers anywhere
# ---------------------------------------------------------------------------

## Progress bar thresholds for colour transitions.
## Above this value the bar is green (plenty of time).
const THRESHOLD_GREEN: float = 0.5

## Below this value the bar turns red (danger zone).
const THRESHOLD_RED: float = 0.25

## Colours for the timer bar at each stage.
## Color(r, g, b, a) — values are 0.0–1.0 in Godot.
const COLOR_GREEN:  Color = Color(0.2, 0.85, 0.3, 1.0)   # comfortable
const COLOR_YELLOW: Color = Color(0.95, 0.8, 0.1, 1.0)   # getting tight
const COLOR_RED:    Color = Color(0.95, 0.2, 0.15, 1.0)  # danger

## Colour of the "NICE! ✓" win text.
const COLOR_WIN:  Color = Color(0.2, 0.9, 0.3, 1.0)

## Colour of the "TOO SLOW! ✗" lose text.
const COLOR_LOSE: Color = Color(0.95, 0.2, 0.15, 1.0)

## Text shown in the result label on a win.
const TEXT_WIN:  String = "NICE! ✓"

## Text shown in the result label on a loss.
const TEXT_LOSE: String = "TOO SLOW! ✗"

# ---------------------------------------------------------------------------
# NODE REFERENCES
# @onready runs the right-hand expression the moment _ready() fires.
# `$NodeName` is Godot's shorthand for get_node("NodeName").
# ---------------------------------------------------------------------------

## The horizontal progress bar across the top of the screen.
@onready var timer_bar: ProgressBar = $MarginContainer/VBoxContainer/TimerBar

## The centred label that appears briefly after win or lose.
@onready var result_label: Label = $ResultLabel

## The smaller hint label shown during gameplay.
@onready var instruction_label: Label = $MarginContainer/VBoxContainer/InstructionLabel

# ---------------------------------------------------------------------------
# PRIVATE STATE
# ---------------------------------------------------------------------------

## How long the current round lasts, in seconds. Set by start().
var _duration: float = 0.0

## How many seconds have elapsed since start() was called.
var _elapsed: float = 0.0

## Whether the timer is actively ticking. Toggled by start() and show_result().
var _running: bool = false

## Guard so _on_timeout only fires once per round.
var _timed_out: bool = false

# ---------------------------------------------------------------------------
# PUBLIC API — called by GameManager
# ---------------------------------------------------------------------------

## Begin a new countdown.
## duration — the total time for this round (already adjusted for speed).
func start(duration: float) -> void:
	# Store how long this round lasts.
	_duration = duration

	# Reset elapsed time to zero (fresh start).
	_elapsed = 0.0

	# Clear the timeout guard so a new round can time out.
	_timed_out = false

	# Reset the bar to full (1.0 = 100%).
	timer_bar.value = 1.0

	# Start with the green colour (plenty of time).
	_set_bar_color(COLOR_GREEN)

	# Hide the result label until win/lose fires.
	result_label.visible = false

	# Show the instruction label for the new round.
	instruction_label.visible = true

	# Allow _process to tick.
	_running = true

## Set the one-line hint text shown below the timer bar.
func set_instruction(text: String) -> void:
	instruction_label.text = text
	instruction_label.visible = true

## Called by GameManager after win() or lose() fires on the mini-game.
## Stops the timer visually and displays the appropriate result message.
func show_result(won: bool) -> void:
	# Stop the countdown.
	_running = false

	# Hide the instruction — player doesn't need it anymore.
	instruction_label.visible = false

	# Choose text and colour depending on outcome.
	if won:
		result_label.text = TEXT_WIN
		result_label.add_theme_color_override("font_color", COLOR_WIN)
	else:
		result_label.text = TEXT_LOSE
		result_label.add_theme_color_override("font_color", COLOR_LOSE)

	# Make the result label visible.
	result_label.visible = true

# ---------------------------------------------------------------------------
# GODOT PROCESS LOOP — ticks every frame while _running is true
# ---------------------------------------------------------------------------

## _process is called every frame by Godot (like a game loop tick).
## `delta` is the time in seconds since the last frame — use it to stay
## frame-rate independent (don't just subtract a fixed number each frame).
func _process(delta: float) -> void:
	# Only tick when the timer is active.
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

## Visually stop the timer. Does NOT call lose() — GameManager handles that
## by listening directly to the mini-game's game_lost signal.
## HUD's job is purely visual: stop ticking and optionally show red bar.
func _on_timeout() -> void:
	# Guard so this only runs once even if frames overshoot.
	if _timed_out:
		return
	_timed_out = true

	# Stop the process loop from continuing.
	_running = false

	# Snap the bar to zero so it's visually clear time is up.
	timer_bar.value = 0.0
	_set_bar_color(COLOR_RED)

## Helper: sets the timer bar's fill colour using Godot's theme override system.
## `add_theme_color_override` lets us change a specific theme property at runtime
## without touching the actual Theme resource.
func _set_bar_color(color: Color) -> void:
	# "fill" is the internal name for the filled portion of a ProgressBar.
	timer_bar.add_theme_color_override("fill", color)
