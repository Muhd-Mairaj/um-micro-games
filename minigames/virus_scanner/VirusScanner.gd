# =============================================================================
# minigames/virus_scanner/VirusScanner.gd
# =============================================================================
extends MiniGameBase

@onready var blackbox = $Blackbox
@onready var virus = $Virus
@onready var scanner_overlay = $ScannerOverlay
@onready var timer_label = $UI/TopPanel/TopLabel
@onready var instruction_panel = $UI/InstructionPanel

# ---------- AUDIO ----------
var audio_cough: AudioStreamPlayer
var audio_pop: AudioStreamPlayer
var audio_start: AudioStreamPlayer
var audio_win: AudioStreamPlayer
var audio_lose: AudioStreamPlayer

# ---------- SHADER ----------
const SCANNER_SHADER = """
shader_type canvas_item;

uniform vec2 scanner_pos = vec2(0.0, 0.0);
uniform float radius = 120.0;
uniform float overlay_alpha = 0.0;
uniform vec2 viewport_size;

void fragment() {
	vec2 screen_pos = SCREEN_UV * viewport_size;

	float dist = distance(screen_pos, scanner_pos);

	if (dist < radius) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, overlay_alpha);
	}
}
"""

# ---------- STATE ----------
enum Phase { PRE_GROW, GROW, WAIT, FADE, INSTRUCT, ACTIVE, WIN, DEAD }
var phase: Phase = Phase.PRE_GROW

# PRE_GROW
var pre_grow_time := 0.5
var pre_grow_elapsed := 0.0

# GROW
var grow_time := 1.5
var grow_elapsed := 0.0
var start_scale := Vector2()
var target_scale := Vector2()
var pop_played := false

# WAIT
var wait_time := 0.5
var wait_elapsed := 0.0

# FADE
var fade_time := 1.2
var fade_elapsed := 0.0

# INSTRUCT
var instruct_time := 2.0
var instruct_elapsed := 0.0

# SCANNER
var scanner_radius := 60.0
var scanner_pos := Vector2.ZERO
var scanner_material: ShaderMaterial

# VIRUS
var virus_found := false


# =============================================================================
func setup() -> void:
	# ~5.5s of intro animation plays before scanning starts, so the round needs
	# enough total time to actually find the virus. 16s leaves ~10s of scan time.
	# (Was 25s originally, then 12s which left only ~5s to scan — far too fast.)
	base_duration = 16.0
	instruction_text = "Scan for the virus!"

	var screen_size = get_viewport_rect().size

	blackbox.visible = false
	instruction_panel.visible = false
	virus.visible = false

	# scale blackbox
	var texture_size = blackbox.texture.get_size()
	start_scale = blackbox.scale
	var final_scale = screen_size.x / texture_size.x
	target_scale = Vector2(final_scale, final_scale)
	blackbox.position = screen_size / 2

	# shader setup
	var shader = Shader.new()
	shader.code = SCANNER_SHADER

	scanner_material = ShaderMaterial.new()
	scanner_material.shader = shader
	scanner_overlay.material = scanner_material

	scanner_overlay.position = Vector2.ZERO
	scanner_overlay.size = screen_size

	scanner_pos = Vector2(-9999, -9999)

	scanner_material.set_shader_parameter("scanner_pos", scanner_pos)
	scanner_material.set_shader_parameter("radius", scanner_radius)
	scanner_material.set_shader_parameter("overlay_alpha", 0.0)
	scanner_material.set_shader_parameter("viewport_size", screen_size)

	# virus spawn
	virus.position = Vector2(
		randf_range(150, screen_size.x - 150),
		randf_range(150, screen_size.y - 150)
	)

	scanner_overlay.visible = true

	# audio
	audio_cough = AudioStreamPlayer.new()
	audio_cough.stream = load("res://assets/assets_virus_scanner/cough_double.wav")
	add_child(audio_cough)

	audio_pop = AudioStreamPlayer.new()
	audio_pop.stream = load("res://assets/assets_virus_scanner/pop_1.wav")
	add_child(audio_pop)

	audio_start = AudioStreamPlayer.new()
	audio_start.stream = load("res://assets/assets_virus_scanner/start.wav")
	add_child(audio_start)

	audio_win = AudioStreamPlayer.new()
	audio_win.stream = load("res://win v1.0.wav")
	add_child(audio_win)

	audio_lose = AudioStreamPlayer.new()
	audio_lose.stream = load("res://lose v1.0.wav")
	add_child(audio_lose)

	audio_cough.play()


