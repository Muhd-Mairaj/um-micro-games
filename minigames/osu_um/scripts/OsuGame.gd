extends MiniGameBase
class_name OsuGame

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var circles_container: Node2D = $CirclesContainer
@onready var score_label: Label = $UI/ScoreLabel
@onready var combo_label: Label = $UI/ComboLabel
@onready var accuracy_label: Label = $UI/AccuracyLabel

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
var post_audio_elapsed_ms: float = 0.0  # Time accumulated after audio stops

func _ready() -> void:
	"""Initialize managers."""
	chart_manager = ChartManager.new()
	score_manager = ScoreManager.new()
	circle_scene = load("res://minigames/osu_um/Circle.tscn")
	hit_zone = HitZone.new()
	add_child(hit_zone)
	
	# Call setup() for standalone testing
	# (GameManager will call setup() again when used in full game)
	call_deferred("setup")

func setup() -> void:
	"""Called by GameManager to initialize the game."""
	instruction_text = "Click the circles to the beat!"
	
	# Load test chart
	chart_path = "res://minigames/osu_um/charts/test_chart.json"
	if not chart_manager.load_chart(chart_path):
		print("Failed to load chart, calling lose()")
		lose()
		return
	
	circles_data = chart_manager.get_circles()
	score_manager.reset()
	
	# Set game duration based on chart
	base_duration = float(chart_manager.get_duration_ms()) / 1000.0
	
	# Spawn all circles at game start
	print("DEBUG: Spawning %d circles" % circles_data.size())
	_spawn_circles()
	print("DEBUG: Spawned circles. CirclesContainer has %d children" % circles_container.get_child_count())
	
	# Start audio playback
	audio_player.play()
	game_active = true
	audio_ended = false
	last_audio_position_ms = 0.0
	post_audio_elapsed_ms = 0.0
	print("DEBUG: Audio playing")
	
	print("OsuGame setup complete. Duration: %.2f seconds, Circles: %d" % [base_duration, circles_data.size()])

func _process(delta: float) -> void:
	"""Update game state."""
	if not game_active:
		return
	
	# Sync game time to audio playback (the melody is the source of truth)
	var current_time_ms: float
	if audio_player.playing:
		current_time_ms = audio_player.get_playback_position() * 1000.0
		last_audio_position_ms = current_time_ms  # Track in case audio ends
	else:
		# Audio finished — continue ticking from where it stopped
		if not audio_ended:
			audio_ended = true
			post_audio_elapsed_ms = 0.0
		post_audio_elapsed_ms += delta * 1000.0
		current_time_ms = last_audio_position_ms + post_audio_elapsed_ms
	
	# Update UI
	score_label.text = "Score: %d" % score_manager.get_score()
	combo_label.text = "Combo: %d" % score_manager.get_combo()
	var accuracy_dict = score_manager.get_accuracy_counts()
	var total = accuracy_dict.perfect + accuracy_dict.good + accuracy_dict.ok + accuracy_dict.miss
	var accuracy_pct = (100.0 * (accuracy_dict.perfect * 300 + accuracy_dict.good * 100 + accuracy_dict.ok * 50)) / max(total * 300, 1)
	accuracy_label.text = "Accuracy: %.1f%%" % accuracy_pct
	
	# Show circles whose spawn time has arrived (synced to audio)
	var process_time_ms = current_time_ms
	for idx in range(circles_container.get_child_count()):
		var circle = circles_container.get_child(idx)
		# Only process Circle nodes, skip ParticleBurst
		if not circle is Circle:
			continue
		if circle in hit_circles or circle in missed_circles:
			continue
		var time_since_spawn = process_time_ms - circle.spawn_time_ms
		
		# Debug circle 3 specifically (spawn time 3000ms)
		if circle.spawn_time_ms == 3000.0:
			print("DEBUG CIRCLE 3: time_since_spawn=%.0f, visible=%s, in_hit=%s, in_miss=%s" % [time_since_spawn, circle.visible, circle in hit_circles, circle in missed_circles])
		
		# Make circle visible when approaching spawn time
		if time_since_spawn >= -500:  # Show 500ms before spawn
			if not circle.visible:
				circle.visible = true
				print("DEBUG: Circle visible at spawn_time: %.0f ms, pos: (%.0f, %.0f)" % [circle.spawn_time_ms, circle.global_position.x, circle.global_position.y])
		# Only mark as missed if we're WELL past the hit window (3+ seconds after spawn)
		# This gives the player time to click, but eventually cleans up old circles
		if time_since_spawn > 3000 and circle.hit_state == "not_hit":
			circle.set_hit_state("missed")
			score_manager.register_hit("miss")
			missed_circles.append(circle)
	
	# Check if all circles have been processed (hit or missed)
	var all_resolved = (hit_circles.size() + missed_circles.size()) >= active_circles.size()
	if all_resolved:
		print("DEBUG: All circles resolved. Hit: %d, Missed: %d, Total: %d" % [hit_circles.size(), missed_circles.size(), active_circles.size()])
		game_active = false
		win()

