# =============================================================================
# minigames/syntax_saviour/SyntaxSaviour.gd
# =============================================================================
# FACULTY: Faculty of Computer Science & Information Technology
# PREMISE: A short Python snippet is shown with one deliberate syntax error.
#          Three buttons show candidate fixes/lines. Tap the correct (buggy) line
#          to win; tap a distractor to lose.
#
# SCENE SETUP (build this in the Godot editor):
# -----------------------------------------------
#   SyntaxSaviour  (Node2D)                    <- root, attach SyntaxSaviour.gd
#   └── ColorRect  (background)                <- fills viewport
#         Color: Color(0.118, 0.118, 0.180, 1) = #1E1E2E  (VSCode dark theme)
#         Anchor Preset: Full Rect
#   └── VBoxContainer  (main layout)
#         Anchor Preset: Full Rect
#         margin: 40px all sides (use theme_override or offset)
#         └── TitleLabel  (Label)              <- "Spot the bug!"
#               horizontal_alignment: CENTER
#               font_size override: 28
#         └── CodeDisplay  (RichTextLabel)     <- shows the Python snippet
#               name must be exactly "CodeDisplay"
#               bbcode_enabled: true
#               fit_content: true
#               custom_minimum_size: (0, 220)
#         └── HBoxContainer  (button row)
#               alignment: CENTER
#               ├── ChoiceButton0  (Button)    <- names must be exactly these
#               ├── ChoiceButton1  (Button)
#               └── ChoiceButton2  (Button)
#                     Each button:
#                       custom_minimum_size: (280, 70)
#                       clip_text: true
# =============================================================================

extends MiniGameBase

# ---------------------------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------------------------

## Background colour matching VSCode's default dark theme.
const BG_COLOR: Color = Color(0.118, 0.118, 0.180, 1.0)   # #1E1E2E

## Highlight colour used in BBCode to mark the error line in the snippet.
const ERROR_LINE_COLOR: String = "#FF6B6B"

## Button normal background colour (dark panel).
const BTN_COLOR_NORMAL: Color = Color(0.18, 0.18, 0.26, 1.0)

## Button highlight colour for the selected answer (set after outcome).
const BTN_COLOR_CORRECT: Color = Color(0.1, 0.7, 0.3, 1.0)
const BTN_COLOR_WRONG:   Color = Color(0.75, 0.1, 0.1, 1.0)

# ---------------------------------------------------------------------------
# SNIPPET LIBRARY
# Each entry is a Dictionary:
#   "code"        : BBCode string shown in CodeDisplay (highlight bug line in red)
#   "options"     : Array[String] of 3 button labels (one correct, two distractors)
#   "correct_idx" : Which index in options[] is the correct (buggy) answer
# ---------------------------------------------------------------------------
const SNIPPETS: Array = [
	{
		"code": (
			"[color=#9CDCFE]def[/color] [color=#DCDCAA]greet[/color](name):\n"
			+ "    [color=#9CDCFE]print[/color]([color=#CE9178]\"Hello, \"[/color] + name)\n"
			+ "[color=%s]    return \"Done\"[/color]\n"                         # missing colon on def — shown below
			+ "\n[color=#9CDCFE]greet[/color]([color=#CE9178]\"World\"[/color])"
		) % ERROR_LINE_COLOR,
		# The real error is on line 1: `def greet(name)` is missing a colon.
		# We present the OPTIONS as line labels so the player picks the buggy line.
		"options": ["Line 1: def greet(name)", "Line 2: print(...)", "Line 4: greet(\"World\")"],
		"correct_idx": 0,
		# Explanation shown in button tooltip (optional — editor can add later).
		"hint": "Missing colon after the function definition."
	},
	{
		"code": (
			"[color=#9CDCFE]for[/color] i [color=#9CDCFE]in[/color] [color=#DCDCAA]range[/color](5):\n"
			+ "[color=%s]print(i)[/color]\n"                                   # missing indentation
			+ "[color=#9CDCFE]if[/color] i == 4:\n"
			+ "    [color=#9CDCFE]print[/color]([color=#CE9178]\"done\"[/color])"
		) % ERROR_LINE_COLOR,
		"options": ["Line 2: print(i)", "Line 3: if i == 4:", "Line 1: for i in range(5):"],
		"correct_idx": 0,
		"hint": "print(i) is not indented inside the for loop."
	},
	{
		"code": (
			"[color=#9CDCFE]def[/color] [color=#DCDCAA]add[/color](a, b):\n"
			+ "    [color=#9CDCFE]return[/color] a + b\n"
			+ "\n"
			+ "[color=%s]result = add(2 3)[/color]\n"                          # missing comma
			+ "[color=#9CDCFE]print[/color](result)"
		) % ERROR_LINE_COLOR,
		"options": ["Line 4: result = add(2 3)", "Line 2: return a + b", "Line 5: print(result)"],
		"correct_idx": 0,
		"hint": "Missing comma between arguments: add(2, 3)."
	},
]

