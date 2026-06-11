# =============================================================================
# minigames/phone_down/PhoneDown.gd
# =============================================================================
# PREMISE: The lecturer randomly glances at the student's desk.
#   Hide the phone (tap it) before the lecturer catches you!
#   Survive until the time runs out to win. One mistake = lose.
#
# STATE MACHINE:
#   SAFE     → lecturer looks away, phone is visible, countdown to next glance
#   WARNING  → lecturer is about to look (brief flash), may be a fakeout
#   GLANCING → lecturer is actively looking — tap the phone NOW or lose
#
# RULES:
#   - extends MiniGameBase  (no own Timer nodes, no change_scene, one win/lose)
#   - setup() only — MiniGameBase._ready() calls it for us
# =============================================================================

extends MiniGameBase

# ---------------------------------------------------------------------------
# PRELOADED TEXTURES
# ---------------------------------------------------------------------------
const TEX_LECTURER_SAFE    = preload("res://minigames/phone_down/assets/lecturer_safe.png")
const TEX_LECTURER_WARNING = preload("res://minigames/phone_down/assets/lecturer_warning.png")
const TEX_LECTURER_ANGRY   = preload("res://minigames/phone_down/assets/lecturer_angry.png")
const TEX_PHONE_VISIBLE    = preload("res://minigames/phone_down/assets/phone_visible.png")
const TEX_PHONE_HIDDEN     = preload("res://minigames/phone_down/assets/phone_hidden.png")

# ---------------------------------------------------------------------------
# GAME SETTINGS
# ---------------------------------------------------------------------------
## How long (seconds) the GLANCING window lasts. Gets shorter as time goes on.
var glance_durations: Array[float] = [1.2, 0.9, 0.6, 0.5]

## How long the WARNING flash shows before resolving to GLANCING or fakeout.
var warning_duration: float = 0.5

# ---------------------------------------------------------------------------
# RUNTIME STATE
# ---------------------------------------------------------------------------
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

## Delay before returning to SAFE after a successful tap.
var _safe_delay_timer: float = 0.0
var _awaiting_safe: bool = false

# ---------------------------------------------------------------------------
# NODE REFERENCES
# ---------------------------------------------------------------------------
@onready var lecturer: Sprite2D = $Lecturer
@onready var student: Sprite2D = $Student
@onready var phone: Sprite2D = $Phone
@onready var background: TextureRect = $Background

@onready var ui_layer: CanvasLayer       = $UILayer
@onready var flash_overlay: ColorRect    = $UILayer/FlashOverlay
@onready var feedback_label: Label       = $UILayer/FeedbackLabel
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

# Sound files
const SFX_WARNING = preload("res://400 Sounds Pack/UI/sci_fi_hover.wav")
const SFX_HIDE = preload("res://400 Sounds Pack/UI/sci_fi_confirm.wav")
const SFX_CAUGHT = preload("res://400 Sounds Pack/Retro/lose.wav")

# ---------------------------------------------------------------------------
# SOLO TESTING
# ---------------------------------------------------------------------------
func _ready() -> void:
	# Hide the old UI labels since we don't use local lives anymore
	if has_node("UILayer/LivesLabel"):
		$UILayer/LivesLabel.visible = false
	if has_node("UILayer/GlancesLabel"):
		$UILayer/GlancesLabel.visible = false
	setup()

# ---------------------------------------------------------------------------
# MINIGAMEBASE CONTRACT
# ---------------------------------------------------------------------------
func setup() -> void:
	base_duration = 10.0
	instruction_text = "Hide your phone!"
	next_glance_time = randf_range(1.5, 2.5)
	game_active = true
	_lecturer_origin = lecturer.position

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	background.position = Vector2.ZERO
	background.size = vp_size
	background.stretch_mode = TextureRect.STRETCH_SCALE

	_apply_state()

# ---------------------------------------------------------------------------
# GAME LOOP
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	# Scale every internal clock by time_scale so this minigame's pacing
	# shrinks along with the HUD's actual_duration() in later faculties.
	delta *= time_scale

	# Survival win is handled by the lose() override below: when the shared HUD
	# timer runs out, GameManager calls lose(), which we convert to win() while
	# game_active is still true (no mistake made). delta is already time_scaled
	# above, so the timers below must NOT multiply by time_scale again.
	if _awaiting_safe:
		_safe_delay_timer -= delta
		if _safe_delay_timer <= 0.0:
			_awaiting_safe = false
			_set_state("SAFE")

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
					_lose_game("CAUGHT!")

	# Effects...
	if _is_shaking:
		_shake_time += delta
		if _shake_time < 0.5:
			var offset := Vector2(sin(_shake_time * 60.0) * 6.0, cos(_shake_time * 55.0) * 3.0)
			lecturer.position = _lecturer_origin + offset
		else:
			lecturer.position = _lecturer_origin
			_is_shaking = false
			_shake_time = 0.0

	if _flash_active:
		_flash_alpha = max(0.0, _flash_alpha - delta * 3.0)
		flash_overlay.color = Color(1.0, 0.0, 0.0, _flash_alpha)
		if _flash_alpha <= 0.0:
			_flash_active = false
			flash_overlay.visible = false

	if _feedback_active:
		_feedback_timer -= delta
		var alpha := clampf(_feedback_timer / 0.3, 0.0, 1.0)
		feedback_label.modulate.a = alpha
		if _feedback_timer <= 0.0:
			_feedback_active = false
			feedback_label.visible = false

# ---------------------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not game_active:
		return
	if not event is InputEventMouseButton:
		return
	if not (event as InputEventMouseButton).pressed:
		return

	var click_pos: Vector2 = get_global_mouse_position()
	if click_pos.distance_to(phone.global_position) > 150:
		return

	match state:
		"GLANCING":
			phone.texture = TEX_PHONE_HIDDEN
			glances_survived += 1
			_show_feedback("NICE!", Color(0.2, 1.0, 0.4))
			audio_player.stream = SFX_HIDE
			audio_player.play()
			state = "HIDDEN" 
			_awaiting_safe = true
			_safe_delay_timer = 0.4

		"SAFE":
			_lose_game("TOO EARLY!")

		"WARNING":
			_lose_game("WAIT!")

# ---------------------------------------------------------------------------
# LOSE CONDITION (One strike)
# ---------------------------------------------------------------------------
func _lose_game(reason: String) -> void:
	game_active = false
	_show_feedback(reason, Color(1.0, 0.25, 0.25))
	audio_player.stream = SFX_CAUGHT
	audio_player.play()
	lose()

# Override the base lose() to handle timeouts as wins for survival mode.
func lose() -> void:
	if game_active:
		# If game_active is still true, the player didn't make a mistake.
		# This means GameManager called lose() because the global timer ran out.
		# In a survival game, timing out means you win!
		game_active = false
		win()
	else:
		# A genuine loss (player got caught or tapped wrong), let the base class handle it.
		super.lose()

# ---------------------------------------------------------------------------
# STATE TRANSITIONS
# ---------------------------------------------------------------------------
func _set_state(new_state: String) -> void:
	state = new_state
	state_timer = 0.0
	fakeout = false

	if state == "SAFE":
		# Make it slightly faster as they survive longer
		var speed_up = min(glances_survived * 0.2, 1.0)
		next_glance_time = randf_range(1.0 - speed_up, 2.5 - speed_up)
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
