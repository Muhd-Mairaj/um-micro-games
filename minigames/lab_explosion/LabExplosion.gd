# =============================================================================
# minigames/lab_explosion/LabExplosion.gd
# =============================================================================
extends MiniGameBase

@onready var explosion = $Explosion
@onready var liquid_container = $UI/RecipePanel/LiquidContainer
@onready var recipe_panel = $UI/RecipePanel
@onready var instruction_label = $UI/RecipePanel/Instruction
@onready var main_label = $UI/RecipePanel/Label

# ---------- AUDIO ----------
var win_sound: AudioStreamPlayer
var lose_sound: AudioStreamPlayer
var pop_sound: AudioStreamPlayer
var explode_sound: AudioStreamPlayer
var start_sound: AudioStreamPlayer

# ---------- STATE ----------
enum Phase { MEMO, RECALL, WIN, DEAD }
var phase: Phase = Phase.MEMO

var game_active := false

var liquid_names = [
	"Liquid1", "Liquid2", "Liquid3",
	"Liquid4", "Liquid5", "Liquid6",
	"Liquid7", "Liquid8", "Liquid9"
]

var correct_liquids: Array = []
var found_liquids: Array = []

var panel_original_size: Vector2
var panel_original_pos: Vector2

# ---------- RESPONSIVE LAYOUT ----------
# Reference design resolution. All hardcoded .tscn positions/scales below were
# authored against this size, so at 1280x720 the scale factor is exactly (1,1)
# and every node stays pixel-identical to the original layout.
const REFERENCE_SIZE: Vector2 = Vector2(1280, 720)

# Cached design-space rects/transforms captured once from the .tscn so we can
# re-derive responsive positions on every viewport resize without drift.
var _bg_ref_pos: Vector2
var _bg_ref_scale: Vector2
var _button_ref_rects: Dictionary = {}   # node_path -> Rect2 (in reference space)

# =============================================================================
# MINIGAMEBASE CONTRACT
# =============================================================================
func setup() -> void:
	base_duration = 25.0
	instruction_text = ""

	explosion.visible = false
	recipe_panel.visible = false

	panel_original_size = recipe_panel.size
	panel_original_pos  = recipe_panel.position

	# Capture the original .tscn-authored layout (in 1280x720 reference space),
	# apply it scaled to the current viewport, and keep it responsive on resize.
	_cache_reference_layout()
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_apply_responsive_layout)

	# --- create audio players ---
	win_sound = AudioStreamPlayer.new()
	win_sound.stream = load("res://win v1.0.wav")
	add_child(win_sound)

	lose_sound = AudioStreamPlayer.new()
	lose_sound.stream = load("res://lose v1.0.wav")
	add_child(lose_sound)

	pop_sound = AudioStreamPlayer.new()
	pop_sound.stream = load("res://assets/assets_lab_explosion/pop_1.wav")
	add_child(pop_sound)

	explode_sound = AudioStreamPlayer.new()
	explode_sound.stream = load("res://assets/assets_lab_explosion/explode.wav")
	add_child(explode_sound)

	start_sound = AudioStreamPlayer.new()
	start_sound.stream = load("res://assets/assets_lab_explosion/start.wav")
	add_child(start_sound)

	var pool = liquid_names.duplicate()
	pool.shuffle()
	correct_liquids = pool.slice(0, 4)

	_start_memo_phase()

# =============================================================================
# RESPONSIVE LAYOUT
# =============================================================================
# Records the original 1280x720-authored transforms so positions can be derived
# from get_viewport_rect().size on every resize. At 1280x720 this reproduces the
# .tscn exactly (scale factor = 1,1).
func _cache_reference_layout() -> void:
	var bg = get_node_or_null("Background")
	if bg:
		_bg_ref_pos = bg.position
		_bg_ref_scale = bg.scale

	for liquid in liquid_names:
		var btn := get_node_or_null("UI/" + liquid)
		if btn:
			_button_ref_rects[liquid] = Rect2(btn.position, btn.size)

# Repositions/rescales the background sprite and the 9 liquid buttons to match
# the current viewport, using REFERENCE_SIZE as the basis. Identity at 1280x720.
func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var factor: Vector2 = viewport_size / REFERENCE_SIZE

	# --- Background sprite ---
	var bg = get_node_or_null("Background")
	if bg:
		bg.position = _bg_ref_pos * factor
		bg.scale = _bg_ref_scale * factor

	# --- 9 liquid buttons (Control nodes in a CanvasLayer) ---
	for liquid in _button_ref_rects.keys():
		var btn := get_node_or_null("UI/" + liquid)
		if btn == null:
			continue
		var ref_rect: Rect2 = _button_ref_rects[liquid]
		btn.position = ref_rect.position * factor
		btn.size = ref_rect.size * factor

# =============================================================================
# PROCESS — only needed to detect recall phase timeout now.
# The HUD owns the authoritative countdown; we just watch game_active.
# =============================================================================
func _process(delta: float) -> void:
	if not game_active:
		return

	# HUD handles display; we only need to know when time runs out.
	# MiniGameBase will call lose() via its own timeout, but if you need
	# an in-scene explode trigger on timeout, keep this block:
	# (remove if MiniGameBase already handles timeout → lose() for you)

