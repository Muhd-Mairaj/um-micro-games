# =============================================================================
# minigames/circuit_lab/CircuitLab.gd
# =============================================================================
# FACULTY: Faculty of Engineering
# PREMISE: A DC loop (battery → bulb) has SEVERAL missing segments. Fix them one
#          at a time by tapping the tray piece that lets current through. Fill
#          every gap to light the bulb (win). A wrong/short pick — or a timeout —
#          loses. Each round randomizes gap count/positions, the correct piece,
#          and the decoy set; difficulty scales with GameManager's time_scale.
#
# Fully procedural (drawn in _draw, like cavity_chase) — no art assets. Root node
# is a Node2D named "CircuitLab".
# =============================================================================

extends MiniGameBase

# ---------------------------------------------------------------------------
# LAYOUT — RESPONSIVE
# ---------------------------------------------------------------------------
# Reference design is 1280x720. Every layout value below is authored against
# that reference, then scaled by the live viewport size in _layout(). At
# exactly 1280x720 the scale factors are 1.0, so the result is pixel-identical
# to the original hardcoded layout; on any other viewport the loop, tray, and
# grid fill and centre correctly. The HUD overlay still owns the top strip.
const REF_SIZE: Vector2 = Vector2(1280.0, 720.0)

# Reference (1280x720) layout anchors — formerly the hardcoded constants.
const REF_LOOP_LEFT: float   = 340.0
const REF_LOOP_RIGHT: float  = 940.0
const REF_LOOP_TOP: float    = 200.0
const REF_LOOP_BOTTOM: float = 410.0
const REF_GAP_HALF: float    = 42.0      # half-length of a missing segment

const REF_TRAY_Y: float      = 512.0
const REF_SLOT_W: float      = 150.0
const REF_SLOT_H: float      = 132.0
const REF_SLOT_GAP: float    = 48.0

# Live layout values, recomputed by _layout() from the current viewport size.
# Initialised to the reference so any draw before the first _layout() still works.
var VIEW: Vector2        = REF_SIZE
var LOOP_LEFT: float     = REF_LOOP_LEFT
var LOOP_RIGHT: float    = REF_LOOP_RIGHT
var LOOP_TOP: float      = REF_LOOP_TOP
var LOOP_BOTTOM: float   = REF_LOOP_BOTTOM
var GAP_HALF: float      = REF_GAP_HALF

var TRAY_Y: float        = REF_TRAY_Y
var SLOT_W: float        = REF_SLOT_W
var SLOT_H: float        = REF_SLOT_H
var SLOT_GAP: float      = REF_SLOT_GAP

# ---------------------------------------------------------------------------
# COMPONENT CATALOG — only conductors complete the circuit.
# ---------------------------------------------------------------------------
const CONDUCTORS: Array = ["wire", "closed_switch"]
const INSULATORS: Array = ["open_switch", "capacitor", "broken_wire"]

# ---------------------------------------------------------------------------
# COLOURS
# ---------------------------------------------------------------------------
const BG: Color          = Color(0.06, 0.09, 0.15)
const GRID: Color        = Color(0.22, 0.38, 0.55, 0.16)
const WIRE: Color        = Color(0.76, 0.85, 0.95)
const WIRE_LIVE: Color   = Color(1.00, 0.88, 0.32)
const BATTERY: Color     = Color(0.95, 0.86, 0.40)
const BULB_OFF: Color    = Color(0.48, 0.50, 0.56)
const BULB_ON: Color     = Color(1.00, 0.92, 0.42)
const SLOT_BG: Color     = Color(0.12, 0.18, 0.28)
const SLOT_BORDER: Color = Color(0.40, 0.60, 0.82)
const GOOD: Color        = Color(0.22, 0.80, 0.34)
const BAD: Color         = Color(0.92, 0.26, 0.22)
const SPARK: Color       = Color(1.00, 0.80, 0.25)
const TEXT: Color        = Color(0.85, 0.90, 1.00)

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------
var _gaps: Array = []           # each: { center: Vector2, horizontal: bool, filled: bool }
var _active_gap: int = 0
var _num_gaps: int = 2
var _slots: Array = []          # tray for the active gap: { rect, type, conducts }
var _resolved: bool = false     # round is over (win/lose triggered)
var _lit: bool = false          # all gaps filled → bulb on
var _wrong_slot: int = -1
var _active: bool = false       # input accepted only after GameManager's get-ready
var _font: Font

