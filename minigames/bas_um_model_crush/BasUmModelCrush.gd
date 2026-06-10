extends MiniGameBase

# ── Player settings ──
var player_speed   = 150.0
var player_base_y  = 0.0
var bus_arrive_x   = 0.0
var player_max_x   = 0.0
var player_start_x = 0.0
var walk_time      = 0.0
var game_active    = false

# ── Student settings ──
var student_speed  = 80.0
var lose_range     = 80.0
var tap_range      = 400.0
var student_hidden = false
var tapped         = false

# ── Nodes ──
var player          : Node = null
var animated_sprite : Node = null
var student1        : Node = null
var tap_sound       : Node = null
var bus             : Node = null

func _ready() -> void:
	player          = $Player
	animated_sprite = $Player/AnimatedS
	student1        = $Student1
	tap_sound       = $TapSound
	bus             = $Bus

	$Student1/ClickArea.input_event.connect(_on_student_tapped)

	setup()

func _on_student_tapped(_viewport, event, _shape_idx) -> void:
	if not game_active or student_hidden:
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return

	tap_sound.play()
	tapped            = true
	student_hidden    = true
	student1.visible  = false
	student1.modulate = Color(1, 1, 1, 1)
	student1.stop_student()
	_schedule_respawn()

func setup() -> void:
	if not player or not animated_sprite or not student1 or not bus or not tap_sound:
		push_error("Missing node!")
		return

	base_duration    = 12.0
	instruction_text = "Walk to the bus! Tap students blocking you!"

	var bg = get_node_or_null("Background")
	if bg and bg is TextureRect:
		bg.size = get_viewport_rect().size

	player_base_y  = player.position.y
	player_start_x = player.position.x
	player_max_x   = player.position.x

	if bus is TextureRect:
		bus_arrive_x = bus.position.x + bus.size.x
	else:
		bus_arrive_x = bus.position.x + 300.0

	player.z_index         = 5
	animated_sprite.flip_h = true
	animated_sprite.stop()

	student1.position = Vector2(bus_arrive_x + 250.0, player_base_y)
	student1.z_index  = 4
	student_hidden    = false
	student1.visible  = true

	game_active = true

func _schedule_respawn() -> void:
	await get_tree().create_timer(3.0).timeout
	if game_active:
		student1.reset_student(
			bus_arrive_x + randi() % 200 + 150,
			player_base_y
		)
		student_hidden = false

func _process(delta: float) -> void:
	if not game_active:
		return

	walk_time += delta

	if Input.is_action_pressed("ui_left"):
		player.position.x     -= player_speed * delta
		player.position.y      = player_base_y + sin(walk_time * 9.0) * 7.0
		animated_sprite.flip_h = true
		animated_sprite.play("walk")

	elif Input.is_action_pressed("ui_right"):
		player.position.x = min(
			player.position.x + player_speed * delta,
			player_max_x
		)
		player.position.y      = player_base_y + sin(walk_time * 9.0) * 7.0
		animated_sprite.flip_h = false
		animated_sprite.play("walk")

	else:
		animated_sprite.stop()
		player.position.y = player_base_y

	# ── WIN ──
	if player.position.x <= bus_arrive_x:
		game_active    = false
		student_hidden = true
		animated_sprite.stop()
		animated_sprite.frame = 4
		student1.visible = false
		student1.stop_student()
		win()
		return

	# ── Student logic ──
	if not student_hidden:
		var dist = student1.position.distance_to(player.position)

		student1.position.x += student_speed * delta
		student1.position.y  = player_base_y + sin(walk_time * 8.0) * 5.0

		if dist < tap_range:
			student1.modulate = Color(1.0, 0.4, 0.4, 1.0)
		else:
			student1.modulate = Color(1.0, 1.0, 1.0, 1.0)

		# ── LOSE ──
		if dist < lose_range:
			if tapped:
				tapped = false
			else:
				_trigger_lose()
				return

		if student1.position.x > player.position.x + 150:
			student1.modulate = Color(1, 1, 1, 1)
			student1.reset_student(
				bus_arrive_x + randi() % 200 + 150,
				player_base_y
			)

func _trigger_lose() -> void:
	game_active    = false
	student_hidden = true
	animated_sprite.stop()
	student1.stop_student()
	student1.modulate = Color(1, 1, 1, 1)
	player.modulate   = Color(1.0, 0.1, 0.1, 1.0)
	await get_tree().create_timer(0.5).timeout
	player.modulate = Color(1, 1, 1, 1)
	lose()
