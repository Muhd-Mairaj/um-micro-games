# =============================================================================
# shared/TitleScreen.gd
# =============================================================================
# PURPOSE:
#   Full-screen title card shown at game start and after each "Play Again".
#   Emits the `started` signal when the player presses the Start button.
#   GameManager listens and transitions to IntroScreen.
#
# SCENE SETUP (build TitleScreen.tscn in the Godot editor):
# -----------------------------------------------
#   TitleScreen  (CanvasLayer)              <- root; attach TitleScreen.gd
#                                              Layer: 5
#   └── ColorRect                           <- Anchor Preset: Full Rect
#         Color: Color(0.08, 0.08, 0.15, 1)   (dark navy)
#   └── VBoxContainer                       <- Anchor Preset: Center
#         alignment: CENTER
#         custom_minimum_size: (600, 300)
#         separation: 32
#         ├── TitleLabel  (Label)           <- name exactly "TitleLabel"
#         │     Text: "Can You Graduate from UM?"
#         │     horizontal_alignment: CENTER
#         │     font size override: 42
#         └── StartButton  (Button)         <- name exactly "StartButton"
#               Text: "Play"
#               custom_minimum_size: (300, 70)
# =============================================================================

extends CanvasLayer

signal started

@onready var start_button: Button = $VBoxContainer/StartButton

func _ready() -> void:
	start_button.pressed.connect(func(): started.emit())
	start_button.pivot_offset = start_button.size / 2
	
func _on_start_button_mouse_entered() -> void:
	start_button.scale = Vector2(0.95, 0.95)

func _on_start_button_mouse_exited() -> void:
	start_button.scale = Vector2.ONE
