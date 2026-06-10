extends MiniGameBase

var _mouth_texture: Texture2D

# ---------------------------------------------------------------------------
# CONFIG
# ---------------------------------------------------------------------------
const CAVITY_COUNT: int   = 4
const GUM_COUNT: int      = 2
const TONGUE_COUNT: int   = 1

const DRILL_RADIUS: float  = 14.0
const CAVITY_RADIUS: float = 28.0
const GUM_RADIUS: float    = 38.0
const TONGUE_RADIUS: float = 50.0

const SAFE_SPAWN_DIST: float = 150.0  # min obstacle-to-cursor spawn gap; prevents instant lose()

const CAVITY_SPEED: float  = 75.0
const GUM_SPEED: float     = 115.0
const TONGUE_SPEED: float  = 148.0
const DRILL_TIME: float    = 0.8    # seconds hovering to drill one cavity

# cavity
const COLOR_CAVITY_HALO: Color   = Color(0.40, 0.22, 0.07)   # outer decay ring
const COLOR_CAVITY_BODY: Color   = Color(0.20, 0.09, 0.02)   # dark brown body
const COLOR_CAVITY_DEEP: Color   = Color(0.08, 0.03, 0.00)   # deep pit
const COLOR_CAVITY_PIT:  Color   = Color(0.02, 0.01, 0.00)   # black centre
const COLOR_CAVITY_HL:   Color   = Color(0.72, 0.34, 0.07)   # lit up while drilling
# gum
const COLOR_GUM:         Color   = Color(0.93, 0.58, 0.62)   # kept for spawn dict
const COLOR_GUM_DARK:    Color   = Color(0.76, 0.40, 0.45)   # shadow outline
const COLOR_GUM_LIGHT:   Color   = Color(0.99, 0.83, 0.85)   # gloss highlight
# tongue
const COLOR_TONGUE:        Color = Color(0.85, 0.24, 0.24)   # kept for spawn dict
const COLOR_TONGUE_BASE:   Color = Color(0.68, 0.17, 0.20)   # dark underside
const COLOR_TONGUE_MID:    Color = Color(0.86, 0.31, 0.34)   # main surface
const COLOR_TONGUE_GROOVE: Color = Color(0.46, 0.10, 0.12)   # centre crease
const COLOR_TONGUE_HL:     Color = Color(1.00, 0.72, 0.74)   # gloss spot
# drill / progress
const COLOR_DRILL:       Color   = Color(0.82, 0.82, 0.90)
const COLOR_DRILL_ACT:   Color   = Color(1.00, 0.92, 0.15)
const COLOR_PROGRESS:    Color   = Color(1.00, 1.00, 1.00, 0.90)

# pre-baked radial offsets that give gums an irregular blob silhouette
const GUM_OFFSETS: Array = [-4.0, 7.0, 2.0, -5.0, 9.0, 1.0, -3.0, 8.0, -6.0, 4.0, -2.0, 6.0]

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------
var _cavities: Array  = []
var _obstacles: Array = []
var _vp: Rect2        = Rect2()
const HUD_TOP: float  = 80.0   # pixels reserved at top for HUD overlay

# pop effects: brief expanding rings drawn where a cavity was just drilled
var _pop_effects: Array = []
const POP_DURATION: float = 0.35
const COLOR_POP: Color = Color(1.0, 0.95, 0.6, 1.0)

# ---------------------------------------------------------------------------
# AUDIO
# ---------------------------------------------------------------------------
var _drill_sound: AudioStreamPlayer
var _pop_sound: AudioStreamPlayer
var _win_sound: AudioStreamPlayer
var _lose_sound: AudioStreamPlayer
var _bg_music: AudioStreamPlayer

# ---------------------------------------------------------------------------
# MINIGAMEBASE CONTRACT
# ---------------------------------------------------------------------------
func setup() -> void:
	base_duration    = 12.0
	instruction_text = "Drill the cavities! Avoid gums & tongue!"
	_vp              = get_viewport_rect()
	_mouth_texture   = load("res://minigames/cavity_chase/assets/mouth_bg_a.png")
	_spawn_sprites()

	_drill_sound = AudioStreamPlayer.new()
	_drill_sound.stream = load("res://400 Sounds Pack/Machines/drill_whizz.wav")
	add_child(_drill_sound)

	_pop_sound = AudioStreamPlayer.new()
	_pop_sound.stream = load("res://400 Sounds Pack/Match Three/match_synth_3.wav")
	add_child(_pop_sound)

	_win_sound = AudioStreamPlayer.new()
	_win_sound.stream = load("res://win v1.0.wav")
	add_child(_win_sound)

	_lose_sound = AudioStreamPlayer.new()
	_lose_sound.stream = load("res://lose v1.0.wav")
	add_child(_lose_sound)

	_bg_music = AudioStreamPlayer.new()
	_bg_music.stream = load("res://400 Sounds Pack/Musical Effects/music_box_inn.wav")
	_bg_music.volume_db = -8.0
	_bg_music.finished.connect(func(): _bg_music.play())
	add_child(_bg_music)
	_bg_music.play()

