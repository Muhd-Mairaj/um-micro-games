# =============================================================================
# minigames/catch_the_cash/CatchTheCash.gd
# =============================================================================
# FACULTY: Faculty of Business & Accountancy  (Fakulti Perniagaan dan Perakaunan / FPP)
# AUTHOR : Alshamrani  ("Catch the Cash" — cash-catching micro-game)
#
# PREMISE:
#   You are a UM Business student catching cash raining down on campus. Slide
#   the wallet at the bottom with your finger/mouse. Green "RM" ringgit notes
#   are GOOD (+balance); red "TAX" papers are BAD (-balance). Catch enough
#   ringgit to hit the target before the ~10s timer ends.
#     WIN  -> balance reaches target_score              ("PROFIT!  YOU WIN")
#     LOSE -> timer ends below target, or balance hits 0 ("BANKRUPT!")
#
# HOW THIS HOOKS INTO THE SHARED FRAMEWORK (see shared/MiniGameBase.gd):
#   - extends MiniGameBase and overrides setup() (NOT _ready()).
#   - base_duration drives the shared HUD countdown bar via actual_duration();
#     this game adds NO timer of its own — the shared HUD owns the countdown.
#   - WIN is an instant event the moment balance reaches the target. The two
#     LOSES are: balance hits 0 (instant BANKRUPT), or the shared HUD timer runs
#     out below target — GameManager already calls lose() on that timeout and the
#     HUD shows the result, so we do NOT re-handle "time's up" here.
#   - Standalone (F6) reuses the SAME shared HUD (shared/HUD.tscn) for its timer
#     bar, so there is no second timer implementation anywhere.
#   - The Stitcher registers this path in GameManager.gd in Week 12:
#       "res://minigames/catch_the_cash/CatchTheCash.tscn",
#
# SCENE SETUP (CatchTheCash.tscn):
# -----------------------------------------------
#   CatchTheCash  (Node2D)   <- root only; attach this script.
#   Everything else (background, wallet, falling notes, balance bar, labels,
#   retry button) is built IN CODE and laid out responsively from
#   get_viewport_rect().size. Placeholder art is drawn with ColorRect / Polygon2D
#   and plain ASCII Labels (Spr_Fpp_Wallet, Spr_Fpp_Ringgit, Spr_Fpp_Tax) — swap
#   for real sprites when the Art Director delivers them.
# =============================================================================

extends MiniGameBase

# ---------------------------------------------------------------------------
# TUNING — exported for the Systems Balancer (Week 12 difficulty tuning).
# ---------------------------------------------------------------------------

## Total round length at time_scale 1.0. Also feeds the shared HUD bar.
@export var round_time: float = 10.0

## Seconds between falling items.
@export var spawn_interval: float = 0.55

## Fall speed in px/sec at the 720p reference height (scaled to the viewport).
@export var fall_speed: float = 360.0

## Balance gained per ringgit note caught.
@export var good_value: int = 10

## Balance lost per TAX paper caught.
@export var bad_penalty: int = 15

## Balance needed to win.
@export var target_score: int = 100

## Probability (0..1) that a spawned item is a BAD tax paper.
@export var bad_spawn_chance: float = 0.30

## Starting balance buffer so an early tax doesn't instantly bankrupt you.
## (Extra knob beyond the required set — keep it below target_score.)
@export var starting_balance: int = 20

# ---------------------------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------------------------

## UM palette (shared with Game 1 for a consistent look; no STYLE_GUIDE.md yet).
const UM_NAVY:       Color = Color(0.0,   0.184, 0.424, 1.0)  # #002F6C
const UM_NAVY_DARK:  Color = Color(0.0,   0.122, 0.282, 1.0)
const UM_GOLD:       Color = Color(0.992, 0.725, 0.075, 1.0)  # #FDB913
const RINGGIT_GREEN: Color = Color(0.18,  0.62,  0.32,  1.0)
const TAX_RED:       Color = Color(0.83,  0.20,  0.20,  1.0)
const WALLET_BROWN:  Color = Color(0.42,  0.26,  0.14,  1.0)
const WALLET_TRIM:   Color = Color(0.992, 0.725, 0.075, 1.0)
const WHITE:         Color = Color(0.95,  0.96,  0.99,  1.0)

