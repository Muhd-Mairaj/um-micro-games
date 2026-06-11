# =============================================================================
# minigames/order_in_the_court/OrderInTheCourt.gd
# =============================================================================
# FACULTY: Faculty of Law  (Fakulti Undang-Undang / FUU)
# AUTHOR : Alshamrani  ("Order in the Court" — gavel-tap micro-game)
#
# PREMISE:
#   You are a stressed UM Law student standing in as the courtroom judge.
#   Lawyers pop up from behind the bench at random slots shouting "OBJECTION!",
#   faster and faster as the round goes on. TAP / CLICK a lawyer to bang the
#   gavel and silence it. A CHAOS METER fills while lawyers are left active
#   (more lawyers up + longer they stay = faster fill).
#     WIN  -> the ~10s round ends with the meter below max   ("CASE WON!")
#     LOSE -> the meter hits max                              ("MISTRIAL!")
#
# HOW THIS HOOKS INTO THE SHARED FRAMEWORK (see shared/MiniGameBase.gd):
#   - extends MiniGameBase and overrides setup() (NOT _ready()).
#   - base_duration drives the shared HUD countdown bar via actual_duration();
#     this game adds NO timer of its own — the shared HUD owns the countdown.
#   - This is a SURVIVAL game: running out of time means the player kept order,
#     so it should WIN. GameManager calls lose() when the HUD timer runs out, so
#     we override lose() to convert that timeout into win() UNLESS the chaos
#     meter already maxed (a real MISTRIAL). Same pattern as PhoneDown, so the
#     whole collection drives off the one shared HUD timer bar.
#   - Standalone (F6) reuses the SAME shared HUD (shared/HUD.tscn) for its timer
#     bar, so there is no second timer implementation anywhere.
#   - The Stitcher registers this path in GameManager.gd in Week 12:
#       "res://minigames/order_in_the_court/OrderInTheCourt.tscn",
#
# SCENE SETUP (OrderInTheCourt.tscn):
# -----------------------------------------------
#   OrderInTheCourt  (Node2D)   <- root only; attach this script.
#   Everything else (background, bench, judge, lawyers, chaos meter, labels,
#   retry button) is built IN CODE and laid out responsively from
#   get_viewport_rect().size, so there are no hardcoded pixel positions and the
#   scene scales to any window. Placeholder art is drawn with Polygon2D /
#   ColorRect and plain ASCII Labels (Spr_Fuu_Bench, Spr_Fuu_Judge,
#   Spr_Fuu_Lawyer, Spr_Fuu_Gavel) — swap these for real sprites when the Art
#   Director delivers them.
# =============================================================================

extends MiniGameBase

# ---------------------------------------------------------------------------
# TUNING — exported for the Systems Balancer (Week 12 difficulty tuning).
# These defaults are a sensible, winnable-with-skill starting point.
# ---------------------------------------------------------------------------

## Total round length at time_scale 1.0. Also feeds the shared HUD bar.
@export var round_time: float = 10.0

## Seconds between lawyer spawns at the START of the round (calmer).
@export var spawn_interval_start: float = 1.2

## Seconds between lawyer spawns at the END of the round (frantic).
@export var spawn_interval_min: float = 0.5

## How long a lawyer stays up before retreating on its own (still costs chaos
## the whole time it is up). Tap it to silence it sooner.
@export var lawyer_stay_time: float = 2.2

## Chaos units added per second, per lawyer currently up. More up = faster fill.
@export var chaos_per_active_lawyer_per_sec: float = 10.0

## The meter maxes out (MISTRIAL) at this value.
@export var max_chaos: float = 100.0

## Chaos drains this fast per second while NO lawyer is up (reward for order).
@export var chaos_settle_per_sec: float = 10.0

# ---------------------------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------------------------

## Number of bench slots a lawyer can pop up from.
const N_SLOTS: int = 5

## Pop-up / retreat animation timings.
const POP_UP_TIME: float = 0.22
const RETREAT_TIME: float = 0.18