var _audio: AudioStreamPlayer
var _audio2: AudioStreamPlayer  # 2nd channel so the fail jingle can follow the explosion
var _sfx_fix: AudioStream       # a gap fixed
var _sfx_win: AudioStream       # all gaps fixed, bulb lights
var _sfx_wrong: AudioStream     # insulator picked
var _sfx_short: AudioStream     # short-circuit trap
var _sfx_negative: AudioStream  # fail jingle, follows the big explosion

var _anim: float = 0.0          # animation phase
var _elapsed: float = 0.0       # time since the round actually started
var _shake: float = 0.0         # remaining screen-shake time
var _sparks: Array = []         # each: { pos, dir, t, col, len }

# ---------------------------------------------------------------------------
# MINIGAMEBASE CONTRACT
# ---------------------------------------------------------------------------
func setup() -> void:
	instruction_text = "Light the bulb — fix every gap to complete the circuit!"
	# Compute the responsive layout up front so _build_round() (called below) and
	# the first _draw() use viewport-correct positions. Reconnect to size_changed
	# so the layout follows window resizes / different displays.
	_layout()
	var vp: Viewport = get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.connect(_on_viewport_resized)
	_font = load("res://assets/Font/Kenney Future.ttf")
	# SFX sourced from the repo's royalty-free 400 Sounds Pack.
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_audio2 = AudioStreamPlayer.new()
	add_child(_audio2)
	_sfx_fix = load("res://400 Sounds Pack/Weapons/weapon_equip_short.wav")
	_sfx_win = load("res://400 Sounds Pack/Retro/power_up.wav")
	_sfx_wrong = load("res://400 Sounds Pack/Retro/explosion_quick.wav")
	_sfx_short = load("res://400 Sounds Pack/Retro/explosion_large.wav")
	_sfx_negative = load("res://400 Sounds Pack/Musical Effects/8_bit_negative.wav")
	_build_round()
	base_duration = clampf(5.0 + 2.0 * _num_gaps, 8.0, 12.0)
	queue_redraw()

# Recompute every layout value from the live viewport size, scaled from the
# 1280x720 reference. At 1280x720 the scale factors are exactly 1.0, so every
# value equals its original constant and the layout is pixel-identical.
func _layout() -> void:
	var vp: Viewport = get_viewport()
	VIEW = vp.get_visible_rect().size if vp != null else REF_SIZE
	if VIEW.x <= 0.0 or VIEW.y <= 0.0:
		VIEW = REF_SIZE
	var sx: float = VIEW.x / REF_SIZE.x
	var sy: float = VIEW.y / REF_SIZE.y
	LOOP_LEFT   = REF_LOOP_LEFT * sx
	LOOP_RIGHT  = REF_LOOP_RIGHT * sx
	LOOP_TOP    = REF_LOOP_TOP * sy
	LOOP_BOTTOM = REF_LOOP_BOTTOM * sy
	# GAP_HALF / slot sizes scale with the smaller axis so shapes stay proportionate.
	var s_min: float = min(sx, sy)
	GAP_HALF = REF_GAP_HALF * s_min
	TRAY_Y   = REF_TRAY_Y * sy
	SLOT_W   = REF_SLOT_W * sx
	SLOT_H   = REF_SLOT_H * sy
	SLOT_GAP = REF_SLOT_GAP * sx

