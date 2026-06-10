# =============================================================================
# minigames/phone_down/PhoneDown.gd
# =============================================================================
# PREMISE: The lecturer randomly glances at the student's desk.
#   Hide the phone (tap it) before the lecturer catches you!
#   Survive 3 glances to win. Lose all 3 lives to lose.
#
# STATE MACHINE:
#   SAFE     → lecturer looks away, phone is visible, countdown to next glance
#   WARNING  → lecturer is about to look (brief flash), may be a fakeout
#   GLANCING → lecturer is actively looking — tap the phone NOW or lose a life
#
# RULES:
#   - extends MiniGameBase  (no own Timer nodes, no change_scene, one win/lose)
#   - setup() only — MiniGameBase._ready() calls it for us
# =============================================================================

extends MiniGameBase

# ---------------------------------------------------------------------------
# PRELOADED TEXTURES — loaded once at parse time for zero runtime stutter
# ---------------------------------------------------------------------------
const TEX_LECTURER_SAFE    = preload("res://minigames/phone_down/assets/lecturer_safe.png")
const TEX_LECTURER_WARNING = preload("res://minigames/phone_down/assets/lecturer_warning.png")
const TEX_LECTURER_ANGRY   = preload("res://minigames/phone_down/assets/lecturer_angry.png")
const TEX_PHONE_VISIBLE    = preload("res://minigames/phone_down/assets/phone_visible.png")
const TEX_PHONE_HIDDEN     = preload("res://minigames/phone_down/assets/phone_hidden.png")

# ---------------------------------------------------------------------------
# GAME SETTINGS
# ---------------------------------------------------------------------------
## How long (seconds) the GLANCING window lasts per difficulty step.
var glance_durations: Array[float] = [1.2, 0.9, 0.6]

## How long the WARNING flash shows before resolving to GLANCING or fakeout.
var warning_duration: float = 0.5

## How many glances the player must survive to win.
var glances_required: int = 3

# ---------------------------------------------------------------------------
# RUNTIME STATE
# ---------------------------------------------------------------------------
var lives: int = 3
var glances_survived: int = 0
var state: String = "SAFE"
var state_timer: float = 0.0
var next_glance_time: float = 0.0
var game_active: bool = false
var fakeout: bool = false

## Tracks original lecturer position for shake effect.
var _lecturer_origin: Vector2 = Vector2.ZERO
var _shake_time: float = 0.0
var _is_shaking: bool = false

## Tracks flash overlay alpha for screen flash effect.
var _flash_alpha: float = 0.0
var _flash_active: bool = false

## Tracks feedback label timer ("CAUGHT!" / "NICE!").
var _feedback_timer: float = 0.0
var _feedback_active: bool = false

## Delay before returning to SAFE after a successful tap, so phone_hidden.png
## stays visible for a visible moment before the phone comes back out.
var _safe_delay_timer: float = 0.0
var _awaiting_safe: bool = false

# ---------------------------------------------------------------------------
# NODE REFERENCES — @onready resolves after scene tree is built
# ---------------------------------------------------------------------------
@onready var lecturer: Sprite2D = $Lecturer
@onready var student: Sprite2D = $Student
@onready var phone: Sprite2D = $Phone
@onready var background: TextureRect = $Background

# UI nodes (all live under the UILayer CanvasLayer in the scene)
@onready var ui_layer: CanvasLayer       = $UILayer
@onready var lives_label: Label          = $UILayer/LivesLabel
@onready var glances_label: Label        = $UILayer/GlancesLabel
@onready var flash_overlay: ColorRect    = $UILayer/FlashOverlay
@onready var feedback_label: Label       = $UILayer/FeedbackLabel
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

# Sound files (from the 400 Sounds Pack)
const SFX_WARNING = preload("res://400 Sounds Pack/UI/sci_fi_hover.wav")
const SFX_HIDE = preload("res://400 Sounds Pack/UI/sci_fi_confirm.wav")
const SFX_CAUGHT = preload("res://400 Sounds Pack/Retro/lose.wav")

# ---------------------------------------------------------------------------
# MINIGAMEBASE CONTRACT
# ---------------------------------------------------------------------------
func setup() -> void:
	base_duration = 10.0
	instruction_text = "Hide your phone when the lecturer looks!"
	next_glance_time = randf_range(1.5, 3.0)
	game_active = true
	_lecturer_origin = lecturer.position

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	background.position = Vector2.ZERO
	background.size = vp_size
	background.stretch_mode = TextureRect.STRETCH_SCALE

	_update_ui()
	_apply_state()