func _spawn_sprites() -> void:
	var sm: float = time_scale   # speed multiplier increases with difficulty
	var cursor: Vector2 = get_global_mouse_position()

	for _i in CAVITY_COUNT:
		var angle: float = randf() * TAU
		_cavities.append({
			"pos":         _rand_pos(),
			"vel":         Vector2(cos(angle), sin(angle)) * CAVITY_SPEED * sm,
			"drill_timer": 0.0,
		})

	for _i in GUM_COUNT:
		_obstacles.append({
			"pos":       _rand_safe_pos(cursor),
			"speed":     GUM_SPEED * sm,
			"radius":    GUM_RADIUS,
			"color":     COLOR_GUM,
			"is_tongue": false,
		})

	for _i in TONGUE_COUNT:
		_obstacles.append({
			"pos":       _rand_safe_pos(cursor),
			"speed":     TONGUE_SPEED * sm,
			"radius":    TONGUE_RADIUS,
			"color":     COLOR_TONGUE,
			"is_tongue": true,
		})

func _rand_pos() -> Vector2:
	var m: float = 60.0
	return Vector2(
		randf_range(m, _vp.size.x - m),
		randf_range(HUD_TOP + m, _vp.size.y - m)
	)

## Re-rolls a spawn position until it's clear of the cursor by SAFE_SPAWN_DIST,
## so an obstacle can never land on top of the player and trigger an instant lose().
func _rand_safe_pos(avoid: Vector2) -> Vector2:
	var pos: Vector2 = _rand_pos()
	var attempts: int = 0
	while pos.distance_to(avoid) < SAFE_SPAWN_DIST and attempts < 20:
		pos = _rand_pos()
		attempts += 1
	return pos

# ---------------------------------------------------------------------------
# GAME LOOP
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _finished:
		return

	var cursor: Vector2 = get_global_mouse_position()

	# -- Update cavities --
	var drilled: Array = []
	var any_drilling: bool = false
	for cavity in _cavities:
		cavity.pos += cavity.vel * delta
		_bounce(cavity)
		if cursor.distance_to(cavity.pos) < DRILL_RADIUS + CAVITY_RADIUS:
			cavity.drill_timer += delta
			any_drilling = true
			if cavity.drill_timer >= DRILL_TIME:
				drilled.append(cavity)
		else:
			cavity.drill_timer = 0.0
	for c in drilled:
		_cavities.erase(c)
		_pop_sound.play()
		_pop_effects.append({"pos": c.pos, "t": 0.0})

	# -- Drilling sound: keep (re)playing while actively drilling, stop otherwise --
	if any_drilling:
		if not _drill_sound.playing:
			_drill_sound.play()
	elif _drill_sound.playing:
		_drill_sound.stop()

	# -- Update pop effects --
	for effect in _pop_effects:
		effect.t += delta
	_pop_effects = _pop_effects.filter(func(e): return e.t < POP_DURATION)

	if _cavities.is_empty():
		_drill_sound.stop()
		_bg_music.stop()
		_win_sound.play()
		win()
		queue_redraw()
		return

	# -- Update obstacles (home toward cursor) --
	for obs in _obstacles:
		var dir: Vector2 = cursor - obs.pos
		if dir.length_squared() > 1.0:
			obs.pos += dir.normalized() * obs.speed * delta
		if cursor.distance_to(obs.pos) < DRILL_RADIUS + obs.radius:
			_drill_sound.stop()
			_bg_music.stop()
			_lose_sound.play()
			lose()
			queue_redraw()
			return

	queue_redraw()

func _bounce(cavity: Dictionary) -> void:
	var r: float = CAVITY_RADIUS
	if cavity.pos.x < r:
		cavity.pos.x = r
		cavity.vel.x = abs(cavity.vel.x)
	elif cavity.pos.x > _vp.size.x - r:
		cavity.pos.x = _vp.size.x - r
		cavity.vel.x = -abs(cavity.vel.x)
	if cavity.pos.y < HUD_TOP + r:
		cavity.pos.y = HUD_TOP + r
		cavity.vel.y = abs(cavity.vel.y)
	elif cavity.pos.y > _vp.size.y - r:
		cavity.pos.y = _vp.size.y - r
		cavity.vel.y = -abs(cavity.vel.y)