# Viewport resized (window maximised / moved to another display): recompute the
# layout, re-derive the active gaps' centres, and re-position the EXISTING tray
# slots (without re-randomising the puzzle) so the slot hit-test rectangles stay
# aligned with what's drawn.
func _on_viewport_resized() -> void:
	_layout()
	_reposition_gaps()
	_reposition_tray()
	queue_redraw()

# Re-lays the current tray slots at the new scale, preserving each slot's type
# and conducts flag (so the puzzle is unchanged). Mirrors _build_tray's centring
# math but never touches the random answer/decoy selection.
func _reposition_tray() -> void:
	var n: int = _slots.size()
	if n == 0:
		return
	var total_w: float = n * SLOT_W + (n - 1) * SLOT_GAP
	var start_x: float = (VIEW.x - total_w) / 2.0
	for i in range(n):
		_slots[i].rect = Rect2(start_x + i * (SLOT_W + SLOT_GAP), TRAY_Y, SLOT_W, SLOT_H)

# Re-derives gap centres in place after a resize, preserving each gap's edge and
# its relative position so _draw_circuit's edge-matching (is_equal_approx against
# LOOP_*) keeps working.
func _reposition_gaps() -> void:
	var sx: float = VIEW.x / REF_SIZE.x
	var sy: float = VIEW.y / REF_SIZE.y
	for g in _gaps:
		var ref_c: Vector2 = g.get("ref_center", g.center)
		g.center = Vector2(ref_c.x * sx, ref_c.y * sy)

func _build_round() -> void:
	# Harder rounds get more gaps as the game speeds up.
	_num_gaps = clampi(2 + int(floor((time_scale - 1.0) / 0.3)), 2, 4)
	var sx: float = VIEW.x / REF_SIZE.x
	var sy: float = VIEW.y / REF_SIZE.y
	var mid_y: float = (LOOP_TOP + LOOP_BOTTOM) / 2.0
	# Candidate gap spots on free segments (avoid battery on left-mid, bulb on top-mid).
	# ref_center stores the unscaled 1280x720 anchor so a later resize can re-derive
	# center exactly. The two interior X anchors (490, 790) scale by sx.
	var cands: Array = [
		{"center": Vector2(490.0 * sx, LOOP_BOTTOM), "ref_center": Vector2(490.0, REF_LOOP_BOTTOM), "horizontal": true},
		{"center": Vector2(790.0 * sx, LOOP_BOTTOM), "ref_center": Vector2(790.0, REF_LOOP_BOTTOM), "horizontal": true},
		{"center": Vector2(LOOP_RIGHT, mid_y), "ref_center": Vector2(REF_LOOP_RIGHT, (REF_LOOP_TOP + REF_LOOP_BOTTOM) / 2.0), "horizontal": false},
		{"center": Vector2(790.0 * sx, LOOP_TOP), "ref_center": Vector2(790.0, REF_LOOP_TOP), "horizontal": true},
	]
	cands.shuffle()
	_gaps.clear()
	for i in range(_num_gaps):
		_gaps.append({
			"center": cands[i].center,
			"ref_center": cands[i].ref_center,
			"horizontal": cands[i].horizontal,
			"filled": false,
		})
	_active_gap = 0
	_build_tray()

func _build_tray() -> void:
	var n: int = 3 + (randi() % 2)             # 3 or 4 options
	var answer: String = CONDUCTORS[randi() % CONDUCTORS.size()]
	var candidates: Array = INSULATORS.duplicate()
	if randf() < 0.4:
		candidates.append("short")             # occasional spark trap
	candidates.shuffle()
	var decoys: Array = candidates.slice(0, n - 1)
	# ON/OFF tension: if the answer is a closed switch, make sure an OPEN switch shows.
	if answer == "closed_switch" and not decoys.has("open_switch"):
		decoys[0] = "open_switch"
	var types: Array = [answer] + decoys
	types.shuffle()

	var total_w: float = n * SLOT_W + (n - 1) * SLOT_GAP
	var start_x: float = (VIEW.x - total_w) / 2.0
	_slots.clear()
	for i in range(n):
		var t: String = types[i]
		_slots.append({
			"rect": Rect2(start_x + i * (SLOT_W + SLOT_GAP), TRAY_Y, SLOT_W, SLOT_H),
			"type": t,
			"conducts": t in CONDUCTORS,
		})

