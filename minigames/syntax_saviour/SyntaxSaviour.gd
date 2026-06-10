# =============================================================================
# minigames/syntax_saviour/SyntaxSaviour.gd   (redesigned)
# =============================================================================
# FACULTY: Faculty of Computer Science & Information Technology (FCSIT)
# PREMISE: Three rounds of broken Java code appear on a FCSIT lab monitor.
#          Each round: tap the buggy line before time runs out.
#          Wrong tap or timeout = immediate loss. Complete all 3 = win.
#
# SCENE SETUP (build in the Godot editor — see implementation plan):
# ─────────────────────────────────────────────────────────────────
#  SyntaxSaviour  (Node2D)              ← root — attach SyntaxSaviour.gd
#  ├── LabBackground  (TextureRect)
#  │     Anchor Preset: Full Rect
#  │     Texture: res://minigames/syntax_saviour/assets/lab_bg.png
#  │     Stretch Mode: Keep Aspect Covered
#  └── MonitorPanel  (Panel)
#        Anchor Preset: Full Rect
#        Offset Left: 60   Offset Top: 40
#        Offset Right: -60  Offset Bottom: -40
#        └── Layout  (VBoxContainer)
#              Anchor Preset: Full Rect
#              Offset Left: 10  Top: 10  Right: -10  Bottom: -10
#              ├── TabBar  (Label)
#              │     Horizontal Alignment: CENTER
#              │     Theme Override > Font Size: 14
#              └── CodeLines  (VBoxContainer)
#                    Size Flags > Vertical: Expand + Fill
# =============================================================================

extends MiniGameBase

# ---------------------------------------------------------------------------
# SNIPPET POOLS
# Each entry: "lines" = Array of code line strings
#             "buggy" = 0-based index of the buggy line
# ---------------------------------------------------------------------------

const POOL_1: Array = [
	{
		"lines": [
			"public class Main {",
			"    public static void main(String[] args) {",
			"        int x = 10",
			"        System.out.println(x);",
			"    }",
			"}",
		],
		"buggy": 2,
	},
	{
		"lines": [
			"public class Main {",
			"    public static void main(String[] args) {",
			"        String name = \"Alice\";",
			"        System.out.println(name)",
			"    }",
			"}",
		],
		"buggy": 3,
	},
	{
		"lines": [
			"public class Main {",
			"    public static void main(String[] args) {",
			"        int[] arr = new int[5;",
			"        arr[0] = 42;",
			"    }",
			"}",
		],
		"buggy": 2,
	},
	{
		"lines": [
			"public class Main {",
			"    public static void main(String[] args) {",
			"        int a = 3;",
			"        int b = 4;",
			"        System.out.println(a + b)",
			"    }",
			"}",
		],
		"buggy": 4,
	},
]

const POOL_2: Array = [
	{
		"lines": [
			"public class Main {",
			"    public static void main(String[] args) {",
			"        String count = 5;",
			"        System.out.println(count);",
			"    }",
			"}",
		],
		"buggy": 2,
	},
	{
		"lines": [
			"public class Main {",
			"    public static void main(String[] args) {",
			"        int x = 10;",
			"        if (x = 10) {",
			"            System.out.println(\"ten\");",
			"        }",
			"    }",
			"}",
		],
		"buggy": 3,
	},
	{
		"lines": [
			"public class Main {",
			"    public static void main(String[] args) {",
			"        int x = \"hello\";",
			"        System.out.println(x);",
			"    }",
			"}",
		],
		"buggy": 2,
	},
	{
		"lines": [
			"public class Main {",
			"    public static void main(String[] args) {",
			"        boolean flag = 1;",
			"        System.out.println(flag);",
			"    }",
			"}",
		],
		"buggy": 2,
	},
]

