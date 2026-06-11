extends MiniGameBase

@export var green_slipper_image: Texture2D

var green_slippers_list = [] 

func setup() -> void:
	base_duration = 10.0
	instruction_text = "Find YOUR slippers!"

	var screen_w = get_viewport_rect().size.x
	var screen_h = get_viewport_rect().size.y

	var min_x = 150
	var max_x = screen_w - 150
	var min_y = screen_h * 0.65 
	var max_y = screen_h - 100  

	# --- 1. SPAWN 100 CAMOUFLAGED GREEN SLIPPERS ---
	for i in range(100):
		var green_slipper = Sprite2D.new()
		green_slipper.texture = green_slipper_image
		green_slipper.scale = Vector2(0.5, 0.5)
		green_slipper.position = Vector2(
			randf_range(min_x, max_x),
			randf_range(min_y, max_y)
		)
		green_slipper.rotation_degrees = randf_range(0, 360)
		
		# Make the green slippers slightly different shades (some darker, some lighter)
		# This breaks up the colors and makes the eyes easily confused!
		var random_shade = randf_range(0.6, 1.0)
		green_slipper.modulate = Color(random_shade, random_shade, random_shade)
		
		add_child(green_slipper)
		green_slippers_list.append(green_slipper) 

	# --- 2. SETUP THE BLUE SLIPPER ---
	$BlueSlipper.scale = Vector2(0.5, 0.5)
	$BlueSlipper.position = Vector2(
		randf_range(min_x, max_x),
		randf_range(min_y, max_y)
	)
	$BlueSlipper.rotation_degrees = randf_range(0, 360)
	$BlueSlipper.move_to_front()

	# --- 3. THE DEVIOUS COLOR TRICK ---
	# We apply a green tint over the blue slipper! 
	# Color values are (Red, Green, Blue). Adjust these decimals if you want it more/less green!
	$BlueSlipper.modulate = Color(0.4, 1.0, 0.6)

	# 4. Make the blue slipper pulse
	var tween = get_tree().create_tween().set_loops()
	tween.tween_property($BlueSlipper, "scale", Vector2(0.25, 0.25), 0.5)
	tween.tween_property($BlueSlipper, "scale", Vector2(0.15, 0.15), 0.5)

	$BlueSlipper.pressed.connect(_on_win)
	$WrongClickBackground.pressed.connect(_on_lose)

	# Disable clicking during the first 1.5 seconds
	$BlueSlipper.disabled = true
	$WrongClickBackground.disabled = true
	
	await get_tree().create_timer(1.5).timeout
	
	$BlueSlipper.disabled = false
	$WrongClickBackground.disabled = false

func _process(delta: float) -> void:
	# Spin all the slippers to make it dizzying
	for slipper in green_slippers_list:
		slipper.rotation += 1.0 * delta 

func _on_win() -> void:
	$BlueSlipper.disabled = true
	$WrongClickBackground.disabled = true
	if has_node("SuccessSound"):
		$SuccessSound.play()
	win()

func _on_lose() -> void:
	$BlueSlipper.disabled = true
	$WrongClickBackground.disabled = true
	lose()