# ---------------------------------------------------------------------------
# LOOP
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not _active:
		_active = true
	_anim += delta
	_elapsed += delta
	# Screen shake (only ever runs after a choice, when input is already locked).
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (_shake / 0.35) * 9.0
	elif position != Vector2.ZERO:
		position = Vector2.ZERO
	# Age sparks.
	for s in _sparks:
		s.t += delta
	_sparks = _sparks.filter(func(s): return s.t < 0.5)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not _active or _resolved:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click: Vector2 = get_global_mouse_position()
		for i in range(_slots.size()):
			if _slots[i].rect.has_point(click):
				_choose(i)
				return

func _choose(index: int) -> void:
	var slot: Dictionary = _slots[index]
	var slot_center: Vector2 = slot.rect.position + slot.rect.size / 2.0

	if slot.conducts:
		# Correct piece for the active gap.
		_gaps[_active_gap].filled = true
		_spawn_sparks(_gaps[_active_gap].center, 6, GOOD)
		if _filled_count() < _num_gaps:
			_play(_sfx_fix)
			_active_gap += 1
			_build_tray()
			queue_redraw()
		else:
			# Every gap fixed — light it up and win immediately. GameManager's
			# own RESULT_PAUSE_DURATION (0.9s) keeps this scene alive and
			# _process running, so the bulb-lit animation still plays out —
			# but a HUD timeout that lands in this window can no longer
			# overwrite a completed circuit with a loss.
			_play(_sfx_win)
			_resolved = true
			_lit = true
			queue_redraw()
			win()
		return

	# Wrong pick — lose (a short trap sparks harder).
	_resolved = true
	_wrong_slot = index
	if slot.type == "short":
		_play(_sfx_short)
		_queue_negative()   # fail jingle follows the big explosion
		_spawn_sparks(slot_center, 16, SPARK)
		_shake = 0.35
	else:
		_play(_sfx_wrong)
		_spawn_sparks(slot_center, 8, BAD)
		_shake = 0.22
	queue_redraw()
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self):
		lose()

func _play(stream: AudioStream) -> void:
	if _audio != null and stream != null:
		_audio.stream = stream
		_audio.play()

# Plays the fail jingle on the 2nd channel shortly AFTER the big explosion, so the
# two don't step on each other. Fire-and-forget (not awaited by the caller).
func _queue_negative() -> void:
	await get_tree().create_timer(0.45).timeout
	if is_instance_valid(self) and _audio2 != null and _sfx_negative != null:
		_audio2.stream = _sfx_negative
		_audio2.play()

func _spawn_sparks(center: Vector2, count: int, col: Color) -> void:
	for _i in range(count):
		var ang: float = randf() * TAU
		_sparks.append({
			"pos": center,
			"dir": Vector2(cos(ang), sin(ang)),
			"t": 0.0,
			"col": col,
			"len": randf_range(22.0, 48.0),
		})

func _filled_count() -> int:
	var n: int = 0
	for g in _gaps:
		if g.filled:
			n += 1
	return n

func _time_frac() -> float:
	if not _active:
		return 0.0
	var dur: float = actual_duration()
	return clampf(_elapsed / dur, 0.0, 1.0) if dur > 0.0 else 0.0

# Wire colour: live (gold) when lit; otherwise white, flickering as time runs low.
func _wire_color() -> Color:
	if _lit:
		return WIRE_LIVE
	var frac: float = _time_frac()
	if frac <= 0.6:
		return WIRE
	var severity: float = clampf((frac - 0.6) / 0.4, 0.0, 1.0)
	var flick: float = 0.5 + 0.5 * sin(_anim * 22.0)
	var factor: float = lerpf(1.0, lerpf(0.4, 1.0, flick), severity)
	return Color(WIRE.r * factor, WIRE.g * factor, WIRE.b * factor, 1.0)