## Optional font (real shared asset). Loaded null-safely in setup().
const FONT_PATH: String = "res://assets/Font/Kenney Future.ttf"

## Optional SFX from this minigame's own folder (snake_case per repo convention).
## Not delivered yet — loaded null-safely so the game never breaks.
const SFX_GOOD_PATH: String = "res://minigames/catch_the_cash/assets/sfx_fpp_coin.wav"
const SFX_BAD_PATH:  String = "res://minigames/catch_the_cash/assets/sfx_fpp_tax.wav"

# ---------------------------------------------------------------------------
# RUNTIME STATE
# ---------------------------------------------------------------------------

var _round_active: bool = false
var _balance: int = 20
var _spawn_timer: float = 0.0
var _wallet_target_x: float = 640.0
var _standalone: bool = false
## Standalone (F6) only: an instance of the shared HUD so solo runs use the same
## timer bar as the hub instead of a home-grown one.
var _solo_hud: CanvasLayer = null

## One entry per live item: { "node": Node2D, "bad": bool }.
var _items: Array = []

# ---------------------------------------------------------------------------
# LAYOUT (recomputed from the viewport in _apply_layout()).
# ---------------------------------------------------------------------------

var _vp: Vector2 = Vector2(1280, 720)
var _item_w: float = 90.0
var _item_h: float = 56.0
var _wall_w: float = 200.0
var _wall_h: float = 80.0
var _wallet_y: float = 620.0
var _fall_speed_px: float = 360.0

# ---------------------------------------------------------------------------
# PERSISTENT NODE REFERENCES (created in _build_scene()).
# ---------------------------------------------------------------------------

var _font: Font = null
var _sfx_good: AudioStreamPlayer = null
var _sfx_bad: AudioStreamPlayer = null
var _bg: ColorRect
var _ground: ColorRect
var _item_layer: Node2D
var _wallet: Node2D
var _balance_label: Label
var _target_label: Label
var _title_label: Label
var _bar_bg: ColorRect
var _bar_fill: ColorRect
var _result_label: Label
var _retry_button: Button

# ---------------------------------------------------------------------------
# MINIGAMEBASE CONTRACT
# ---------------------------------------------------------------------------

func setup() -> void:
	# Feed the shared HUD: base_duration -> actual_duration() -> countdown bar.
	base_duration = round_time
	instruction_text = "Catch the RM, dodge the TAX! Slide the wallet to reach the target."

	# Sanity-guard tuning knobs so stray Inspector values can't break the round.
	good_value = maxi(good_value, 1)
	target_score = maxi(target_score, 1)
	# Keep the start strictly below the target (and above 0) so the round can
	# never instant-win on frame one or start already bankrupt.
	starting_balance = clampi(starting_balance, 1, maxi(target_score - 1, 1))
	spawn_interval = maxf(spawn_interval, 0.05)
	bad_spawn_chance = clampf(bad_spawn_chance, 0.0, 1.0)

	# Keep the game winnable as the hub shrinks the round with time_scale: scale
	# the gap to the target down so the catches needed track the shorter window.
	# (actual_duration() = base_duration / time_scale, so later rounds are shorter
	# while spawn rate and note value stay in real time. At time_scale 1.0 the
	# target is unchanged; e.g. ts 1.45 -> ~RM 76.)
	target_score = starting_balance + ceili(float(target_score - starting_balance) / time_scale)
	target_score = maxi(target_score, starting_balance + good_value)

	# Standalone (F6) vs in the hub — gates the solo HUD + retry button.
	_standalone = get_tree().current_scene == self

	# Optional shared font (null-safe).
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as Font

	_build_scene()
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)

	# Start the round.
	_balance = starting_balance
	_spawn_timer = 0.0
	_wallet_target_x = _vp.x * 0.5
	_round_active = true
	_update_balance_ui()

	# Standalone testing: reuse the real shared HUD so even F6 runs off the one
	# timer bar; its countdown running out below target is the loss (as in the hub).
	if _standalone:
		_start_solo_hud()

# Wallet follows the horizontal mouse / touch position (desktop + mobile).
func _input(event: InputEvent) -> void:
	if not _round_active:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		_wallet_target_x = event.position.x
	elif event is InputEventScreenTouch and event.pressed:
		_wallet_target_x = event.position.x

