# =============================================================================
# shared/DropOutScreen.gd
# =============================================================================
# PURPOSE:
#   Game-over screen shown when the player loses all 3 lives mid-run.
#   Emits `play_again` when the player presses Try Again; GameManager listens
#   and transitions back to IntroScreen for a fresh run.
#
#   This is the "lose UI" rebuilt to mirror the GraduationScreen "win UI"
#   (krup13 / Khaira) so the game-over screen feels as finished as the victory
#   one: a full-screen styled backdrop + dim overlay + outlined headline + a
#   defeat sting. The backdrop is a dark-red gradient for now — the Art Director
#   can drop a real "dropout" image into the Backdrop TextureRect's texture slot
#   later, exactly like GraduationScreen's WinImage.
#
# SCENE (DropOutScreen.tscn):
#   DropOutScreen (CanvasLayer, layer 20)
#   ├── Backdrop      (TextureRect, full rect, dark-red GradientTexture2D)
#   ├── ColorRect     (full rect, semi-transparent black dim)
#   └── VBoxContainer (centered)
#       ├── HeadlineLabel  "DROPPED OUT"
#       ├── SubLabel       "You ran out of lives. ..."
#       ├── PlayAgainLabel "Every dropout's a comeback story — try again?"
#       └── TryAgainButton "Try Again"   <- name path the script reads
# =============================================================================

extends CanvasLayer

signal play_again

@onready var try_again_button: Button = $VBoxContainer/TryAgainButton

# Defeat sting played once on entry (mirrors GraduationScreen's win song).
const LOSE_SONG: AudioStream = preload("res://400 Sounds Pack/Musical Effects/xylophone_negative_long.wav")

var _lose_song: AudioStreamPlayer

func _ready() -> void:
	_play_lose_song()
	try_again_button.pressed.connect(func(): play_again.emit())

func _play_lose_song() -> void:
	_lose_song = AudioStreamPlayer.new()
	_lose_song.stream = LOSE_SONG
	add_child(_lose_song)
	_lose_song.play()