func _label(t: String) -> String:
	match t:
		"wire": return "WIRE"
		"closed_switch": return "SWITCH (ON)"
		"open_switch": return "SWITCH (OFF)"
		"capacitor": return "CAPACITOR"
		"broken_wire": return "BROKEN WIRE"
		"short": return "SHORT!"
	return t.to_upper()

# ===========================================================================
# RENDERING
# ===========================================================================
func _draw() -> void:
	_draw_background()
	_draw_instructions()
	_draw_circuit()
	_draw_flow()
	_draw_battery(Vector2(LOOP_LEFT, (LOOP_TOP + LOOP_BOTTOM) / 2.0))
	_draw_gaps()
	_draw_bulb(Vector2((LOOP_LEFT + LOOP_RIGHT) / 2.0, LOOP_TOP))
	for i in range(_slots.size()):
		_draw_slot(i)
	_draw_sparks()
	_draw_feedback()

func _draw_background() -> void:
	draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), BG, true)
	# Grid spacing scales with the viewport so the cell count stays the same as at
	# 1280x720 (1280/40 = 32 columns, 720/40 = 18 rows), keeping the look identical.
	# Half-open (< not <=) so the line set matches the original range(0, 1280, 40).
	var step_x: float = 40.0 * (VIEW.x / REF_SIZE.x)
	var step_y: float = 40.0 * (VIEW.y / REF_SIZE.y)
	if step_x <= 0.0:
		step_x = 40.0
	if step_y <= 0.0:
		step_y = 40.0
	var gx: float = 0.0
	while gx < VIEW.x:
		draw_line(Vector2(gx, 0), Vector2(gx, VIEW.y), GRID, 1.0)
		gx += step_x
	var gy: float = 0.0
	while gy < VIEW.y:
		draw_line(Vector2(0, gy), Vector2(VIEW.x, gy), GRID, 1.0)
		gy += step_y

func _draw_instructions() -> void:
	if not _font:
		return
	var sy: float = VIEW.y / REF_SIZE.y
	var fs: float = min(VIEW.x / REF_SIZE.x, sy)   # font scale (smaller axis)
	# Centring width is the full viewport so text stays centred at any size.
	draw_string(_font, Vector2(0, 112.0 * sy), "LIGHT THE BULB!",
		HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, int(40 * fs), BULB_ON)
	draw_string(_font, Vector2(0, 150.0 * sy), "Tap the piece that lets current through — fix every gap",
		HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, int(20 * fs), TEXT)
	# Progress counter sits in the empty centre of the loop so the bulb (top-centre)
	# never overlaps it.
	draw_string(_font, Vector2(0, (LOOP_TOP + LOOP_BOTTOM) / 2.0 + 8.0 * sy),
		"%d / %d FIXED" % [_filled_count(), _num_gaps],
		HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, int(22 * fs), GOOD if _lit else TEXT)

func _draw_circuit() -> void:
	var col: Color = _wire_color()
	var w: float = 6.0
	var corner_tl: Vector2 = Vector2(LOOP_LEFT, LOOP_TOP)
	var corner_tr: Vector2 = Vector2(LOOP_RIGHT, LOOP_TOP)
	var corner_br: Vector2 = Vector2(LOOP_RIGHT, LOOP_BOTTOM)
	var corner_bl: Vector2 = Vector2(LOOP_LEFT, LOOP_BOTTOM)

	# Top edge: the bulb sits inline on the wire (drawn on top), so no bulb cut —
	# the wire runs straight through behind it and connects on both sides.
	var top_cuts: Array = []
	for g in _gaps:
		if not g.filled and is_equal_approx(g.center.y, LOOP_TOP):
			top_cuts.append([g.center.x - GAP_HALF - LOOP_LEFT, g.center.x + GAP_HALF - LOOP_LEFT])
	_draw_edge(corner_tl, corner_tr, top_cuts, col, w)

	# Right edge.
	var right_cuts: Array = []
	for g in _gaps:
		if not g.filled and is_equal_approx(g.center.x, LOOP_RIGHT):
			right_cuts.append([g.center.y - GAP_HALF - LOOP_TOP, g.center.y + GAP_HALF - LOOP_TOP])
	_draw_edge(corner_tr, corner_br, right_cuts, col, w)

	# Bottom edge.
	var bottom_cuts: Array = []
	for g in _gaps:
		if not g.filled and is_equal_approx(g.center.y, LOOP_BOTTOM):
			bottom_cuts.append([g.center.x - GAP_HALF - LOOP_LEFT, g.center.x + GAP_HALF - LOOP_LEFT])
	_draw_edge(corner_bl, corner_br, bottom_cuts, col, w)

	# Left edge (battery overlaid) — always whole.
	_draw_edge(corner_tl, corner_bl, [], col, w)