func _input(event: InputEvent) -> void:
	"""Handle mouse clicks on circles."""
	if not game_active or event is not InputEventMouseButton:
		return
	
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = get_global_mouse_position()
		# Use audio position for timing (synced to the melody)
		var current_time_ms: float
		if audio_player.playing:
			current_time_ms = audio_player.get_playback_position() * 1000.0
		else:
			current_time_ms = last_audio_position_ms + post_audio_elapsed_ms
		
		print("DEBUG: Click at (%.0f, %.0f) at time %.0f ms" % [click_pos.x, click_pos.y, current_time_ms])
		
		# Find the closest unprocessed circle to this click
		var closest_circle = null
		var closest_distance = INF
		
		for circle in active_circles:
			if circle in hit_circles or circle in missed_circles:
				continue
			
			if circle.is_clickable(click_pos):
				var distance = circle.global_position.distance_to(click_pos)
				print("DEBUG: Circle at (%.0f, %.0f) is clickable, distance: %.0f" % [circle.global_position.x, circle.global_position.y, distance])
				if distance < closest_distance:
					closest_circle = circle
					closest_distance = distance
		
		if closest_circle:
			var time_diff = current_time_ms - closest_circle.spawn_time_ms
			print("DEBUG: Clicked circle at time %.0f ms, spawn was %.0f ms, diff: %.0f" % [current_time_ms, closest_circle.spawn_time_ms, time_diff])
			if hit_zone.is_within_hit_window(time_diff):
				var accuracy = hit_zone.get_accuracy(time_diff)
				closest_circle.set_hit_state(accuracy)
				score_manager.register_hit(accuracy)
				hit_circles.append(closest_circle)
				print("DEBUG: HIT! Accuracy: %s" % accuracy)
				_show_accuracy_feedback(accuracy, closest_circle.global_position + Vector2(40, 40))
			else:
				closest_circle.set_hit_state("missed")
				score_manager.register_hit("miss")
				missed_circles.append(closest_circle)
				print("DEBUG: MISS! Too late")
				_show_accuracy_feedback("miss", closest_circle.global_position + Vector2(40, 40))
		else:
			print("DEBUG: No clickable circles found at this position")
		
		get_viewport().set_input_as_handled()

func _show_accuracy_feedback(accuracy: String, position: Vector2) -> void:
	"""Show accuracy text that fades out at click position."""
	var label = Label.new()
	label.text = accuracy.to_upper()
	label.add_theme_font_size_override("font_size", 32)
	
	# Color based on accuracy
	match accuracy:
		"perfect": label.add_theme_color_override("font_color", Color.GREEN)
		"good": label.add_theme_color_override("font_color", Color.YELLOW)
		"ok": label.add_theme_color_override("font_color", Color.ORANGE)
		"miss": label.add_theme_color_override("font_color", Color.RED)
	
	# Position at click location
	label.global_position = position - Vector2(20, 20)  # Rough center offset
	
	add_child(label)
	
	# Move up while fading out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_property(label, "global_position", position + Vector2(0, -50), 0.8)
	tween.tween_callback(label.queue_free)

func _spawn_circles() -> void:
	"""Instantiate all circles from the chart."""
	if circle_scene == null:
		print("ERROR: circle_scene is null!")
		return
	print("DEBUG: circle_scene loaded, spawning %d circles" % circles_data.size())
	for circle_data in circles_data:
		var circle = circle_scene.instantiate()
		if circle == null:
			print("ERROR: Failed to instantiate circle!")
			continue
		circle.set_spawn_time(circle_data.time_ms)
		# Control nodes anchor at top-left, so offset by circle radius to center it
		circle.global_position = Vector2(circle_data.x - 40.0, circle_data.y - 40.0)
		circle.visible = false  # Hidden until spawn time approaches
		circles_container.add_child(circle)
		active_circles.append(circle)
		print("DEBUG: Circle spawned at (%.0f, %.0f) with time %.0f ms, positioned at (%.0f, %.0f)" % [circle_data.x, circle_data.y, circle_data.time_ms, circle.global_position.x, circle.global_position.y])