const POOL_3: Array = [
	{
		"lines": [
			"public class Main {",
			"    public static void main(String[] args) {",
			"        int[] arr = {1, 2, 3};",
			"        for (int i = 0; i <= arr.length; i++) {",
			"            System.out.println(arr[i]);",
			"        }",
			"    }",
			"}",
		],
		"buggy": 3,
	},
	{
		"lines": [
			"public static int add(int a, int b) {",
			"    int result = 0;",
			"    return result;",
			"    result = a + b;",
			"}",
		],
		"buggy": 2,
	},
	{
		"lines": [
			"public class Main {",
			"    public static void main(String[] args) {",
			"        int n = 5; int sum = 0;",
			"        for (int i = 1; i <= n; i++) {",
			"            sum = sum - i;",
			"        }",
			"        System.out.println(sum);",
			"    }",
			"}",
		],
		"buggy": 4,
	},
	{
		"lines": [
			"public class Main {",
			"    static boolean isEven(int n) {",
			"        return n % 2 == 1;",
			"    }",
			"    public static void main(String[] args) {",
			"        System.out.println(isEven(4));",
			"    }",
			"}",
		],
		"buggy": 2,
	},
]

# ---------------------------------------------------------------------------
# COLORS
# ---------------------------------------------------------------------------

const COLOR_CORRECT: Color = Color(0.1, 0.55, 0.25, 1.0)
const COLOR_WRONG:   Color = Color(0.55, 0.1, 0.1, 1.0)

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------

var _current_round: int = 0
var _rounds: Array = []

# ---------------------------------------------------------------------------
# NODE REFS  (paths must match the scene node tree)
# ---------------------------------------------------------------------------

@onready var tab_bar: Label = $UI/MonitorPanel/Layout/TabBar
@onready var code_lines: VBoxContainer = $UI/MonitorPanel/Layout/CodeLines

# ---------------------------------------------------------------------------
# SYNTAX HIGHLIGHT COLORS (VS Code "Dark+" inspired) & ROW BACKGROUND
# ---------------------------------------------------------------------------

const COLOR_ROW_BG:   Color  = Color(0.118, 0.118, 0.18, 1.0)
const COLOR_LINE_NUM: String = "#6a8759"
const COLOR_KEYWORD:  String = "#569cd6"
const COLOR_TYPE:     String = "#4ec9b0"
const COLOR_STRING_TK: String = "#ce9178"
const COLOR_NUMBER:   String = "#b5cea8"
const COLOR_DEFAULT:  String = "#d4d4d4"

const KEYWORDS: Array = ["public", "static", "void", "class", "return", "new", "if", "for", "while", "else", "do"]
const TYPES: Array = ["int", "String", "boolean", "double", "char", "float", "long"]

# ---------------------------------------------------------------------------
# AUDIO
# ---------------------------------------------------------------------------

var _tap_sound: AudioStreamPlayer
var _win_sound: AudioStreamPlayer
var _lose_sound: AudioStreamPlayer
var _bg_music: AudioStreamPlayer

# ---------------------------------------------------------------------------
# MINIGAMEBASE CONTRACT
# ---------------------------------------------------------------------------

func setup() -> void:
	base_duration = 15.0
	instruction_text = "Tap the buggy line!"
	_rounds = [
		POOL_1[randi() % POOL_1.size()],
		POOL_2[randi() % POOL_2.size()],
		POOL_3[randi() % POOL_3.size()],
	]
	_current_round = 0

	var header_font := load("res://assets/Font/Kenney Future.ttf")
	tab_bar.add_theme_font_override("font", header_font)
	tab_bar.add_theme_font_size_override("font_size", 20)
	tab_bar.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	tab_bar.add_theme_constant_override("shadow_offset_x", 2)
	tab_bar.add_theme_constant_override("shadow_offset_y", 2)

	_tap_sound = AudioStreamPlayer.new()
	_tap_sound.stream = load("res://400 Sounds Pack/UI/select_1.wav")
	add_child(_tap_sound)

	_win_sound = AudioStreamPlayer.new()
	_win_sound.stream = load("res://win v1.0.wav")
	add_child(_win_sound)

	_lose_sound = AudioStreamPlayer.new()
	_lose_sound.stream = load("res://lose v1.0.wav")
	add_child(_lose_sound)

	_bg_music = AudioStreamPlayer.new()
	_bg_music.stream = load("res://400 Sounds Pack/Musical Effects/music_box_mystery.wav")
	_bg_music.volume_db = -8.0
	_bg_music.finished.connect(func(): _bg_music.play())
	add_child(_bg_music)
	_bg_music.play()

	_load_round(0)