func _draw_edge(a: Vector2, b: Vector2, cuts: Array, col: Color, w: float) -> void:
	var total: float = a.distance_to(b)
	var dir: Vector2 = (b - a) / total
	cuts.sort_custom(func(x, y): return x[0] < y[0])
	var pos: float = 0.0
	for c in cuts:
		var cs: float = clampf(c[0], 0.0, total)
		var ce: float = clampf(c[1], 0.0, total)
		if cs > pos:
			draw_line(a + dir * pos, a + dir * cs, col, w)
		pos = maxf(pos, ce)
	if pos < total:
		draw_line(a + dir * pos, a + dir * total, col, w)

func _draw_flow() -> void:
	if not _lit:
		return
	var corners: Array = [
		Vector2(LOOP_LEFT, LOOP_TOP), Vector2(LOOP_RIGHT, LOOP_TOP),
		Vector2(LOOP_RIGHT, LOOP_BOTTOM), Vector2(LOOP_LEFT, LOOP_BOTTOM),
	]
	var seglen: Array = []
	var perim: float = 0.0
	for i in range(4):
		var l: float = corners[i].distance_to(corners[(i + 1) % 4])
		seglen.append(l)
		perim += l
	var k: int = 14
	for i in range(k):
		var dist: float = fmod(_anim * 190.0 + perim * float(i) / k, perim)
		var p: Vector2 = _perim_point(dist, corners, seglen)
		draw_circle(p, 9.0, Color(WIRE_LIVE.r, WIRE_LIVE.g, WIRE_LIVE.b, 0.30))
		draw_circle(p, 5.0, WIRE_LIVE)

func _perim_point(dist: float, corners: Array, seglen: Array) -> Vector2:
	var d: float = dist
	for i in range(4):
		if d <= seglen[i]:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			return a + (b - a).normalized() * d
		d -= seglen[i]
	return corners[0]

func _draw_battery(center: Vector2) -> void:
	draw_line(center + Vector2(-22, -8), center + Vector2(22, -8), BATTERY, 3.0)
	draw_line(center + Vector2(-12, 6), center + Vector2(12, 6), BATTERY, 7.0)
	if _font:
		draw_string(_font, center + Vector2(-44, -10), "+", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, BATTERY)
		draw_string(_font, center + Vector2(28, 14), "-", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, BATTERY)

