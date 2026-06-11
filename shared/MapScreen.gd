# =============================================================================
# shared/MapScreen.gd
# =============================================================================
# PURPOSE:
#   The faculty "map" / level-select shown after the Intro. Lists all 12 games
#   (name + faculty) as cards. The player picks any game in any order; clearing
#   one marks it done. When all 12 are cleared, GameManager shows Graduation.
#
#   Signals:
#     game_selected(scene_path) - player tapped a game card
#     graduate_now              - the TEST button: jump straight to Graduation
#
#   GameManager sets `completed` (scene_path -> true) before add_child so the
#   map shows which games are already cleared.
# =============================================================================

extends CanvasLayer

signal game_selected(scene_path)
signal graduate_now

# The 12 games: display name + faculty + scene path. Order/labels per the owner.
const GAMES: Array = [
	{ "name": "Syntax Saviour",         "faculty": "Computer Science & IT (FSKTM)",   "scene": "res://minigames/syntax_saviour/SyntaxSaviour.tscn" },
	{ "name": "Don't Flinch",           "faculty": "Dentistry",                       "scene": "res://minigames/cavity_chase/CavityChase.tscn" },
	{ "name": "Build a Circuit",        "faculty": "Engineering",                     "scene": "res://minigames/circuit_lab/CircuitLab.tscn" },
	{ "name": "Rhythm Game",            "faculty": "Creative Arts",                   "scene": "res://minigames/osu_um/OsuGame.tscn" },
	{ "name": "Virus Scanner",          "faculty": "Medicine",                        "scene": "res://minigames/virus_scanner/VirusScanner.tscn" },
	{ "name": "Lab Explosion",          "faculty": "Science",                         "scene": "res://minigames/lab_explosion/LabExplosion.tscn" },
	{ "name": "Don't Get Caught",       "faculty": "Education",                       "scene": "res://minigames/phone_down/PhoneDown.tscn" },
	{ "name": "False Start",            "faculty": "Sports & Exercise Sciences",      "scene": "res://minigames/hurdle_rush/HurdleRush.tscn" },
	{ "name": "The Friday Slipper Hunt","faculty": "Academy of Islamic Studies (API)","scene": "res://minigames/friday_slipper_hunt/FridaySlipperHunt.tscn" },
	{ "name": "Bas UM Model Crush",     "faculty": "Built Environment (FBE)",         "scene": "res://minigames/bas_um_model_crush/BasUmModelCrush.tscn" },
	{ "name": "Order in the Court",     "faculty": "Law (FUU)",                       "scene": "res://minigames/order_in_the_court/OrderInTheCourt.tscn" },
	{ "name": "Catch the Cash",         "faculty": "Business & Accountancy (FPP)",    "scene": "res://minigames/catch_the_cash/CatchTheCash.tscn" },
]

const DONE_COLOR: Color = Color(0.55, 1.0, 0.65, 1.0)
const TODO_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const HEART_FULL: String = "♥"
const HEART_EMPTY: String = "♡"

# Set by GameManager before this node enters the tree.
var completed: Dictionary = {}   # scene_path -> true
var lives: int = 3               # shared hearts for the whole run

var _cards: Dictionary = {}

@onready var grid: GridContainer = $Margin/VBox/Grid
@onready var lives_label: Label = $Margin/VBox/Lives
@onready var progress_label: Label = $Margin/VBox/Progress
@onready var test_button: Button = $Margin/VBox/TestButton

func _ready() -> void:
	test_button.pressed.connect(func() -> void: graduate_now.emit())
	_build_cards()
	_refresh()

func _build_cards() -> void:
	for g in GAMES:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(280, 124)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.clip_text = false
		btn.focus_mode = Control.FOCUS_NONE
		var path: String = g["scene"]
		btn.pressed.connect(func() -> void: game_selected.emit(path))
		grid.add_child(btn)
		_cards[path] = btn

func _refresh() -> void:
	for g in GAMES:
		var btn: Button = _cards.get(g["scene"])
		if btn == null:
			continue
		var done: bool = completed.has(g["scene"])
		btn.text = ("[ DONE ]  " if done else "") + g["name"] + "\n" + g["faculty"]
		btn.modulate = DONE_COLOR if done else TODO_COLOR
	var hearts: String = ""
	for i in range(3):
		hearts += (HEART_FULL if i < lives else HEART_EMPTY) + " "
	lives_label.text = hearts.strip_edges()
	progress_label.text = "%d / 12 faculties cleared  -  clear all 12 to graduate!" % completed.size()
