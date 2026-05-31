extends MiniGameBase

# ── Player settings ──
var player_speed  = 200.0
var player_base_y = 1276.0
var bus_arrive_x  = 800.0
var player_max_x  = 2775.0   # ← cannot go further right than start!
var walk_time     = 0.0
var game_active   = false

# ── Student settings ──
var student_speed  = 80.0
var lose_range     = 100.0
var tap_range      = 300.0
var student_hidden = false

# ── Node references ──
@onready var player          = $Player
@onready var animated_sprite = $Player/AnimatedS
@onready var student1        = $Student1
@onready var tap_sound       = $TapSound 

# ── Solo testing only ──────────────────────────
func _ready() -> void:
	setup()

# ── MiniGameBase Contract ──────────────────────
func setup() -> void:
	base_duration    = 12.0
	instruction_text = "Walk to the bus! Tap students blocking you!"

	player.position        = Vector2(2775.0, player_base_y)
	player.z_index         = 5
	animated_sprite.flip_h = true
	animated_sprite.stop()

	student1.position = Vector2(616, player_base_y)
	student1.z_index  = 4
	student_hidden    = false
	student1.visible  = true

	game_active = true

# ── Tap detection ──────────────────────────────
func _input(event: InputEvent) -> void:
	if not game_active:
		return
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return
	tap_sound.play()
	if student_hidden:
		return

	var click_pos   = get_global_mouse_position()
	var dist_click  = click_pos.distance_to(student1.global_position)
	var dist_player = student1.global_position.distance_to(player.global_position)

	if dist_click > 150:
		return
	if dist_player > tap_range:
		return

	# Valid tap!
	student_hidden    = true
	student1.visible  = false
	student1.modulate = Color(1, 1, 1, 1)
	student1.stop_student()
	_schedule_respawn()

func _schedule_respawn() -> void:
	await get_tree().create_timer(3.0).timeout
	if game_active:
		student1.reset_student(
			randi() % 300 + 150,
			player_base_y
		)
		student_hidden = false

# ── Main game loop ─────────────────────────────
func _process(delta: float) -> void:
	if not game_active:
		return

	walk_time += delta

	# ── User controls player ──
	if Input.is_action_pressed("ui_left"):
		player.position.x     -= player_speed * delta
		player.position.y      = player_base_y + sin(walk_time * 9.0) * 7.0
		animated_sprite.flip_h = true
		animated_sprite.play("walk")

	elif Input.is_action_pressed("ui_right"):
		# ← clamp so player cannot go past start position!
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

	# ── Check WIN first before anything else! ──
	if player.position.x <= bus_arrive_x:
		game_active = false
		animated_sprite.stop()
		animated_sprite.frame = 4
		student_hidden = true     # stop student processing!
		student1.visible = false
		student1.stop_student()
		win()                     # ← WIN overlay!
		return

	# ── Student moves RIGHT ──
	if not student_hidden:
		var dist = student1.global_position.distance_to(
			player.global_position
		)

		student1.position.x += student_speed * delta
		student1.position.y  = player_base_y + sin(walk_time * 8.0) * 5.0

		# Glow red when in tap range
		if dist < tap_range:
			student1.modulate = Color(1.0, 0.4, 0.4, 1.0)
		else:
			student1.modulate = Color(1.0, 1.0, 1.0, 1.0)

		# ── Check LOSE ──
		if dist < lose_range:
			_trigger_lose()
			return

		# Student past player → respawn from left
		if student1.position.x > 3000:
			student1.modulate = Color(1, 1, 1, 1)
			student1.reset_student(
				randi() % 300 + 150,
				player_base_y
			)

func _trigger_lose() -> void:
	game_active    = false
	student_hidden = true   # stop student processing!
	animated_sprite.stop()
	student1.stop_student()
	student1.modulate = Color(1, 1, 1, 1)
	player.modulate   = Color(1.0, 0.1, 0.1, 1.0)
	await get_tree().create_timer(0.5).timeout
	player.modulate = Color(1, 1, 1, 1)
	lose()                  # ← LOSE overlay!