func _draw_gaps() -> void:
	var late: bool = _time_frac() > 0.85
	for i in range(_gaps.size()):
		var g: Dictionary = _gaps[i]
		if g.filled:
			continue
		var c: Vector2 = g.center
		var a: Vector2 = c + (Vector2(-GAP_HALF, 0) if g.horizontal else Vector2(0, -GAP_HALF))
		var b: Vector2 = c + (Vector2(GAP_HALF, 0) if g.horizontal else Vector2(0, GAP_HALF))
		var is_active: bool = (i == _active_gap)
		var border: Color
		if is_active:
			var pulse: float = 0.5 + 0.5 * sin(_anim * 6.0)
			border = (BAD if late else SLOT_BORDER).lerp(Color.WHITE, pulse * 0.5)
		else:
			border = Color(SLOT_BORDER.r, SLOT_BORDER.g, SLOT_BORDER.b, 0.35)

		var min_p: Vector2 = Vector2(min(a.x, b.x), min(a.y, b.y))
		var max_p: Vector2 = Vector2(max(a.x, b.x), max(a.y, b.y))
		var box: Rect2
		if g.horizontal:
			box = Rect2(min_p.x - 8, min_p.y - 24, (max_p.x - min_p.x) + 16, 48)
		else:
			box = Rect2(min_p.x - 24, min_p.y - 8, 48, (max_p.y - min_p.y) + 16)
		draw_rect(box, Color(border.r, border.g, border.b, 0.10), true)
		_draw_dashed_rect(box, border, 2.0, 9.0)
		draw_circle(a, 5.0, border)
		draw_circle(b, 5.0, border)
		if is_active and _font:
			draw_string(_font, Vector2(c.x - 60, max_p.y + 26), "FIX THIS",
				HORIZONTAL_ALIGNMENT_CENTER, 120, 15, border)

func _draw_dashed_rect(rect: Rect2, col: Color, width: float, dash: float) -> void:
	var p: Vector2 = rect.position
	var s: Vector2 = rect.size
	_draw_dashed_line(p, p + Vector2(s.x, 0), col, width, dash)
	_draw_dashed_line(p + Vector2(s.x, 0), p + s, col, width, dash)
	_draw_dashed_line(p + s, p + Vector2(0, s.y), col, width, dash)
	_draw_dashed_line(p + Vector2(0, s.y), p, col, width, dash)

func _draw_dashed_line(a: Vector2, b: Vector2, col: Color, width: float, dash: float) -> void:
	var total: float = a.distance_to(b)
	var dir: Vector2 = (b - a).normalized()
	var d: float = 0.0
	while d < total:
		var seg_end: float = min(d + dash, total)
		draw_line(a + dir * d, a + dir * seg_end, col, width)
		d += dash * 2.0

func _draw_bulb(center: Vector2) -> void:
	var ratio: float = float(_filled_count()) / float(max(_num_gaps, 1))
	if _lit:
		var pulse: float = 6.0 * sin(_anim * 6.0)
		draw_circle(center, 52.0 + pulse, Color(BULB_ON.r, BULB_ON.g, BULB_ON.b, 0.22))
		draw_circle(center, 38.0 + pulse * 0.5, Color(BULB_ON.r, BULB_ON.g, BULB_ON.b, 0.40))
	elif ratio > 0.0:
		draw_circle(center, 40.0, Color(BULB_ON.r, BULB_ON.g, BULB_ON.b, 0.18 * ratio))
	var glass: Color = BULB_ON if _lit else BULB_OFF.lerp(BULB_ON, ratio * 0.6)
	if not _lit and _time_frac() > 0.85:
		glass = glass.darkened(0.35)
	draw_circle(center, 26.0, glass)
	draw_arc(center, 26.0, 0.0, TAU, 32, WIRE, 2.0, true)
	var f: PackedVector2Array = PackedVector2Array([
		center + Vector2(-10, 6), center + Vector2(-4, -8),
		center + Vector2(4, 6), center + Vector2(10, -8),
	])
	draw_polyline(f, Color(0.3, 0.25, 0.1) if _lit else Color(0.2, 0.2, 0.22), 2.0)

func _draw_slot(index: int) -> void:
	var slot: Dictionary = _slots[index]
	var rect: Rect2 = slot.rect
	var border: Color = SLOT_BORDER
	if _wrong_slot == index:
		border = BAD
	draw_rect(rect, SLOT_BG, true)
	draw_rect(rect, border, false, 3.0)

	var center: Vector2 = rect.position + rect.size / 2.0 - Vector2(0, 10)
	_draw_component(center, slot.type, WIRE)

	if _font:
		var col: Color = BAD if slot.type == "short" else TEXT
		draw_string(_font, Vector2(rect.position.x, rect.position.y + rect.size.y - 14),
			_label(slot.type), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16, col)
	if _wrong_slot == index:
		draw_line(rect.position + Vector2(20, 20), rect.position + rect.size - Vector2(20, 40), BAD, 5.0)
		draw_line(rect.position + Vector2(rect.size.x - 20, 20),
			rect.position + Vector2(20, rect.size.y - 40), BAD, 5.0)