## UM palette (no STYLE_GUIDE.md published by the Art Director yet, so we fall
## back to the official UM colours — navy + gold read as formal/judicial).
const UM_NAVY:      Color = Color(0.0,   0.184, 0.424, 1.0)  # #002F6C
const UM_NAVY_DARK: Color = Color(0.0,   0.122, 0.282, 1.0)
const UM_GOLD:      Color = Color(0.992, 0.725, 0.075, 1.0)  # #FDB913
const BENCH_WOOD:   Color = Color(0.357, 0.204, 0.110, 1.0)  # dark oak bench
const BENCH_TRIM:   Color = Color(0.498, 0.310, 0.180, 1.0)
const ROBE_COLOR:   Color = Color(0.114, 0.122, 0.169, 1.0)  # dark lawyer robe
const SKIN_COLOR:   Color = Color(0.886, 0.722, 0.561, 1.0)
const WHITE:        Color = Color(0.93,  0.94,  0.98,  1.0)
const CHAOS_LOW:    Color = Color(0.231, 0.78,  0.353, 1.0)  # green
const CHAOS_MID:    Color = Color(0.98,  0.74,  0.18,  1.0)  # amber
const CHAOS_HIGH:   Color = Color(0.92,  0.22,  0.20,  1.0)  # red

## Optional font (real shared asset). Loaded null-safely in setup().
const FONT_PATH: String = "res://assets/Font/Kenney Future.ttf"

## Optional gavel-bang SFX from this minigame's own folder. Does not exist yet —
## still needed from the Audio Lead. Loaded null-safely so the game never breaks.
## Filename is snake_case per the repo asset convention (CLAUDE.md / README).
const SFX_BANG_PATH: String = "res://minigames/order_in_the_court/assets/sfx_fuu_gavel_bang.wav"

# ---------------------------------------------------------------------------
# RUNTIME STATE
# ---------------------------------------------------------------------------

var _round_active: bool = false
var _elapsed: float = 0.0
var _round_len: float = 10.0
var _spawn_timer: float = 0.4
var _chaos: float = 0.0
var _standalone: bool = false
## True once the chaos meter maxes (a real MISTRIAL). Lets the lose() override
## tell a genuine loss apart from a survival timeout (which is a WIN).
var _mistrial_triggered: bool = false
## Standalone (F6) only: an instance of the shared HUD so solo runs use the same
## timer bar as the hub instead of a home-grown one.
var _solo_hud: CanvasLayer = null

## One entry per live lawyer: { "node": Area2D, "slot": int, "time_up": float,
## "alive": bool }.
var _lawyers: Array = []

# ---------------------------------------------------------------------------
# LAYOUT (recomputed from the viewport in _apply_layout()).
# ---------------------------------------------------------------------------

var _vp: Vector2 = Vector2(1280, 720)
var _bench_top: float = 0.0
var _lawyer_w: float = 120.0
var _lawyer_h: float = 200.0
var _slot_x: Array[float] = []
var _slot_up_y: float = 0.0
var _slot_hidden_y: float = 0.0

# ---------------------------------------------------------------------------
# PERSISTENT NODE REFERENCES (created in _build_scene()).
# ---------------------------------------------------------------------------

var _font: Font = null
var _sfx: AudioStreamPlayer = null
var _bg: ColorRect
var _wall: ColorRect
var _judge: Node2D
var _lawyer_layer: Node2D
var _bench: Node2D
var _meter_bg: ColorRect
var _meter_fill: ColorRect
var _meter_label: Label
var _title_label: Label
var _result_label: Label
var _retry_button: Button

# ---------------------------------------------------------------------------
# MINIGAMEBASE CONTRACT
# ---------------------------------------------------------------------------

func setup() -> void:
	# Feed the shared HUD: base_duration -> actual_duration() -> countdown bar.
	base_duration = round_time
	instruction_text = "Order! TAP each lawyer to bang the gavel and silence the OBJECTION!"

	# Guard the meter ceiling: a non-positive max_chaos (a stray tuning value)
	# would make _chaos >= max_chaos true on frame one (instant MISTRIAL) and
	# turn _chaos / max_chaos into nan. Keep it sane.
	max_chaos = maxf(max_chaos, 1.0)

	# Round bookkeeping (actual_duration() already accounts for time_scale).
	# Used only to pace the spawn ramp — the shared HUD owns the countdown.
	_round_len = max(actual_duration(), 1.0)

	# Are we running on our own via F6 (no GameManager / HUD)? If so we spin up
	# the shared HUD ourselves and offer a retry; in the hub GameManager owns the
	# HUD and transitions and we never reload.
	_standalone = get_tree().current_scene == self

	# Make Area2D taps work for both mouse and touch regardless of project defaults.
	get_viewport().physics_object_picking = true

	# Optional shared font (null-safe).
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as Font

	_build_scene()
	_apply_layout()

	# Reflow if the window is resized while playing.
	get_viewport().size_changed.connect(_apply_layout)

	# Kick the round off. The first lawyer arrives after a short beat.
	_chaos = 0.0
	_elapsed = 0.0
	_spawn_timer = 0.4
	_mistrial_triggered = false
	_round_active = true
	_update_chaos_meter()

	# Standalone testing: reuse the real shared HUD so even F6 runs off the one
	# timer bar. Its countdown running out is our survival WIN (via lose()).
	if _standalone:
		_start_solo_hud()