# ---------------------------------------------------------------------------
# GAME LOOP
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	# Scale every internal clock by time_scale so this minigame's pacing
	# shrinks along with the HUD's actual_duration() in later faculties.
	delta *= time_scale

	# ── Safe-return delay (lets phone_hidden texture show briefly) ──────────
	if _awaiting_safe:
		_safe_delay_timer -= delta
		if _safe_delay_timer <= 0.0:
			_awaiting_safe = false
			_set_state("SAFE")

	# ── State machine ──────────────────────────────────────────────────────
	if game_active:
		state_timer += delta
		match state:
			"SAFE":
				if state_timer >= next_glance_time:
					_set_state("WARNING")
			"WARNING":
				if state_timer >= warning_duration:
					if fakeout:
						_show_feedback("Phew!", Color(0.5, 0.8, 1.0))
						_set_state("SAFE")
					else:
						_set_state("GLANCING")
			"GLANCING":
				var duration: float = glance_durations[min(glances_survived, glance_durations.size() - 1)]
				if state_timer >= duration:
					_lose_life()

	# ── Lecturer shake ─────────────────────────────────────────────────────
	if _is_shaking:
		_shake_time += delta
		if _shake_time < 0.5:
			var offset := Vector2(
				sin(_shake_time * 60.0) * 6.0,
				cos(_shake_time * 55.0) * 3.0
			)
			lecturer.position = _lecturer_origin + offset
		else:
			lecturer.position = _lecturer_origin
			_is_shaking = false
			_shake_time = 0.0

	# ── Screen flash fade-out ──────────────────────────────────────────────
	if _flash_active:
		_flash_alpha = max(0.0, _flash_alpha - delta * 3.0)
		flash_overlay.color = Color(1.0, 0.0, 0.0, _flash_alpha)
		if _flash_alpha <= 0.0:
			_flash_active = false
			flash_overlay.visible = false

	# ── Feedback label fade-out ────────────────────────────────────────────
	if _feedback_active:
		_feedback_timer -= delta
		var alpha := clampf(_feedback_timer / 0.3, 0.0, 1.0)
		feedback_label.modulate.a = alpha
		if _feedback_timer <= 0.0:
			_feedback_active = false
			feedback_label.visible = false

# ---------------------------------------------------------------------------
# INPUT — tap the phone sprite
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not game_active:
		return
	if not event is InputEventMouseButton:
		return
	if not (event as InputEventMouseButton).pressed:
		return

	var click_pos: Vector2 = get_global_mouse_position()
	var dist: float = click_pos.distance_to(phone.global_position)
	if dist > 150:
		return

	match state:

		"GLANCING":
			phone.texture = TEX_PHONE_HIDDEN
			glances_survived += 1
			_show_feedback("NICE!", Color(0.2, 1.0, 0.4))
			
			audio_player.stream = SFX_HIDE
			audio_player.play()
			
			_update_ui()
			
			# Instantly exit the GLANCING state so _process() doesn't trigger _lose_life()
			# due to the timer expiring while we are waiting for the safe delay.
			state = "HIDDEN" 
			
			if glances_survived >= glances_required:
				game_active = false
				win()
			else:
				_awaiting_safe = true
				_safe_delay_timer = 0.4

		"SAFE":
			lives -= 1
			_show_feedback("TOO EARLY!", Color(1.0, 0.5, 0.0))
			audio_player.stream = SFX_CAUGHT
			audio_player.play()
			_update_ui()
			if lives <= 0:
				game_active = false
				lose()
				return
			_set_state("SAFE")

		"WARNING":
			lives -= 1
			_show_feedback("WAIT!", Color(1.0, 1.0, 0.0))
			audio_player.stream = SFX_CAUGHT
			audio_player.play()
			_update_ui()
			if lives <= 0:
				game_active = false
				lose()
				return
			_set_state("SAFE")

# ---------------------------------------------------------------------------
# LIFE MANAGEMENT — only called when lecturer catches the player (timeout)
# ---------------------------------------------------------------------------
func _lose_life() -> void:
	lives -= 1
	_show_feedback("CAUGHT!", Color(1.0, 0.25, 0.25))
	audio_player.stream = SFX_CAUGHT
	audio_player.play()
	_update_ui()
	if lives <= 0:
		game_active = false
		lose()
	else:
		_set_state("SAFE")

# ---------------------------------------------------------------------------
# STATE TRANSITIONS
# ---------------------------------------------------------------------------
func _set_state(new_state: String) -> void:
	state = new_state
	state_timer = 0.0
	fakeout = false

	if state == "SAFE":
		next_glance_time = randf_range(1.5, 2.5)
		fakeout = randf() < 0.3

	if state == "GLANCING":
		_start_flash()
		_is_shaking = true
		_shake_time = 0.0

	_apply_state()

func _apply_state() -> void:
	match state:
		"SAFE":
			lecturer.texture = TEX_LECTURER_SAFE
			phone.texture = TEX_PHONE_VISIBLE
		"WARNING":
			lecturer.texture = TEX_LECTURER_WARNING
			audio_player.stream = SFX_WARNING
			audio_player.play()
		"GLANCING":
			lecturer.texture = TEX_LECTURER_ANGRY
			phone.texture = TEX_PHONE_VISIBLE

# ---------------------------------------------------------------------------
# VISUAL EFFECTS
# ---------------------------------------------------------------------------
func _start_flash() -> void:
	_flash_alpha = 0.45
	flash_overlay.color = Color(1.0, 0.0, 0.0, _flash_alpha)
	flash_overlay.visible = true
	_flash_active = true

func _show_feedback(text: String, color: Color) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", color)
	feedback_label.modulate.a = 1.0
	feedback_label.visible = true
	_feedback_timer = 1.0
	_feedback_active = true

# ---------------------------------------------------------------------------
# UI UPDATE
# ---------------------------------------------------------------------------
func _update_ui() -> void:
	var hearts := ""
	for i in range(3):
		if i < lives:
			hearts += "❤️ "
		else:
			hearts += "🖤 "
	lives_label.text = hearts.strip_edges()
	glances_label.text = "Glances: %d / %d" % [glances_survived, glances_required]
