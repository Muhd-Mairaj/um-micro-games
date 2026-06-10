extends MiniGameBase
class_name OsuGame

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var circles_container: Node2D = $CirclesContainer
@onready var back_wall: TextureRect = $Stage/BackWall
@onready var spotlight: TextureRect = $Stage/Spotlight

const STAGE_TEXTURE_PATH := "res://minigames/osu_um/theater-stage-with-red-curtains-theatre-seats-free-vector.jpg"
@onready var score_label: Label = $UI/ScoreLabel
@onready var combo_label: Label = $UI/ComboLabel
@onready var accuracy_label: Label = $UI/AccuracyLabel

# Preloaded once instead of load()-ing on every judgement label (see review).
const JUDGE_FONT := preload("res://assets/Font/Kenney Future.ttf")

# Hit chime (royalty-free 400 Sounds Pack). Played on every successful circle hit
# via a dedicated player so it never interrupts the song on $AudioStreamPlayer.
const HIT_SFX_PATH := "res://400 Sounds Pack/Musical Effects/8_bit_chime_positive.wav"
var _sfx: AudioStreamPlayer

# --- Tunables ---
const PREEMPT_MS: float = 1200.0      # how long a circle is visible before its beat
const END_PAD_MS: float = 1000.0      # round budget = last note + this pad
const MISS_GRACE_MS: float = 150.0     # extra ms past the OK window before auto-miss
const PASS_ACCURACY_PCT: float = 40.0  # accuracy must exceed this to win (<=40 loses)

var chart_manager: ChartManager
var score_manager: ScoreManager
var circles_data: Array = []
var active_circles: Array = []  # Circles currently on screen
var hit_circles: Array = []     # Already hit circles
var missed_circles: Array = []  # Missed circles
var circle_scene: PackedScene
var hit_zone: HitZone
var chart_path: String = ""
var game_active: bool = false  # Whether the game is running (accepting input & processing)
var audio_ended: bool = false  # Whether the audio track has finished playing
var last_audio_position_ms: float = 0.0  # Last known audio position before it stopped
var post_audio_elapsed_ms: float = 0.0   # Time accumulated after audio stops
var _pending_lose: bool = false          # Deferred lose() (e.g. chart failed to load)
var _started: bool = false               # Audio/round starts on the first real _process frame

func setup() -> void:
	"""Called by GameManager (via MiniGameBase._ready) to initialise the game.
	All init lives here — overriding _ready() would run before GameManager reads
	base_duration / instruction_text, breaking the HUD timer and hint."""
	chart_manager = ChartManager.new()
	score_manager = ScoreManager.new()
	circle_scene = load("res://minigames/osu_um/Circle.tscn")
	hit_zone = HitZone.new()
	add_child(hit_zone)

	# Dedicated SFX player so hit chimes don't interrupt the song.
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	_sfx.stream = load(HIT_SFX_PATH)

	instruction_text = "Direct the performance! The closer the ring to the circle, the more accurate your hit!"

	# Load the stage backdrop in code (same proven load() path Circle.gd uses for
	# its button art) rather than via a scene ExtResource, which can fail to
	# resolve from a stale editor import/uid cache.
	var stage_tex: Texture2D = load(STAGE_TEXTURE_PATH)
	if stage_tex != null:
		back_wall.texture = stage_tex
	else:
		push_warning("[OsuGame] Stage backdrop failed to load: " + STAGE_TEXTURE_PATH)

	# Load chart.
	chart_path = "res://minigames/osu_um/charts/test_chart.json"
	if not chart_manager.load_chart(chart_path):
		push_error("[OsuGame] Failed to load chart: " + chart_path)
		# Can't lose() here — GameManager connects signals after setup(). Defer it.
		_pending_lose = true
		return

	circles_data = chart_manager.get_circles()
	score_manager.reset()

	# Round budget derives from the LAST note (+ pad), not the raw metadata, so
	# every circle resolves a beat before the HUD timeout. Kept within 5–12s.
	var last_time_ms: float = 0.0
	for circle_data in circles_data:
		last_time_ms = max(last_time_ms, float(circle_data.time_ms))
	base_duration = clamp((last_time_ms + END_PAD_MS) / 1000.0, 5.0, 12.0)

	# Speed the song (and therefore the whole chart, which is timed off the audio
	# position) in lockstep with GameManager's time_scale.
	audio_player.pitch_scale = max(time_scale, 0.01)

	_spawn_circles()

	# NOTE: audio + timing intentionally start on the first _process frame
	# (see _start_round), NOT here. GameManager disables _process during its
	# 2.2s "get ready" screen; starting the song in setup() would let it play
	# through that freeze and desync every circle. The first _process frame only
	# fires once gameplay actually begins.