func _process(delta: float) -> void:
	if _finished or not _round_active:
		return

	_elapsed += delta

	# --- spawning: interval shrinks from start -> min across the round ---
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_lawyer()
		_spawn_timer = _current_spawn_interval()

	# --- lawyer lifetimes: auto-retreat after staying up too long ---
	for entry in _lawyers.duplicate():
		entry["time_up"] += delta
		if entry["alive"] and entry["time_up"] >= lawyer_stay_time:
			_retreat_lawyer(entry)

	# --- chaos: fills while lawyers are up, settles while the court is calm ---
	var active: int = 0
	for entry in _lawyers:
		if entry["alive"]:
			active += 1
	if active > 0:
		_chaos += float(active) * chaos_per_active_lawyer_per_sec * delta
	else:
		_chaos -= chaos_settle_per_sec * delta
	_chaos = clampf(_chaos, 0.0, max_chaos)

	_update_chaos_meter()

	# --- loss check: the meter maxing out is a MISTRIAL. The survival WIN is
	# driven by the shared HUD timer running out (see the lose() override). ---
	if _chaos >= max_chaos:
		_mistrial()

# ---------------------------------------------------------------------------
# OUTCOMES
# ---------------------------------------------------------------------------

## SURVIVAL override: the player wins by outlasting the shared HUD timer.
## GameManager calls lose() the instant that timer runs out, so we convert a
## timeout into a win — UNLESS the chaos meter already maxed (a real MISTRIAL).
## (Same approach as PhoneDown; keeps the whole game on the shared timer bar.)
func lose() -> void:
	if _finished:
		return
	if _mistrial_triggered:
		super.lose()   # genuine loss — let the base class emit game_lost.
	else:
		_case_won()    # timer ran out with order kept — the player WINS.

func _case_won() -> void:
	if _finished:
		return
	_round_active = false
	_freeze_lawyers()
	_show_result("CASE WON!", UM_GOLD)
	if _solo_hud != null:
		_solo_hud.show_result(true)
	win()   # GameManager + HUD take over from here.

func _mistrial() -> void:
	if _finished:
		return
	_mistrial_triggered = true
	_round_active = false
	_chaos = max_chaos
	_update_chaos_meter()
	_freeze_lawyers()
	_show_result("MISTRIAL!", CHAOS_HIGH)
	if _solo_hud != null:
		_solo_hud.show_result(false)
	lose()  # -> override -> super.lose(); GameManager + HUD take over from here.

# ---------------------------------------------------------------------------
# STANDALONE SHARED-HUD HARNESS (F6 only) — reuse shared/HUD.tscn so solo runs
# use the exact same timer bar as the hub (no second timer implementation).
# ---------------------------------------------------------------------------

func _start_solo_hud() -> void:
	var hud_scene: PackedScene = load("res://shared/HUD.tscn")
	if hud_scene == null:
		return
	_solo_hud = hud_scene.instantiate()
	add_child(_solo_hud)
	_solo_hud.update_lives(3)
	_solo_hud.update_progress(0, 1)
	_solo_hud.set_instruction(instruction_text)
	_solo_hud.start(actual_duration())
	# Mirror GameManager: the HUD timer running out calls lose() (which our
	# override turns into the survival win).
	_solo_hud.timed_out.connect(func() -> void: lose())

