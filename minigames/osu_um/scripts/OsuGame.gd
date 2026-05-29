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

func _ready() -> void:
	"""Initialize managers."""
	chart_manager = ChartManager.new()
	score_manager = ScoreManager.new()
	circle_scene = load("res://minigames/osu_um/Circle.tscn")
	hit_zone = HitZone.new()
	add_child(hit_zone)

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
	print("DEBUG: Audio playing")
	
	print("OsuGame setup complete. Duration: %.2f seconds, Circles: %d" % [base_duration, circles_data.size()])

func _process(_delta: float) -> void:
	"""Update game state."""
	if not audio_player.playing:
		return
	
	# Update UI
	score_label.text = "Score: %d" % score_manager.get_score()
	combo_label.text = "Combo: %d" % score_manager.get_combo()
	var accuracy_dict = score_manager.get_accuracy_counts()
	var total = accuracy_dict.perfect + accuracy_dict.good + accuracy_dict.ok + accuracy_dict.miss
	var accuracy_pct = (100.0 * (accuracy_dict.perfect * 300 + accuracy_dict.good * 100 + accuracy_dict.ok * 50)) / max(total * 300, 1)
	accuracy_label.text = "Accuracy: %.1f%%" % accuracy_pct
	
	# Show circles whose spawn time has arrived
	var current_time_ms = audio_player.get_playback_position() * 1000.0
	print("DEBUG: Current time: %.0f ms" % current_time_ms)
	for circle in circles_container.get_children():
		if circle in hit_circles or circle in missed_circles:
			continue
		var time_since_spawn = current_time_ms - circle.spawn_time_ms
		# Make circle visible when approaching or at spawn time
		if time_since_spawn >= -500:  # Show 500ms before spawn
			circle.visible = true
			print("DEBUG: Circle visible at spawn_time: %.0f ms" % circle.spawn_time_ms)
		# Mark as missed if too late
		if time_since_spawn > hit_zone.OK_WINDOW and circle.hit_state == "not_hit":
			circle.set_hit_state("missed")
			score_manager.register_hit("miss")
			missed_circles.append(circle)
	
	# Check if all circles have been processed and song finished
	if audio_player.get_playback_position() >= base_duration:
		win()

func _input(event: InputEvent) -> void:
	"""Handle mouse clicks on circles."""
	if not audio_player.playing or event is not InputEventMouseButton:
		return
	
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = get_global_mouse_position()
		var current_time_ms = audio_player.get_playback_position() * 1000.0
		
		# Find the closest unprocessed circle to this click
		var closest_circle = null
		var closest_distance = INF
		
		for circle in active_circles:
			if circle in hit_circles or circle in missed_circles:
				continue
			
			if circle.is_clickable(click_pos):
				var distance = circle.global_position.distance_to(click_pos)
				if distance < closest_distance:
					closest_circle = circle
					closest_distance = distance
		
		if closest_circle:
			var time_diff = current_time_ms - closest_circle.spawn_time_ms
			if hit_zone.is_within_hit_window(time_diff):
				var accuracy = hit_zone.get_accuracy(time_diff)
				closest_circle.set_hit_state(accuracy)
				score_manager.register_hit(accuracy)
				hit_circles.append(closest_circle)
			else:
				closest_circle.set_hit_state("missed")
				score_manager.register_hit("miss")
				missed_circles.append(closest_circle)
		
		get_tree().set_input_as_handled()

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
		circle.global_position = Vector2(circle_data.x, circle_data.y)
		circle.visible = false  # Hidden until spawn time approaches
		circles_container.add_child(circle)
		active_circles.append(circle)
		print("DEBUG: Circle spawned at (%.0f, %.0f) with time %.0f ms" % [circle_data.x, circle_data.y, circle_data.time_ms])