# =============================================================================
# MEMO PHASE
# =============================================================================
func _start_memo_phase() -> void:
	phase = Phase.MEMO
	game_active = false

	instruction_label.text = "Remember all these ingredients!"

	_populate_liquid_images(true)

	recipe_panel.visible = true
	recipe_panel.pivot_offset = recipe_panel.size / 2.0
	recipe_panel.scale = Vector2.ZERO

	var viewport_size = get_viewport_rect().size
	var target_size   = viewport_size * 0.75
	var target_scale  = Vector2(
		target_size.x / recipe_panel.size.x,
		target_size.y / recipe_panel.size.y
	)
	recipe_panel.position = (viewport_size - recipe_panel.size) / 2.0

	var tween = get_tree().create_tween()
	tween.tween_property(recipe_panel, "scale", target_scale, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tween.finished

	pop_sound.play()
	start_sound.play()

	# 5-second display window — no timer label, just a delay.
	await get_tree().create_timer(5.0).timeout

	_end_memo_phase()

func _end_memo_phase() -> void:
	_set_liquid_images_visible(false)

	recipe_panel.position = panel_original_pos

	var tween = get_tree().create_tween()
	tween.tween_property(recipe_panel, "scale", Vector2.ONE, 0.4) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

	_start_recall_phase()

# =============================================================================
# RECALL PHASE
# =============================================================================
func _start_recall_phase() -> void:
	phase = Phase.RECALL
	found_liquids.clear()
	game_active = true

	instruction_label.text = "Click all the ingredients needed!"

# =============================================================================
# LIQUID IMAGE HELPERS
# =============================================================================
func _populate_liquid_images(show_images: bool) -> void:
	for child in liquid_container.get_children():
		child.queue_free()

	for liquid in correct_liquids:
		var slot = Control.new()
		slot.custom_minimum_size = Vector2(80, 80)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.name = "Slot_" + liquid

		var tex_rect = TextureRect.new()
		tex_rect.name = "Tex"
		tex_rect.texture = load(
			"res://assets/assets_lab_explosion/liquid/" + liquid.to_lower() + ".png"
		)
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.visible = show_images
		slot.add_child(tex_rect)

		liquid_container.add_child(slot)

func _set_liquid_images_visible(is_visible: bool) -> void:
	for slot in liquid_container.get_children():
		var tex = slot.get_node_or_null("Tex")
		if tex:
			tex.visible = is_visible

# =============================================================================
# LIQUID CLICK
# =============================================================================
func _on_liquid_pressed(liquid_name: String) -> void:
	if phase != Phase.RECALL:
		return

	pop_sound.play()

	if liquid_name not in correct_liquids:
		_explode()
		return

	if liquid_name in found_liquids:
		return

	found_liquids.append(liquid_name)

	for slot in liquid_container.get_children():
		if slot.name == "Slot_" + liquid_name:
			var tex = slot.get_node_or_null("Tex")
			if tex:
				tex.visible = true
			break

	if found_liquids.size() == correct_liquids.size():
		_win()

# =============================================================================
# WIN / LOSE
# =============================================================================
func _win() -> void:
	if _finished:
		return

	game_active = false
	phase = Phase.WIN

	win_sound.play()

	recipe_panel.visible = true
	recipe_panel.pivot_offset = recipe_panel.size / 2.0

	instruction_label.text = "DONE !!!\nThanks for helping out"
	main_label.text = ""

	$UI/TimerPanel.visible = false

	var viewport_size = get_viewport_rect().size
	var target_size   = viewport_size * 0.75
	var target_scale = Vector2(
		target_size.x / recipe_panel.size.x,
		target_size.y / recipe_panel.size.y
	)

	recipe_panel.position = (viewport_size - recipe_panel.size) / 2.0
	recipe_panel.scale = Vector2.ZERO

	var tween = get_tree().create_tween()
	tween.tween_property(recipe_panel, "scale", target_scale, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tween.finished

	await get_tree().create_timer(win_sound.stream.get_length()).timeout

	win()

func _explode() -> void:
	if _finished:
		return
	if phase == Phase.DEAD:
		return

	phase = Phase.DEAD
	game_active = false

	var top_layer = CanvasLayer.new()
	top_layer.layer = 100
	get_tree().root.add_child(top_layer)
	explosion.reparent(top_layer)

	explosion.visible = true
	explosion.position = get_viewport_rect().size / 2.0
	explosion.scale = Vector2(0.1, 0.1)

	explode_sound.play()

	var tween = get_tree().create_tween()
	tween.tween_property(explosion, "scale", Vector2(2.0, 2.0), 0.5)
	await tween.finished

	await get_tree().create_timer(2.0).timeout
	lose_sound.play()

	await get_tree().create_timer(lose_sound.stream.get_length()).timeout

	explosion.visible = false

	lose()

# =============================================================================
# BUTTON SIGNAL HANDLERS
# =============================================================================
func _on_liquid1_pressed() -> void: _on_liquid_pressed("Liquid1")
func _on_liquid2_pressed() -> void: _on_liquid_pressed("Liquid2")
func _on_liquid3_pressed() -> void: _on_liquid_pressed("Liquid3")
func _on_liquid4_pressed() -> void: _on_liquid_pressed("Liquid4")
func _on_liquid5_pressed() -> void: _on_liquid_pressed("Liquid5")
func _on_liquid6_pressed() -> void: _on_liquid_pressed("Liquid6")
func _on_liquid7_pressed() -> void: _on_liquid_pressed("Liquid7")
func _on_liquid8_pressed() -> void: _on_liquid_pressed("Liquid8")
func _on_liquid9_pressed() -> void: _on_liquid_pressed("Liquid9")