func _show_result(text: String, color: Color) -> void:
	_result_label.text = text
	_result_label.add_theme_color_override("font_color", color)
	_result_label.visible = true
	# Little pop so the verdict lands.
	_result_label.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(_result_label, "scale", Vector2(1.0, 1.0), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Standalone testing only: offer a retry (the hub frees us automatically).
	if _standalone:
		_retry_button.visible = true

# ---------------------------------------------------------------------------
# LAWYERS
# ---------------------------------------------------------------------------

func _spawn_lawyer() -> void:
	var slot: int = _pick_free_slot()
	if slot == -1:
		return  # every slot occupied — wait for the judge to clear some.

	var area := Area2D.new()
	area.name = "Spr_Fuu_Lawyer"
	area.input_pickable = true
	area.position = Vector2(_slot_x[slot], _slot_hidden_y)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(_lawyer_w, _lawyer_h)
	col.shape = shape
	# Centre the hit box on the visible upper body (origin sits at the bench line).
	col.position = Vector2(0, -_lawyer_h * 0.5)
	area.add_child(col)

	_build_lawyer_visual(area)
	_lawyer_layer.add_child(area)

	var entry: Dictionary = {"node": area, "slot": slot, "time_up": 0.0, "alive": true}
	_lawyers.append(entry)

	area.input_event.connect(_on_lawyer_input.bind(entry))

	# Pop up from behind the bench.
	var tw := create_tween()
	tw.tween_property(area, "position:y", _slot_up_y, POP_UP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_lawyer_visual(area: Area2D) -> void:
	# All shapes are drawn relative to the bench line (y = 0 at the bench top),
	# growing upward (negative y). Pure placeholders — clearly not final art.
	var hw: float = _lawyer_w * 0.5

	var robe := Polygon2D.new()
	robe.name = "Body"
	robe.color = ROBE_COLOR
	robe.polygon = PackedVector2Array([
		Vector2(-hw * 0.85, 0.0),
		Vector2(hw * 0.85, 0.0),
		Vector2(hw * 0.55, -_lawyer_h * 0.62),
		Vector2(-hw * 0.55, -_lawyer_h * 0.62),
	])
	area.add_child(robe)

	# White collar band.
	var collar := Polygon2D.new()
	collar.name = "Collar"
	collar.color = WHITE
	collar.polygon = PackedVector2Array([
		Vector2(-hw * 0.18, -_lawyer_h * 0.60),
		Vector2(hw * 0.18, -_lawyer_h * 0.60),
		Vector2(0.0, -_lawyer_h * 0.50),
	])
	area.add_child(collar)

	var head := Polygon2D.new()
	head.name = "Head"
	head.color = SKIN_COLOR
	head.polygon = _circle_points(Vector2(0, -_lawyer_h * 0.74), _lawyer_w * 0.24, 14)
	area.add_child(head)

	var shout := Label.new()
	shout.name = "Shout"
	shout.text = "OBJECTION!"
	_style_label(shout, int(_lawyer_w * 0.22), UM_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	shout.size = Vector2(_lawyer_w * 2.0, _lawyer_h * 0.2)
	shout.position = Vector2(-_lawyer_w, -_lawyer_h * 1.02)
	area.add_child(shout)

func _on_lawyer_input(_viewport: Node, event: InputEvent, _shape_idx: int, entry: Dictionary) -> void:
	if not _round_active:
		return
	if _is_press(event):
		_silence_lawyer(entry)

func _silence_lawyer(entry: Dictionary) -> void:
	if not entry["alive"]:
		return
	entry["alive"] = false
	var area: Area2D = entry["node"]
	area.input_pickable = false
	_gavel_bang(Vector2(area.position.x, _slot_up_y - _lawyer_h * 0.5))
	_play_bang()
	_retreat_node(area, entry)

func _retreat_lawyer(entry: Dictionary) -> void:
	# Lawyer gives up and ducks back down on its own (no gavel bang).
	if not entry["alive"]:
		return
	entry["alive"] = false
	var area: Area2D = entry["node"]
	area.input_pickable = false
	_retreat_node(area, entry)

func _retreat_node(area: Area2D, entry: Dictionary) -> void:
	var tw := create_tween()
	tw.tween_property(area, "position:y", _slot_hidden_y, RETREAT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_lawyers.erase(entry)
		if is_instance_valid(area):
			area.queue_free()
	)

func _freeze_lawyers() -> void:
	for entry in _lawyers:
		entry["alive"] = false
		var area: Area2D = entry["node"]
		if is_instance_valid(area):
			area.input_pickable = false

func _pick_free_slot() -> int:
	var taken: Dictionary = {}
	for entry in _lawyers:
		if entry["alive"]:
			taken[entry["slot"]] = true
	var free_slots: Array[int] = []
	for i in range(N_SLOTS):
		if not taken.has(i):
			free_slots.append(i)
	if free_slots.is_empty():
		return -1
	return free_slots[randi() % free_slots.size()]

# ---------------------------------------------------------------------------
# GAVEL BANG VFX (placeholder Spr_Fuu_Gavel + "BANG!" pop)
# ---------------------------------------------------------------------------

func _gavel_bang(pos: Vector2) -> void:
	var fx := Node2D.new()
	fx.name = "GavelBang"
	add_child(fx)
	fx.position = pos
	fx.scale = Vector2(0.5, 0.5)

	# Gavel head + handle placeholder.
	var gavel := Node2D.new()
	gavel.name = "Spr_Fuu_Gavel"
	fx.add_child(gavel)
	var head := Polygon2D.new()
	head.color = BENCH_TRIM
	head.polygon = PackedVector2Array([
		Vector2(-34, -16), Vector2(34, -16), Vector2(34, 16), Vector2(-34, 16),
	])
	gavel.add_child(head)
	var handle := Polygon2D.new()
	handle.color = BENCH_WOOD
	handle.polygon = PackedVector2Array([
		Vector2(-6, 12), Vector2(6, 12), Vector2(14, 64), Vector2(-14, 64),
	])
	gavel.add_child(handle)

	var bang := Label.new()
	bang.text = "BANG!"
	_style_label(bang, 34, UM_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	bang.size = Vector2(220, 48)
	bang.position = Vector2(-110, -88)
	fx.add_child(bang)

	var tw := create_tween()
	tw.tween_property(fx, "scale", Vector2(1.25, 1.25), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(fx, "modulate:a", 0.0, 0.3)
	tw.tween_callback(fx.queue_free)

# ---------------------------------------------------------------------------
# INPUT FALLBACK — manual hit-test (works for mouse + touch even if physics
# picking is unavailable). Idempotent via each lawyer's "alive" flag, so it can
# never double-process a tap already handled by Area2D.input_event.
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _round_active or not _is_press(event):
		return
	var pos: Vector2 = (event as InputEventMouse).position if event is InputEventMouse \
		else (event as InputEventScreenTouch).position
	for entry in _lawyers:
		if not entry["alive"]:
			continue
		var area: Area2D = entry["node"]
		var centre: Vector2 = area.global_position + Vector2(0, -_lawyer_h * 0.5)
		var rect := Rect2(centre - Vector2(_lawyer_w, _lawyer_h) * 0.5, Vector2(_lawyer_w, _lawyer_h))
		if rect.has_point(pos):
			_silence_lawyer(entry)
			return

func _is_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false

# ---------------------------------------------------------------------------
# STANDALONE RETRY (F6 only) — reset in place; never change_scene.
# ---------------------------------------------------------------------------

func _restart_round() -> void:
	for entry in _lawyers:
		var area: Area2D = entry["node"]
		if is_instance_valid(area):
			area.queue_free()
	_lawyers.clear()
	_finished = false        # clear the base guard so win()/lose() can fire again
	_chaos = 0.0
	_elapsed = 0.0
	_spawn_timer = 0.4
	_mistrial_triggered = false
	_result_label.visible = false
	_retry_button.visible = false
	_apply_layout()
	_update_chaos_meter()
	_round_active = true
	# Restart the shared HUD timer for the new attempt.
	if _solo_hud != null:
		_solo_hud.start(actual_duration())

# ---------------------------------------------------------------------------
# HUD-ON-SCREEN: chaos meter + countdown
# ---------------------------------------------------------------------------

func _update_chaos_meter() -> void:
	var frac: float = clampf(_chaos / max_chaos, 0.0, 1.0)
	var full_h: float = _meter_bg.size.y
	var fill_h: float = full_h * frac
	_meter_fill.size = Vector2(_meter_bg.size.x, fill_h)
	_meter_fill.position = Vector2(_meter_bg.position.x, _meter_bg.position.y + (full_h - fill_h))
	var c: Color
	if frac < 0.5:
		c = CHAOS_LOW.lerp(CHAOS_MID, frac / 0.5)
	else:
		c = CHAOS_MID.lerp(CHAOS_HIGH, (frac - 0.5) / 0.5)
	_meter_fill.color = c
	_meter_label.text = "CHAOS %d%%" % int(round(frac * 100.0))

func _current_spawn_interval() -> float:
	var t: float = clampf(_elapsed / _round_len, 0.0, 1.0)
	return lerpf(spawn_interval_start, spawn_interval_min, t)

# ---------------------------------------------------------------------------
# SCENE CONSTRUCTION (all in code, laid out from the viewport size)
# ---------------------------------------------------------------------------

func _build_scene() -> void:
	# Background wall.
	_bg = ColorRect.new()
	_bg.name = "Bg"
	_bg.color = UM_NAVY
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# Upper wall panel (slightly darker) for a courtroom-wall feel.
	_wall = ColorRect.new()
	_wall.name = "Wall"
	_wall.color = UM_NAVY_DARK
	_wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wall)

	# Judge (the player) — drawn behind the bench.
	_judge = Node2D.new()
	_judge.name = "Spr_Fuu_Judge"
	add_child(_judge)
	_build_judge_visual()

	# Lawyer layer — added BEFORE the bench so the bench occludes their lower
	# bodies and they look like they rise from behind it.
	_lawyer_layer = Node2D.new()
	_lawyer_layer.name = "LawyerLayer"
	add_child(_lawyer_layer)

	# Judge's bench — drawn in front of the lawyers.
	_bench = Node2D.new()
	_bench.name = "Spr_Fuu_Bench"
	add_child(_bench)
	var bench_front := Polygon2D.new()
	bench_front.name = "BenchFront"
	_bench.add_child(bench_front)
	var bench_trim := Polygon2D.new()
	bench_trim.name = "BenchTrim"
	_bench.add_child(bench_trim)

	# Chaos meter (right edge).
	_meter_bg = ColorRect.new()
	_meter_bg.name = "ChaosMeterBg"
	_meter_bg.color = Color(0.0, 0.0, 0.0, 0.45)
	_meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_meter_bg)

	_meter_fill = ColorRect.new()
	_meter_fill.name = "ChaosMeterFill"
	_meter_fill.color = CHAOS_LOW
	_meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_meter_fill)

	_meter_label = Label.new()
	_meter_label.name = "ChaosMeterLabel"
	_style_label(_meter_label, 20, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_meter_label)

	# Title + countdown (kept below the shared HUD's top strip).
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "ORDER IN THE COURT  -  Faculty of Law"
	_style_label(_title_label, 24, UM_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_title_label)

	# Verdict banner (hidden until the round ends).
	_result_label = Label.new()
	_result_label.name = "ResultLabel"
	_style_label(_result_label, 72, UM_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_result_label.visible = false
	add_child(_result_label)

	# Retry button (standalone testing only).
	_retry_button = Button.new()
	_retry_button.name = "RetryButton"
	_retry_button.text = "RETRY"
	_retry_button.visible = false
	_retry_button.pressed.connect(_restart_round)
	add_child(_retry_button)

	# Optional gavel-bang SFX (null-safe; file not delivered yet).
	if ResourceLoader.exists(SFX_BANG_PATH):
		_sfx = AudioStreamPlayer.new()
		_sfx.stream = load(SFX_BANG_PATH) as AudioStream
		add_child(_sfx)

func _build_judge_visual() -> void:
	# Simple seated-judge placeholder: robe + head + a tiny gavel in hand.
	var robe := Polygon2D.new()
	robe.color = UM_NAVY_DARK
	robe.polygon = PackedVector2Array([
		Vector2(-90, 0), Vector2(90, 0), Vector2(60, -150), Vector2(-60, -150),
	])
	_judge.add_child(robe)
	var head := Polygon2D.new()
	head.color = SKIN_COLOR
	head.polygon = _circle_points(Vector2(0, -180), 40, 16)
	_judge.add_child(head)
	var gavel := Polygon2D.new()
	gavel.color = UM_GOLD
	gavel.polygon = PackedVector2Array([
		Vector2(70, -70), Vector2(118, -70), Vector2(118, -52), Vector2(70, -52),
	])
	_judge.add_child(gavel)

# ---------------------------------------------------------------------------
# RESPONSIVE LAYOUT
# ---------------------------------------------------------------------------

func _apply_layout() -> void:
	_vp = get_viewport_rect().size

	# Background fills everything.
	_bg.position = Vector2.ZERO
	_bg.size = _vp

	# Upper wall.
	_wall.position = Vector2.ZERO
	_wall.size = Vector2(_vp.x, _vp.y * 0.5)

	# Bench occupies the lower part of the screen.
	_bench_top = _vp.y * 0.66
	var bench_front: Polygon2D = _bench.get_node("BenchFront")
	bench_front.color = BENCH_WOOD
	bench_front.polygon = PackedVector2Array([
		Vector2(0, _bench_top), Vector2(_vp.x, _bench_top),
		Vector2(_vp.x, _vp.y), Vector2(0, _vp.y),
	])
	var bench_trim: Polygon2D = _bench.get_node("BenchTrim")
	bench_trim.color = BENCH_TRIM
	bench_trim.polygon = PackedVector2Array([
		Vector2(0, _bench_top), Vector2(_vp.x, _bench_top),
		Vector2(_vp.x, _bench_top + _vp.y * 0.035), Vector2(0, _bench_top + _vp.y * 0.035),
	])

	# Judge sits centred, behind the bench.
	_judge.position = Vector2(_vp.x * 0.5, _bench_top + _vp.y * 0.02)
	_judge.scale = Vector2.ONE * clampf(_vp.y / 720.0, 0.6, 1.4)

	# Lawyer sizing + slot geometry, derived from the viewport.
	_lawyer_w = clampf(_vp.x * 0.11, 70.0, 150.0)
	_lawyer_h = _lawyer_w * 1.7
	_slot_up_y = _bench_top          # origin sits on the bench line; body rises above
	_slot_hidden_y = _bench_top + _lawyer_h  # fully tucked behind the bench

	_slot_x.clear()
	var margin: float = _vp.x * 0.09
	var usable: float = _vp.x - margin * 2.0
	for i in range(N_SLOTS):
		var t: float = 0.5 if N_SLOTS == 1 else float(i) / float(N_SLOTS - 1)
		_slot_x.append(margin + usable * t)

	# Reposition any live lawyers onto their slots.
	for entry in _lawyers:
		var area: Area2D = entry["node"]
		if is_instance_valid(area):
			var y: float = _slot_up_y if entry["alive"] else _slot_hidden_y
			area.position = Vector2(_slot_x[entry["slot"]], y)

	# Chaos meter (right edge), comfortably clear of the HUD.
	var meter_w: float = clampf(_vp.x * 0.05, 40.0, 80.0)
	var meter_h: float = _vp.y * 0.46
	var meter_x: float = _vp.x - meter_w - _vp.x * 0.03
	var meter_y: float = _vp.y * 0.2
	_meter_bg.position = Vector2(meter_x, meter_y)
	_meter_bg.size = Vector2(meter_w, meter_h)
	_meter_label.position = Vector2(meter_x - meter_w * 1.4, meter_y - _vp.y * 0.06)
	_meter_label.size = Vector2(meter_w * 3.8, _vp.y * 0.05)

	# Title + countdown, parked just under the shared HUD's top strip.
	var top_safe: float = _vp.y * 0.16
	_title_label.position = Vector2(_vp.x * 0.5 - _vp.x * 0.4, top_safe)
	_title_label.size = Vector2(_vp.x * 0.8, _vp.y * 0.06)

	# Verdict banner centred in the play area (above the HUD's centre flash).
	_result_label.position = Vector2(_vp.x * 0.5 - _vp.x * 0.45, _vp.y * 0.30)
	_result_label.size = Vector2(_vp.x * 0.9, _vp.y * 0.16)
	_result_label.pivot_offset = _result_label.size * 0.5

	# Retry button under the banner.
	var btn_w: float = _vp.x * 0.22
	var btn_h: float = _vp.y * 0.08
	_retry_button.position = Vector2(_vp.x * 0.5 - btn_w * 0.5, _vp.y * 0.5)
	_retry_button.size = Vector2(btn_w, btn_h)
	if _font != null:
		_retry_button.add_theme_font_override("font", _font)
	_retry_button.add_theme_font_size_override("font_size", int(btn_h * 0.45))

	_update_chaos_meter()

# ---------------------------------------------------------------------------
# SMALL HELPERS
# ---------------------------------------------------------------------------

func _style_label(label: Label, size: int, color: Color, align: int) -> void:
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _play_bang() -> void:
	if _sfx != null:
		_sfx.play()

func _circle_points(centre: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a: float = TAU * float(i) / float(segments)
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)
	return pts