func _process(delta: float) -> void:
	if _finished or not _round_active:
		return

	# Wallet tracks the pointer, clamped fully inside the screen.
	var half: float = _wall_w * 0.5
	_wallet.position = Vector2(clampf(_wallet_target_x, half, _vp.x - half), _wallet_y)

	# Spawn falling items.
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_item()
		_spawn_timer = spawn_interval

	# Move items, resolve catches and misses (simple AABB).
	var wallet_rect: Rect2 = _wallet_rect()
	for entry in _items.duplicate():
		var item: Node2D = entry["node"]
		item.position.y += _fall_speed_px * delta
		var item_rect := Rect2(item.position - Vector2(_item_w, _item_h) * 0.5, Vector2(_item_w, _item_h))
		if item_rect.intersects(wallet_rect):
			if entry["bad"]:
				_balance -= bad_penalty
				_play(_sfx_bad)
				_pop_text(item.position, "-%d" % bad_penalty, TAX_RED)
			else:
				_balance += good_value
				_play(_sfx_good)
				_pop_text(item.position, "+%d" % good_value, UM_GOLD)
			_items.erase(entry)
			item.queue_free()
		elif item.position.y - _item_h * 0.5 > _vp.y:
			# Missed — fell off the bottom. No penalty for missing.
			_items.erase(entry)
			item.queue_free()

	_update_balance_ui()

	# Outcomes we own: instant WIN on hitting target, instant BANKRUPT at zero.
	# "Time's up below target" is handled by the shared HUD timer (GameManager
	# calls lose() on timeout) — we deliberately do NOT re-implement it here.
	if _balance >= target_score:
		_win()
		return
	if _balance <= 0:
		_lose("BANKRUPT!")

# ---------------------------------------------------------------------------
# OUTCOMES
# ---------------------------------------------------------------------------

func _win() -> void:
	if _finished:
		return
	_round_active = false
	_show_result("PROFIT!  YOU WIN", UM_GOLD)
	win()

func _lose(text: String) -> void:
	if _finished:
		return
	_round_active = false
	_show_result(text, TAX_RED)
	lose()