# ---------------------------------------------------------------------------
# RUNTIME STATE
# ---------------------------------------------------------------------------

## Index of the snippet chosen for this round.
var _snippet_index: int = 0

## Which button index (0–2) holds the correct answer THIS round.
## Shuffled in setup() so the correct button isn't always the same.
var _correct_button_index: int = 0

## Cached button node references, filled in setup().
var _buttons: Array[Button] = []

# ---------------------------------------------------------------------------
# NODE REFERENCES
# ---------------------------------------------------------------------------

@onready var code_display: RichTextLabel = $VBoxContainer/CodeDisplay
@onready var choice_button_0: Button = $VBoxContainer/HBoxContainer/ChoiceButton0
@onready var choice_button_1: Button = $VBoxContainer/HBoxContainer/ChoiceButton1
@onready var choice_button_2: Button = $VBoxContainer/HBoxContainer/ChoiceButton2

# ---------------------------------------------------------------------------
# MINIGAMEBASE CONTRACT
# ---------------------------------------------------------------------------

func setup() -> void:
	# How long the player has to spot the bug.
	base_duration = 7.0

	# One-line hint shown in the HUD above the scene.
	instruction_text = "Find the syntax error!"

	# Collect button references into an array for easy indexed access.
	_buttons = [choice_button_0, choice_button_1, choice_button_2]

	# Pick a random snippet from the library.
	_snippet_index = randi() % SNIPPETS.size()
	var snippet: Dictionary = SNIPPETS[_snippet_index]

	# Display the code with BBCode colouring.
	code_display.text = snippet["code"]

	# The snippet defines which option is "correct" at index correct_idx.
	# We now shuffle the button assignment so the correct answer isn't always
	# the same button position each time.
	var original_correct: int = snippet["correct_idx"]
	var option_labels: Array = snippet["options"].duplicate()   # copy so we can reorder

	# Generate a random permutation of [0, 1, 2].
	var perm: Array[int] = [0, 1, 2]
	perm.shuffle()

	# Apply the permutation: perm[i] is which original option goes on button i.
	_correct_button_index = -1
	for i in range(3):
		var original_option_index: int = perm[i]
		_buttons[i].text = option_labels[original_option_index]
		# If this button is displaying the original correct option, record it.
		if original_option_index == original_correct:
			_correct_button_index = i

	# Connect each button's pressed signal to a handler that knows its index.
	# We use a lambda (anonymous function) to capture `i` by value.
	for i in range(3):
		var btn: Button = _buttons[i]
		var captured_i: int = i   # Capture the current value of i in this closure.
		btn.pressed.connect(func(): _on_button_pressed(captured_i))

## Called when any of the three buttons is tapped.
func _on_button_pressed(button_index: int) -> void:
	# Disable all buttons to prevent double-input while result flashes.
	for btn in _buttons:
		btn.disabled = true

	if button_index == _correct_button_index:
		# Correct! Highlight the button green and win.
		_buttons[button_index].add_theme_color_override("font_color", BTN_COLOR_CORRECT)
		win()
	else:
		# Wrong choice. Highlight red and lose.
		_buttons[button_index].add_theme_color_override("font_color", BTN_COLOR_WRONG)
		# Also reveal the correct button in green so the player learns.
		_buttons[_correct_button_index].add_theme_color_override("font_color", BTN_COLOR_CORRECT)
		lose()
