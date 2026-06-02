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
	_load_round(0)

func _load_round(round_index: int) -> void:
	tab_bar.text = "SyntaxSaviour.java  —  Round %d / 3" % (round_index + 1)
	for child in code_lines.get_children():
		child.queue_free()
	var lines: Array = _rounds[round_index]["lines"]
	var mono_font := SystemFont.new()
	mono_font.font_names = PackedStringArray(["Courier New", "Courier", "monospace"])
	for i in range(lines.size()):
		var btn := Button.new()
		btn.text = "  %d   %s" % [i + 1, lines[i]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_override("font", mono_font)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color(0.863, 0.863, 0.863, 1.0))
		var captured_i: int = i
		btn.pressed.connect(func(): _on_line_pressed(captured_i))
		code_lines.add_child(btn)

func _on_line_pressed(line_index: int) -> void:
	for child in code_lines.get_children():
		child.disabled = true
	var is_correct: bool = (line_index == _rounds[_current_round]["buggy"])
	var btn: Button = code_lines.get_child(line_index)
	if is_correct:
		_tint_button(btn, COLOR_CORRECT)
		await get_tree().create_timer(0.5).timeout
		if not is_instance_valid(self):
			return
		_current_round += 1
		if _current_round >= _rounds.size():
			win()
		else:
			_load_round(_current_round)
	else:
		_tint_button(btn, COLOR_WRONG)
		await get_tree().create_timer(0.3).timeout
		if not is_instance_valid(self):
			return
		lose()

func _tint_button(btn: Button, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("disabled", sb)