func _load_round(round_index: int) -> void:
	tab_bar.text = "SyntaxSaviour.java  —  Round %d / 3" % (round_index + 1)
	for child in code_lines.get_children():
		child.queue_free()
	var lines: Array = _rounds[round_index]["lines"]
	var mono_font := SystemFont.new()
	mono_font.font_names = PackedStringArray(["Courier New", "Courier", "monospace"])

	var row_sb := StyleBoxFlat.new()
	row_sb.bg_color = COLOR_ROW_BG
	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = COLOR_ROW_BG.lightened(0.15)

	for i in range(lines.size()):
		var btn := Button.new()
		btn.text = ""
		btn.custom_minimum_size = Vector2(0, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_stylebox_override("normal", row_sb)
		btn.add_theme_stylebox_override("disabled", row_sb)
		btn.add_theme_stylebox_override("hover", hover_sb)
		var captured_i: int = i
		btn.pressed.connect(func(): _on_line_pressed(captured_i))

		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.scroll_active = false
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.add_theme_font_override("normal_font", mono_font)
		rtl.add_theme_font_override("bold_font", mono_font)
		rtl.add_theme_font_size_override("normal_font_size", 16)
		rtl.set_anchors_preset(Control.PRESET_FULL_RECT)
		rtl.offset_left = 6
		rtl.text = "[color=%s]  %d   [/color]%s" % [COLOR_LINE_NUM, i + 1, _highlight_line(lines[i])]
		btn.add_child(rtl)

		code_lines.add_child(btn)

## Wraps Java keywords/types/strings/numbers in BBCode color tags for a
## VS Code-style syntax-highlighted look inside the RichTextLabel overlay.
func _highlight_line(line: String) -> String:
	var token_re := RegEx.new()
	token_re.compile("(\"[^\"]*\")|(\\b\\d+\\b)|(\\b[A-Za-z_][A-Za-z0-9_]*\\b)")
	var result := ""
	var last_end := 0
	for m in token_re.search_all(line):
		result += _escape_bbcode(line.substr(last_end, m.get_start() - last_end))
		var token: String = m.get_string()
		var color: String = COLOR_DEFAULT
		if token.begins_with("\""):
			color = COLOR_STRING_TK
		elif token.is_valid_int():
			color = COLOR_NUMBER
		elif token in KEYWORDS:
			color = COLOR_KEYWORD
		elif token in TYPES:
			color = COLOR_TYPE
		if color == COLOR_DEFAULT:
			result += _escape_bbcode(token)
		else:
			result += "[color=%s]%s[/color]" % [color, _escape_bbcode(token)]
		last_end = m.get_end()
	result += _escape_bbcode(line.substr(last_end))
	return result

## Escapes BBCode-significant brackets so literal "[]" in Java arrays display correctly.
func _escape_bbcode(s: String) -> String:
	return s.replace("[", "[lb]").replace("]", "[rb]")

func _on_line_pressed(line_index: int) -> void:
	for child in code_lines.get_children():
		child.disabled = true
	_tap_sound.play()
	var is_correct: bool = (line_index == _rounds[_current_round]["buggy"])
	var btn: Button = code_lines.get_child(line_index)
	if is_correct:
		_tint_button(btn, COLOR_CORRECT)
		_punch(btn)
		await get_tree().create_timer(0.5).timeout
		if _finished or not is_instance_valid(self):
			return
		_current_round += 1
		if _current_round >= _rounds.size():
			_bg_music.stop()
			_win_sound.play()
			win()
		else:
			_load_round(_current_round)
	else:
		_tint_button(btn, COLOR_WRONG)
		_shake(btn)
		_bg_music.stop()
		_lose_sound.play()
		await get_tree().create_timer(0.3).timeout
		if _finished or not is_instance_valid(self):
			return
		lose()

func _tint_button(btn: Button, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("disabled", sb)

## Quick scale "pop" to celebrate a correct tap.
func _punch(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

## Horizontal shake to call out a wrong tap.
func _shake(btn: Button) -> void:
	var origin_x: float = btn.position.x
	var tween := create_tween()
	for offset in [8.0, -8.0, 5.0, -5.0, 0.0]:
		tween.tween_property(btn, "position:x", origin_x + offset, 0.05) \
			.set_trans(Tween.TRANS_SINE)
