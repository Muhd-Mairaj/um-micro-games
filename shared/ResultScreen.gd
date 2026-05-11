# =============================================================================
# shared/ResultScreen.gd
# =============================================================================
# PURPOSE:
#   Shown after all mini-games in a run are complete.
#   Displays the final score and a "Play Again" button.
#
# SCENE SETUP (build this in the Godot editor):
# -----------------------------------------------
#   ResultScreen  (Control)                    <- root, attach ResultScreen.gd
#   └── ColorRect                              <- fills viewport, dark background
#       - Color: Color(0.08, 0.08, 0.12, 1.0)
#       - Anchor Preset: Full Rect
#   └── VBoxContainer                          <- centres the UI vertically
#       - Anchor Preset: Center
#       - alignment: ALIGNMENT_CENTER
#       - custom_minimum_size: (600, 400)
#       ├── TitleLabel  (Label)                <- "Run Complete!"
#       │     - horizontal_alignment: CENTER
#       │     - theme font_size override: 64
#       ├── ScoreLabel  (Label)                <- "You won X / Y games"
#       │     - name must be exactly "ScoreLabel"
#       │     - horizontal_alignment: CENTER
#       │     - theme font_size override: 36
#       └── PlayAgainButton  (Button)          <- "Play Again"
#             - name must be exactly "PlayAgainButton"
#             - custom_minimum_size: (260, 60)
#             - alignment: CENTER
# =============================================================================

extends Control

# ---------------------------------------------------------------------------
# NODE REFERENCES
# ---------------------------------------------------------------------------

## Label that shows "You won X / Y games".
@onready var score_label: Label = $VBoxContainer/ScoreLabel

## Button that restarts the game.
@onready var play_again_button: Button = $VBoxContainer/PlayAgainButton

# ---------------------------------------------------------------------------
# LIFECYCLE
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Connect the button's pressed signal to our handler.
	# This is Godot's way of binding a click callback — no polling required.
	play_again_button.pressed.connect(_on_play_again_pressed)

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------

## Set the score display. Called by GameManager before showing this screen.
## won   — number of games the player won
## total — total number of games in the run
func set_score(won: int, total: int) -> void:
	score_label.text = "You won %d / %d games" % [won, total]

# ---------------------------------------------------------------------------
# SIGNAL HANDLERS
# ---------------------------------------------------------------------------

## Restarts the entire run by reloading GameManager.tscn.
func _on_play_again_pressed() -> void:
	# change_scene_to_file() replaces the current scene tree root.
	# This effectively restarts the game from the beginning.
	get_tree().change_scene_to_file("res://shared/GameManager.tscn")
