# =============================================================================
# shared/IntroScreen.gd
# =============================================================================
# PURPOSE:
#   5-second intro card shown before each run. Displays the premise, then
#   emits `done` automatically. Player can tap or click anywhere to skip.
#   GameManager listens and calls _start_game_loop().
#
# SCENE SETUP (build IntroScreen.tscn in the Godot editor):
# -----------------------------------------------
#   IntroScreen  (CanvasLayer)              <- root; attach IntroScreen.gd
#                                              Layer: 5
#   └── ColorRect                           <- Anchor Preset: Full Rect
#         Color: Color(0.08, 0.08, 0.15, 1)
#   └── VBoxContainer                       <- Anchor Preset: Center
#         alignment: CENTER
#         custom_minimum_size: (700, 220)
#         separation: 24
#         ├── IntroLabel  (Label)           <- name exactly "IntroLabel"
#         │     Text: "You have 3 lives.\n12 faculties.\nOne degree."
#         │     horizontal_alignment: CENTER
#         │     font size override: 36
#         └── HintLabel   (Label)           <- name exactly "HintLabel"
#               Text: "Tap anywhere to skip"
#               horizontal_alignment: CENTER
#               font size override: 18
#               Modulate alpha: 0.6
# =============================================================================

extends CanvasLayer

signal done

const INTRO_DURATION: float = 5.0

# Guard so the timer and a tap cannot both emit done.
var _emitted: bool = false

func _ready() -> void:
	_fit_background()
	get_tree().create_timer(INTRO_DURATION).timeout.connect(_emit_done)

## Scale the Sprite2D background to fully cover the viewport (authored at a fixed
## scale for the old default resolution, which left padding at 1280x720).
func _fit_background() -> void:
	var bg := get_node_or_null("Background") as Sprite2D
	if bg == null or bg.texture == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tex: Vector2 = bg.texture.get_size()
	bg.position = vp / 2.0
	var s: float = maxf(vp.x / tex.x, vp.y / tex.y)
	bg.scale = Vector2(s, s)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_emit_done()
	elif event is InputEventScreenTouch and event.pressed:
		_emit_done()

func _emit_done() -> void:
	if _emitted:
		return
	_emitted = true
	set_process_input(false)
	done.emit()