# =============================================================================
func _process(delta: float) -> void:
	match phase:
		Phase.PRE_GROW:  _handle_pre_grow(delta)
		Phase.GROW:      _handle_grow(delta)
		Phase.WAIT:      _handle_wait(delta)
		Phase.FADE:      _handle_fade(delta)
		Phase.INSTRUCT:  _handle_instruct(delta)
		Phase.ACTIVE:    _handle_scanner()
		Phase.WIN, Phase.DEAD:
			pass


# =============================================================================
func _handle_pre_grow(delta: float) -> void:
	pre_grow_elapsed += delta
	if pre_grow_elapsed >= pre_grow_time:
		blackbox.visible = true
		phase = Phase.GROW


func _handle_grow(delta: float) -> void:
	grow_elapsed += delta
	var t = clamp(grow_elapsed / grow_time, 0.0, 1.0)

	blackbox.scale = start_scale.lerp(target_scale, t)

	if not pop_played:
		audio_pop.play()
		pop_played = true

	if t >= 1.0:
		phase = Phase.WAIT


func _handle_wait(delta: float) -> void:
	wait_elapsed += delta
	if wait_elapsed >= wait_time:
		phase = Phase.FADE


func _handle_fade(delta: float) -> void:
	fade_elapsed += delta
	var t = clamp(fade_elapsed / fade_time, 0.0, 1.0)

	scanner_material.set_shader_parameter("overlay_alpha", t * t)

	if t >= 1.0:
		_start_instruct()


# =============================================================================
func _start_instruct() -> void:
	phase = Phase.INSTRUCT

	var screen_size = get_viewport_rect().size

	scanner_pos = screen_size / 2
	scanner_material.set_shader_parameter("scanner_pos", scanner_pos)
	scanner_material.set_shader_parameter("overlay_alpha", 1.0)

	timer_label.text = "Save the guy!"
	instruction_panel.visible = true
	instruct_elapsed = 0.0


func _handle_instruct(delta: float) -> void:
	instruct_elapsed += delta
	if instruct_elapsed >= instruct_time:
		instruction_panel.visible = false
		phase = Phase.ACTIVE
		audio_start.play()


# =============================================================================
func _handle_scanner() -> void:
	scanner_pos = get_global_mouse_position()
	scanner_material.set_shader_parameter("scanner_pos", scanner_pos)
	scanner_material.set_shader_parameter("radius", scanner_radius)

	if not virus_found:
		if scanner_pos.distance_to(virus.global_position) <= scanner_radius:
			virus_found = true
			virus.visible = true

			# SNAP circle to virus center (IMPORTANT FIX)
			scanner_pos = virus.global_position
			scanner_material.set_shader_parameter("scanner_pos", scanner_pos)

			_do_win()
		else:
			virus.visible = false


# =============================================================================
func _do_win() -> void:
	if _finished:
		return

	phase = Phase.WIN
	timer_label.text = "VIRUS FOUND !!!"
	audio_win.play()

	# Win IMMEDIATELY so a tight HUD timer can never beat the find. Previously this
	# awaited the full win-sound length, so finding the virus near the end let the
	# HUD timeout fire lose() first ("found it but marked lost").
	win()


func _do_lose() -> void:
	if _finished or phase == Phase.DEAD:
		return

	phase = Phase.DEAD
	virus.visible = true

	scanner_material.set_shader_parameter("scanner_pos", Vector2(-9999, -9999))

	timer_label.text = "YOU FAILED TO CONTAIN THE VIRUS"
	audio_lose.play()

	await get_tree().create_timer(audio_lose.stream.get_length()).timeout
	lose()


# =============================================================================
func _on_timeout() -> void:
	_do_lose()