# ---------------------------------------------------------------------------
# RENDERING
# ---------------------------------------------------------------------------
func _draw() -> void:
	if _mouth_texture:
		draw_texture_rect(_mouth_texture, _vp, false)

	var cursor: Vector2 = get_global_mouse_position()
	var any_drilling: bool = false

	for cavity in _cavities:
		_draw_cavity(cavity, cursor)
		if cavity.drill_timer > 0.0:
			any_drilling = true

	for obs in _obstacles:
		if obs.is_tongue:
			_draw_tongue(obs.pos)
		else:
			_draw_gum(obs.pos)

	for effect in _pop_effects:
		_draw_pop(effect)

	var dcol: Color = COLOR_DRILL_ACT if any_drilling else COLOR_DRILL
	draw_circle(cursor, DRILL_RADIUS, dcol)
	var arm: float = DRILL_RADIUS * 2.5
	draw_line(cursor + Vector2(-arm, 0), cursor + Vector2(arm, 0), Color.WHITE, 2.0)
	draw_line(cursor + Vector2(0, -arm), cursor + Vector2(0, arm), Color.WHITE, 2.0)

func _draw_cavity(cavity: Dictionary, cursor: Vector2) -> void:
	var pos: Vector2 = cavity.pos
	var drilling: bool = cursor.distance_to(pos) < DRILL_RADIUS + CAVITY_RADIUS

	# Four concentric rings give the decay-in-enamel look
	draw_circle(pos, CAVITY_RADIUS * 1.28, COLOR_CAVITY_HALO)
	draw_circle(pos, CAVITY_RADIUS,        COLOR_CAVITY_HL if drilling else COLOR_CAVITY_BODY)
	draw_circle(pos, CAVITY_RADIUS * 0.60, COLOR_CAVITY_DEEP)
	draw_circle(pos, CAVITY_RADIUS * 0.28, COLOR_CAVITY_PIT)

	if cavity.drill_timer > 0.0:
		var progress: float = cavity.drill_timer / DRILL_TIME
		draw_arc(pos, CAVITY_RADIUS + 9.0,
			-PI / 2.0, -PI / 2.0 + TAU * progress,
			32, COLOR_PROGRESS, 4.0)

## Briefly expanding, fading ring marking a freshly drilled cavity.
func _draw_pop(effect: Dictionary) -> void:
	var progress: float = effect.t / POP_DURATION
	var radius: float = CAVITY_RADIUS * (1.0 + progress * 1.2)
	var color: Color = COLOR_POP
	color.a = 1.0 - progress
	draw_arc(effect.pos, radius, 0.0, TAU, 32, color, 4.0)

func _draw_gum(pos: Vector2) -> void:
	# Shadow blob slightly larger and offset down-right
	draw_colored_polygon(_blob_pts(pos + Vector2(3, 4), GUM_RADIUS * 1.12, GUM_OFFSETS, 1.1), COLOR_GUM_DARK)
	# Main fleshy body
	draw_colored_polygon(_blob_pts(pos, GUM_RADIUS, GUM_OFFSETS, 1.0), COLOR_GUM)
	# Gloss highlight — small bright ellipse top-left
	draw_set_transform(pos + Vector2(-GUM_RADIUS * 0.30, -GUM_RADIUS * 0.32), 0.0, Vector2(1.15, 0.65))
	draw_circle(Vector2.ZERO, GUM_RADIUS * 0.27, Color(COLOR_GUM_LIGHT.r, COLOR_GUM_LIGHT.g, COLOR_GUM_LIGHT.b, 0.70))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_tongue(pos: Vector2) -> void:
	# Layer 1 — dark base, widest ellipse
	draw_set_transform(pos, 0.0, Vector2(1.45, 0.82))
	draw_circle(Vector2.ZERO, TONGUE_RADIUS, COLOR_TONGUE_BASE)
	# Layer 2 — brighter main surface, slightly smaller and nudged up-left
	draw_set_transform(pos + Vector2(-5, -8), 0.0, Vector2(1.28, 0.72))
	draw_circle(Vector2.ZERO, TONGUE_RADIUS * 0.90, COLOR_TONGUE_MID)
	# Layer 3 — narrow vertical groove down the centre
	draw_set_transform(pos, 0.0, Vector2(0.17, 0.74))
	draw_circle(Vector2.ZERO, TONGUE_RADIUS * 0.80, COLOR_TONGUE_GROOVE)
	# Layer 4 — gloss highlight spot
	draw_set_transform(pos + Vector2(-TONGUE_RADIUS * 0.40, -TONGUE_RADIUS * 0.28), 0.0, Vector2(1.3, 0.72))
	draw_circle(Vector2.ZERO, TONGUE_RADIUS * 0.27, Color(COLOR_TONGUE_HL.r, COLOR_TONGUE_HL.g, COLOR_TONGUE_HL.b, 0.50))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _blob_pts(center: Vector2, base_r: float, offsets: Array, scale: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = offsets.size()
	for i in range(n):
		var angle: float = (float(i) / n) * TAU - PI / 2.0
		var r: float = base_r + offsets[i] * scale
		pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
	return pts