func _process(delta: float) -> void:
	# Deferred failure path (signals are connected by now).
	if _pending_lose:
		_pending_lose = false
		lose()
		return
	# First real frame (after GameManager's get-ready freeze): start the song now
	# so audio and gameplay are in sync.
	if not _started:
		_start_round()
	if not game_active:
		return

	# Sync game time to audio playback (the melody is the source of truth).
	var current_time_ms: float
	if audio_player.playing:
		current_time_ms = audio_player.get_playback_position() * 1000.0
		last_audio_position_ms = current_time_ms
	else:
		# Audio finished — keep ticking in stream time (scaled like the song was).
		if not audio_ended:
			audio_ended = true
			post_audio_elapsed_ms = 0.0
		post_audio_elapsed_ms += delta * 1000.0 * time_scale
		current_time_ms = last_audio_position_ms + post_audio_elapsed_ms

	_update_ui()

	# Drive circle telegraph (fade-in + shrinking approach ring) and auto-miss.
	for child in circles_container.get_children():
		var circle := child as Circle
		if circle == null:
			continue
		if circle in hit_circles or circle in missed_circles:
			continue
		var time_since_spawn: float = current_time_ms - circle.spawn_time_ms
		if time_since_spawn >= -PREEMPT_MS:
			circle.update_approach(time_since_spawn, PREEMPT_MS)
		# Auto-miss once the OK window (+grace) has closed.
		if time_since_spawn > hit_zone.OK_WINDOW + MISS_GRACE_MS and circle.hit_state == "not_hit":
			circle.set_hit_state("missed")
			score_manager.register_hit("miss")
			missed_circles.append(circle)

	# End the round once every circle is resolved.
	if active_circles.size() > 0 and (hit_circles.size() + missed_circles.size()) >= active_circles.size():
		_end_round()

func _start_round() -> void:
	_started = true
	# If the chart failed to load, _pending_lose already handled it; stay idle.
	if _pending_lose:
		return
	audio_player.play()
	game_active = true
	audio_ended = false
	last_audio_position_ms = 0.0
	post_audio_elapsed_ms = 0.0

func _update_ui() -> void:
	score_label.text = "Score: %d" % score_manager.get_score()
	combo_label.text = "Combo: %d" % score_manager.get_combo()
	accuracy_label.text = "Accuracy: %.1f%%" % score_manager.get_accuracy_pct()

func _end_round() -> void:
	game_active = false
	if audio_player.playing:
		audio_player.stop()
	# A WarioWare round must pass or fail on performance: win only above the
	# accuracy threshold; 40% or lower is a loss.
	if score_manager.get_accuracy_pct() > PASS_ACCURACY_PCT:
		win()
	else:
		lose()

func _input(event: InputEvent) -> void:
	"""Handle mouse clicks on circles."""
	if not game_active or event is not InputEventMouseButton:
		return

	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos := get_global_mouse_position()
		var current_time_ms: float
		if audio_player.playing:
			current_time_ms = audio_player.get_playback_position() * 1000.0
		else:
			current_time_ms = last_audio_position_ms + post_audio_elapsed_ms

		# Find the closest unprocessed circle under the click.
		var closest_circle: Circle = null
		var closest_distance := INF
		for circle in active_circles:
			if circle in hit_circles or circle in missed_circles:
				continue
			if circle.is_clickable(click_pos):
				var distance: float = circle.global_position.distance_to(click_pos)
				if distance < closest_distance:
					closest_circle = circle
					closest_distance = distance

		if closest_circle != null:
			var time_diff := current_time_ms - closest_circle.spawn_time_ms
			var result := "miss"
			if hit_zone.is_within_hit_window(time_diff):
				result = hit_zone.get_accuracy(time_diff)
				closest_circle.set_hit_state(result)
				score_manager.register_hit(result)
				hit_circles.append(closest_circle)
				_pulse_stage()
				if _sfx.stream != null:
					_sfx.play()
			else:
				closest_circle.set_hit_state("missed")
				score_manager.register_hit("miss")
				missed_circles.append(closest_circle)
			_show_accuracy_feedback(result, closest_circle.global_position + Vector2(40, 40))

		get_viewport().set_input_as_handled()

func _pulse_stage() -> void:
	"""Brighten the spotlight briefly so the stage 'breathes' with each hit."""
	if spotlight == null:
		return
	spotlight.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(spotlight, "modulate:a", 0.55, 0.25)

func _show_accuracy_feedback(accuracy: String, pos: Vector2) -> void:
	"""Show themed judgement text that floats up and fades at the hit position."""
	var label := Label.new()
	match accuracy:
		"perfect": label.text = "BRAVO!"
		"good": label.text = "ELEGANT!"
		"ok": label.text = "NOT BAD"
		_: label.text = "OUT OF TUNE"
	label.add_theme_font_size_override("font_size", 32)

	match accuracy:
		"perfect": label.add_theme_color_override("font_color", Color.GOLD)
		"good": label.add_theme_color_override("font_color", Color.DODGER_BLUE)
		"ok": label.add_theme_color_override("font_color", Color.LIGHT_SKY_BLUE)
		_: label.add_theme_color_override("font_color", Color.CRIMSON)

	label.global_position = pos - Vector2(20, 20)
	label.z_index = 100
	label.add_theme_font_override("font", JUDGE_FONT)
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_property(label, "global_position", pos + Vector2(0, -50), 0.8)
	tween.chain().tween_callback(label.queue_free)

func _spawn_circles() -> void:
	"""Instantiate all circles from the chart, hidden until their beat nears."""
	if circle_scene == null:
		push_error("[OsuGame] circle_scene failed to load.")
		return
	var combo_number := 1
	for circle_data in circles_data:
		var circle: Circle = circle_scene.instantiate()
		circle.set_spawn_time(circle_data.time_ms)
		circles_container.add_child(circle)
		# Control nodes anchor at top-left, so offset by radius to centre on (x,y).
		circle.global_position = Vector2(circle_data.x - 40.0, circle_data.y - 40.0)
		circle.set_combo_number(combo_number)
		active_circles.append(circle)
		combo_number += 1
