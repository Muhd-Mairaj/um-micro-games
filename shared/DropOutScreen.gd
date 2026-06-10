# =============================================================================
# shared/DropOutScreen.gd
# =============================================================================
# PURPOSE:
#   Game-over screen shown when the player loses all 3 lives mid-run.
#   Emits `play_again` when the player presses the button.
#   GameManager listens and transitions back to IntroScreen for a fresh run.
#
# SCENE SETUP (build DropOutScreen.tscn in the Godot editor):
# -----------------------------------------------
#   DropOutScreen  (CanvasLayer)            <- root; attach DropOutScreen.gd
#                                              Layer: 20
#   └── ColorRect                           <- Anchor Preset: Full Rect
#         Color: Color(0.15, 0.02, 0.02, 1)   (dark red)
#   └── VBoxContainer                       <- Anchor Preset: Center
#         alignment: CENTER
#         custom_minimum_size: (640, 340)
#         separation: 28
#         ├── HeadlineLabel  (Label)        <- name exactly "HeadlineLabel"
#         │     Text: "DROPPED OUT"
#         │     horizontal_alignment: CENTER
#         │     font size override: 64
#         │     Modulate color: Color(1, 0.3, 0.3, 1)
#         ├── SubLabel  (Label)             <- name exactly "SubLabel"
#         │     Text: "You ran out of lives.\nBetter luck next semester."
#         │     horizontal_alignment: CENTER
#         │     font size override: 24
#         └── TryAgainButton  (Button)      <- name exactly "TryAgainButton"
#               Text: "Try Again"
#               custom_minimum_size: (280, 70)
# =============================================================================

extends CanvasLayer

signal play_again

@onready var try_again_button: Button = $VBoxContainer/TryAgainButton

func _ready() -> void:
	try_again_button.pressed.connect(func(): play_again.emit())
