# =============================================================================
# shared/GraduationScreen.gd
# =============================================================================
# PURPOSE:
#   Victory screen shown when the player completes all mini-games with at
#   least 1 life remaining. Displays a grade based on lives left, then
#   offers a "Play Again" button. GameManager sets `lives_remaining` before
#   adding this node to the scene tree so _ready() can read it.
#
# GRADE LOGIC:
#   3 lives -> First Class / Dean's List
#   2 lives -> Second Class Upper
#   1 life  -> Second Class Lower
#
# SCENE SETUP (build GraduationScreen.tscn in the Godot editor):
# -----------------------------------------------
#   GraduationScreen  (CanvasLayer)         <- root; attach GraduationScreen.gd
#                                              Layer: 20
#   └── WinImage                            <- TextureRect, FIRST child (backdrop)
#         Anchor Preset: Full Rect
#         expand_mode: Ignore Size
#         stretch_mode: Keep Aspect Covered
#         texture: set at runtime per lives_remaining (win1/2/3heart.png)
#   └── ColorRect                           <- dim overlay (drawn above image)
#         Anchor Preset: Full Rect
#         Color: Color(0, 0, 0, 0.45)         (semi-transparent black)
#   └── VBoxContainer                       <- Anchor Preset: Center; drawn on top
#         alignment: CENTER
#         custom_minimum_size: (700, 440)
#         separation: 24
#         ├── HeadlineLabel  (Label)        <- name exactly "HeadlineLabel"
#         │     Text: "CONGRATULATIONS!"
#         │     horizontal_alignment: CENTER
#         │     font size override: 52
#         ├── GradeLabel  (Label)           <- name exactly "GradeLabel"
#         │     Text: "" (set at runtime)
#         │     horizontal_alignment: CENTER
#         │     font size override: 36
#         ├── LivesLabel  (Label)           <- name exactly "LivesLabel"
#         │     Text: "" (set at runtime)
#         │     horizontal_alignment: CENTER
#         │     font size override: 28
#         ├── PlayAgainLabel  (Label)       <- name exactly "PlayAgainLabel"
#         │     Text: "Play Again to chase First Class?"
#         │     horizontal_alignment: CENTER
#         │     font size override: 20
#         │     Modulate alpha: 0.7
#         └── PlayAgainButton  (Button)     <- name exactly "PlayAgainButton"
#               Text: "Play Again"
#               custom_minimum_size: (280, 70)
# =============================================================================

extends CanvasLayer

signal play_again

# Set by GameManager before add_child() so _ready() can read it.
var lives_remaining: int = 0

@onready var win_image:         TextureRect = $WinImage
@onready var grade_label:       Label  = $VBoxContainer/GradeLabel
@onready var lives_label:       Label  = $VBoxContainer/LivesLabel
@onready var play_again_button: Button = $VBoxContainer/PlayAgainButton

const GRADES: Dictionary = {
	3: { "text": "First Class / Dean's List", "color": Color(1.0, 0.85, 0.1, 1.0) },
	2: { "text": "Second Class Upper",        "color": Color(0.8, 0.8,  0.8, 1.0) },
	1: { "text": "Second Class Lower",        "color": Color(0.8, 0.6,  0.4, 1.0) },
}

# Backdrop image per lives remaining (1/2/3 hearts -> grade tier).
const WIN_TEXTURES: Dictionary = {
	1: preload("res://assets/win_2ndClassLower.png"),
	2: preload("res://assets/win_2ndClassUpper.png"),
	3: preload("res://assets/win_DeansList.png"),
}

# Celebratory song played once on entry, same for every tier.
const WIN_SONG: AudioStream = preload("res://400 Sounds Pack/Musical Effects/xylophone_positive_long.wav")

var _win_song: AudioStreamPlayer

func _ready() -> void:
	_display_grade()
	_play_win_song()
	play_again_button.pressed.connect(func(): play_again.emit())

func _display_grade() -> void:
	win_image.texture = WIN_TEXTURES.get(lives_remaining, WIN_TEXTURES[1])
	lives_label.text = "♥".repeat(lives_remaining) + "♡".repeat(3 - lives_remaining)
	var grade: Dictionary = GRADES.get(lives_remaining, { "text": "Pass", "color": Color.WHITE })
	grade_label.text = grade["text"]
	grade_label.add_theme_color_override("font_color", grade["color"])

func _play_win_song() -> void:
	_win_song = AudioStreamPlayer.new()
	_win_song.stream = WIN_SONG
	add_child(_win_song)
	_win_song.play()