func _draw_component(center: Vector2, type: String, col: Color) -> void:
	var half: float = 52.0
	var w: float = 5.0
	match type:
		"wire":
			draw_line(center + Vector2(-half, 0), center + Vector2(half, 0), col, w)
		"closed_switch":
			var p1: Vector2 = center + Vector2(-half * 0.5, 0)
			var c1: Vector2 = center + Vector2(half * 0.5, 0)
			draw_line(center + Vector2(-half, 0), p1, col, w)
			draw_line(c1, center + Vector2(half, 0), col, w)
			draw_line(p1, c1, col, w)
			draw_line(c1, c1 + Vector2(-12, -12), col, w)
			draw_circle(p1, 4.0, col)
			draw_circle(c1, 4.0, col)
		"open_switch":
			var pivot: Vector2 = center + Vector2(-half * 0.5, 0)
			var contact: Vector2 = center + Vector2(half * 0.5, 0)
			draw_line(center + Vector2(-half, 0), pivot, col, w)
			draw_line(contact, center + Vector2(half, 0), col, w)
			draw_line(pivot, center + Vector2(half * 0.5, -22), col, w)
			draw_circle(pivot, 4.0, col)
			draw_circle(contact, 4.0, col)
		"capacitor":
			var g: float = 9.0
			draw_line(center + Vector2(-half, 0), center + Vector2(-g, 0), col, w)
			draw_line(center + Vector2(g, 0), center + Vector2(half, 0), col, w)
			draw_line(center + Vector2(-g, -16), center + Vector2(-g, 16), col, w)
			draw_line(center + Vector2(g, -16), center + Vector2(g, 16), col, w)
		"broken_wire":
			var bk: float = 16.0
			draw_line(center + Vector2(-half, 0), center + Vector2(-bk, 0), col, w)
			draw_line(center + Vector2(bk, 0), center + Vector2(half, 0), col, w)
			draw_circle(center + Vector2(-bk, 0), 3.0, col)
			draw_circle(center + Vector2(bk, 0), 3.0, col)
		"short":
			draw_line(center + Vector2(-half, 0), center + Vector2(half, 0), col, w)
			var bolt: PackedVector2Array = PackedVector2Array([
				center + Vector2(-10, -15), center + Vector2(2, -2),
				center + Vector2(-4, 2), center + Vector2(10, 15),
			])
			draw_polyline(bolt, SPARK, 3.0)

func _draw_sparks() -> void:
	for s in _sparks:
		var prog: float = s.t / 0.5
		var c: Color = s.col
		c.a = 1.0 - prog
		var start: Vector2 = s.pos + s.dir * (s.len * prog * 0.4)
		var end_pt: Vector2 = s.pos + s.dir * (s.len * (0.4 + prog))
		draw_line(start, end_pt, c, 3.0)

func _draw_feedback() -> void:
	if not _font:
		return
	var sy: float = VIEW.y / REF_SIZE.y
	var fs: int = int(28 * min(VIEW.x / REF_SIZE.x, sy))
	if _lit:
		draw_string(_font, Vector2(0, 690.0 * sy), "CIRCUIT COMPLETE!",
			HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, fs, GOOD)
	elif _wrong_slot >= 0:
		var msg: String = "STILL BROKEN — current can't pass!"
		if _slots[_wrong_slot].type == "short":
			msg = "SHORT CIRCUIT — ZAP!"
		draw_string(_font, Vector2(0, 690.0 * sy), msg, HORIZONTAL_ALIGNMENT_CENTER, VIEW.x, fs, BAD)