func _show_result(text: String, color: Color) -> void:
	_result_label.text = text
	_result_label.add_theme_color_override("font_color", color)
	_result_label.visible = true
	_result_label.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(_result_label, "scale", Vector2(1.0, 1.0), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _standalone:
		_retry_button.visible = true

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
	# Mirror GameManager: time running out below target is the loss.
	_solo_hud.timed_out.connect(func() -> void: lose())
	# No GameManager in solo, so reflect our own outcome on the shared HUD + retry.
	game_won.connect(func() -> void: _on_solo_finished(true))
	game_lost.connect(func() -> void: _on_solo_finished(false))

func _on_solo_finished(won: bool) -> void:
	_round_active = false
	if is_instance_valid(_solo_hud):
		_solo_hud.show_result(won)
	_retry_button.visible = true

# ---------------------------------------------------------------------------
# FALLING ITEMS
# ---------------------------------------------------------------------------

func _spawn_item() -> void:
	var is_bad: bool = randf() < bad_spawn_chance

	var item := Node2D.new()
	item.name = "Spr_Fpp_Tax" if is_bad else "Spr_Fpp_Ringgit"

	var rect := ColorRect.new()
	rect.color = TAX_RED if is_bad else RINGGIT_GREEN
	rect.size = Vector2(_item_w, _item_h)
	rect.position = Vector2(_item_w, _item_h) * -0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(rect)

	# Gold/white border strip so the note reads as currency / paperwork.
	var strip := ColorRect.new()
	strip.color = UM_GOLD if not is_bad else WHITE
	strip.size = Vector2(_item_w, _item_h * 0.16)
	strip.position = Vector2(-_item_w * 0.5, -_item_h * 0.5)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(strip)

	var lbl := Label.new()
	lbl.text = "TAX" if is_bad else "RM"
	_style_label(lbl, int(_item_h * 0.5), WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.size = Vector2(_item_w, _item_h)
	lbl.position = Vector2(_item_w, _item_h) * -0.5
	item.add_child(lbl)

	item.position = Vector2(randf_range(_item_w, _vp.x - _item_w), -_item_h)
	_item_layer.add_child(item)
	_items.append({"node": item, "bad": is_bad})

func _wallet_rect() -> Rect2:
	return Rect2(_wallet.position - Vector2(_wall_w, _wall_h) * 0.5, Vector2(_wall_w, _wall_h))

# Small floating +/- feedback at the catch point.
func _pop_text(pos: Vector2, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	_style_label(lbl, int(_item_h * 0.6), color, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.size = Vector2(_item_w * 2.0, _item_h)
	lbl.position = pos + Vector2(-_item_w, -_item_h)
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - _vp.y * 0.08, 0.4)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)

# ---------------------------------------------------------------------------
# STANDALONE RETRY (F6 only) — reset in place; never change_scene.
# ---------------------------------------------------------------------------

func _restart_round() -> void:
	for entry in _items:
		var item: Node2D = entry["node"]
		if is_instance_valid(item):
			item.queue_free()
	_items.clear()
	_finished = false
	_balance = starting_balance
	_spawn_timer = 0.0
	_result_label.visible = false
	_retry_button.visible = false
	_apply_layout()
	_update_balance_ui()
	_round_active = true
	# Restart the shared HUD timer for the new attempt.
	if _solo_hud != null:
		_solo_hud.start(actual_duration())

# ---------------------------------------------------------------------------
# HUD-ON-SCREEN: balance + target (the countdown is the shared HUD's job)
# ---------------------------------------------------------------------------

func _update_balance_ui() -> void:
	_balance_label.text = "BALANCE:  RM %d" % _balance
	_target_label.text = "TARGET:  RM %d" % target_score
	var frac: float = clampf(float(_balance) / float(target_score), 0.0, 1.0)
	_bar_fill.size = Vector2(_bar_bg.size.x * frac, _bar_bg.size.y)
	_bar_fill.position = _bar_bg.position
	_bar_fill.color = RINGGIT_GREEN if _balance >= starting_balance else TAX_RED

# ---------------------------------------------------------------------------
# SCENE CONSTRUCTION (all in code, laid out from the viewport size)
# ---------------------------------------------------------------------------

func _build_scene() -> void:
	_bg = ColorRect.new()
	_bg.name = "Bg"
	_bg.color = UM_NAVY
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# Campus ground band along the bottom.
	_ground = ColorRect.new()
	_ground.name = "Ground"
	_ground.color = UM_NAVY_DARK
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ground)

	# Falling items live behind the wallet so a catch looks like it lands inside.
	_item_layer = Node2D.new()
	_item_layer.name = "ItemLayer"
	add_child(_item_layer)

	# Wallet / basket (player-controlled).
	_wallet = Node2D.new()
	_wallet.name = "Spr_Fpp_Wallet"
	add_child(_wallet)
	var body := Polygon2D.new()
	body.name = "WalletBody"
	_wallet.add_child(body)
	var rim := Polygon2D.new()
	rim.name = "WalletRim"
	_wallet.add_child(rim)

	# Balance progress bar.
	_bar_bg = ColorRect.new()
	_bar_bg.name = "BalanceBarBg"
	_bar_bg.color = Color(0.0, 0.0, 0.0, 0.45)
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.name = "BalanceBarFill"
	_bar_fill.color = RINGGIT_GREEN
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_fill)

	# Labels.
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "CATCH THE CASH  -  Faculty of Business & Accountancy"
	_style_label(_title_label, 24, UM_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_title_label)

	_balance_label = Label.new()
	_balance_label.name = "BalanceLabel"
	_style_label(_balance_label, 26, WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_balance_label)

	_target_label = Label.new()
	_target_label.name = "TargetLabel"
	_style_label(_target_label, 22, UM_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(_target_label)

	_result_label = Label.new()
	_result_label.name = "ResultLabel"
	_style_label(_result_label, 68, UM_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_result_label.visible = false
	add_child(_result_label)

	_retry_button = Button.new()
	_retry_button.name = "RetryButton"
	_retry_button.text = "RETRY"
	_retry_button.visible = false
	_retry_button.pressed.connect(_restart_round)
	add_child(_retry_button)

	# Optional SFX (null-safe; files not delivered yet).
	if ResourceLoader.exists(SFX_GOOD_PATH):
		_sfx_good = AudioStreamPlayer.new()
		_sfx_good.stream = load(SFX_GOOD_PATH) as AudioStream
		add_child(_sfx_good)
	if ResourceLoader.exists(SFX_BAD_PATH):
		_sfx_bad = AudioStreamPlayer.new()
		_sfx_bad.stream = load(SFX_BAD_PATH) as AudioStream
		add_child(_sfx_bad)

# ---------------------------------------------------------------------------
# RESPONSIVE LAYOUT
# ---------------------------------------------------------------------------

func _apply_layout() -> void:
	_vp = get_viewport_rect().size

	_bg.position = Vector2.ZERO
	_bg.size = _vp

	_ground.position = Vector2(0, _vp.y * 0.82)
	_ground.size = Vector2(_vp.x, _vp.y * 0.18)

	# Item + wallet sizing, scaled to the viewport.
	_item_w = clampf(_vp.x * 0.07, 60.0, 130.0)
	_item_h = _item_w * 0.62
	_wall_w = clampf(_vp.x * 0.16, 120.0, 260.0)
	_wall_h = clampf(_vp.y * 0.10, 60.0, 120.0)
	_wallet_y = _vp.y * 0.85
	_fall_speed_px = fall_speed * (_vp.y / 720.0)

	# Wallet shape (basket: wider at the top opening).
	var hw: float = _wall_w * 0.5
	var hh: float = _wall_h * 0.5
	var body: Polygon2D = _wallet.get_node("WalletBody")
	body.color = WALLET_BROWN
	body.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh),
		Vector2(hw * 0.72, hh), Vector2(-hw * 0.72, hh),
	])
	var rim: Polygon2D = _wallet.get_node("WalletRim")
	rim.color = WALLET_TRIM
	rim.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh),
		Vector2(hw, -hh + _wall_h * 0.18), Vector2(-hw, -hh + _wall_h * 0.18),
	])
	_wallet.position = Vector2(clampf(_wallet_target_x, hw, _vp.x - hw), _wallet_y)

	# Reposition live items horizontally back inside if the window shrank.
	for entry in _items:
		var item: Node2D = entry["node"]
		if is_instance_valid(item):
			item.position.x = clampf(item.position.x, _item_w, _vp.x - _item_w)

	# Balance progress bar (centred, below the HUD's top strip).
	var top_safe: float = _vp.y * 0.16
	var bar_w: float = _vp.x * 0.5
	var bar_h: float = _vp.y * 0.03
	_bar_bg.position = Vector2(_vp.x * 0.5 - bar_w * 0.5, top_safe + _vp.y * 0.06)
	_bar_bg.size = Vector2(bar_w, bar_h)

	# Labels.
	_title_label.position = Vector2(_vp.x * 0.1, top_safe)
	_title_label.size = Vector2(_vp.x * 0.8, _vp.y * 0.05)
	_balance_label.position = Vector2(_vp.x * 0.06, top_safe + _vp.y * 0.10)
	_balance_label.size = Vector2(_vp.x * 0.4, _vp.y * 0.05)
	_target_label.position = Vector2(_vp.x * 0.54, top_safe + _vp.y * 0.10)
	_target_label.size = Vector2(_vp.x * 0.4, _vp.y * 0.05)

	_result_label.position = Vector2(_vp.x * 0.5 - _vp.x * 0.45, _vp.y * 0.36)
	_result_label.size = Vector2(_vp.x * 0.9, _vp.y * 0.16)
	_result_label.pivot_offset = _result_label.size * 0.5

	var btn_w: float = _vp.x * 0.22
	var btn_h: float = _vp.y * 0.08
	_retry_button.position = Vector2(_vp.x * 0.5 - btn_w * 0.5, _vp.y * 0.55)
	_retry_button.size = Vector2(btn_w, btn_h)
	if _font != null:
		_retry_button.add_theme_font_override("font", _font)
	_retry_button.add_theme_font_size_override("font_size", int(btn_h * 0.45))

	_update_balance_ui()

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

func _play(player: AudioStreamPlayer) -> void:
	if player != null:
		player.play()
