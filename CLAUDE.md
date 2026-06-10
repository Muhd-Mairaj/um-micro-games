# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WarioWare-style micro-game collection set in Universiti Malaya. Players chain through mini-games at increasing speed, each themed around a UM faculty. Built in **Godot 4.6** using **GDScript**. No external dependencies — everything runs inside the Godot editor.

## Running the Project

There is no CLI build system. All development happens in the Godot editor:

- **Run full game**: Press **F5** in the Godot editor (or click the Play button)
- **Run single mini-game in isolation**: Open the scene, press **F6**
- **Main scene**: `res://shared/GameManager.tscn` (set in Project -> Project Settings -> Application -> Run -> Main Scene)

There are no linting or test commands. Godot performs type checking and shows errors in the editor output panel at runtime.

## Architecture

### State Machine

```
TITLE -> INTRO -> PLAYING -> DROPOUT   (lives reach 0 mid-run)
                          -> GRADUATION (all games done, lives > 0)
DROPOUT / GRADUATION -> (play again) -> INTRO
```

GameManager owns the full state machine. Each state corresponds to a screen scene instantiated as a child of GameManager, then freed when done. Screen scenes emit a single signal (`started`, `done`, or `play_again`) that GameManager connects to in order to advance state.

### The Two-Layer Model

```
shared/     <- Framework (owned by Lead Programmer - do not edit without permission)
minigames/  <- One subfolder per mini-game (each developer owns only their subfolder)
```

**`shared/`** provides the entire game loop:
- `GameManager.gd/.tscn` - state machine; tracks lives (3) and faculty progress (0/12); shuffles and loads mini-games; injects `time_scale`; connects `hud.timed_out` to call `lose()` when timer expires
- `MiniGameBase.gd` - base class all mini-games extend; exposes `win()`, `lose()`, `base_duration`, `instruction_text`, `actual_duration()`, `time_scale`
- `HUD.gd/.tscn` - CanvasLayer overlay with lives display, progress counter, countdown bar, and result flash; emits `timed_out` signal when timer reaches zero
- `TitleScreen.gd/.tscn` - "Can You Graduate from UM?" splash; emits `started`
- `IntroScreen.gd/.tscn` - 5-second run intro, tap to skip; emits `done`
- `DropOutScreen.gd/.tscn` - game-over screen when lives reach 0; emits `play_again`
- `GraduationScreen.gd/.tscn` - victory + grade reveal when all games done; emits `play_again`

**`minigames/`** contains self-contained mini-game subfolders:
- `syntax_saviour/` - reference implementation (study this first)
- `slipper_hunt/` - second completed example

### MiniGameBase Contract

Every mini-game script **must** follow this pattern:

```gdscript
extends MiniGameBase

func setup() -> void:
    base_duration = 8.0          # recommended 5.0-15.0 seconds
    instruction_text = "..."     # shown in HUD
    # connect signals, randomise scene

func _on_something() -> void:
    win()    # or lose() - GameManager handles everything else
```

Critical constraints:
- Override `setup()`, **never** `_ready()` - GameManager injects `time_scale` before `_ready()` fires
- Never call `get_tree().change_scene_to_*()` - GameManager owns scene transitions
- Never create your own timer - HUD manages the countdown and automatically calls `lose()` when time runs out
- `win()` / `lose()` are guarded; calling them more than once is safe but avoid it

### Signal Flow

```
MiniGame.win()  -> game_won.emit()  -> GameManager._on_won()  -> hud.show_result(true)  -> _next()
MiniGame.lose() -> game_lost.emit() -> GameManager._on_lost() -> hud.show_result(false) -> _next()
HUD._on_timeout() -> timed_out.emit() -> GameManager._on_hud_timed_out() -> current_minigame.lose()
```

If lives reach 0 after a loss, `_on_lost()` calls `_show_dropout_screen()` instead of `_next()`.
If `current_index` reaches the end of `minigame_scenes`, `_end_run()` calls `_show_graduation_screen()`.

### Adding a New Mini-Game

1. Create `minigames/your_game_name/YourGameName.gd` and `YourGameName.tscn`
2. The scene root must be `Node2D`, named to match the class (e.g. `YourGameName`)
3. The `.gd` file's scene setup comment block is the blueprint for building the `.tscn`
4. Register the path in `GameManager.gd`'s `minigame_scenes` array when ready:
   ```gdscript
   "res://minigames/your_game_name/YourGameName.tscn",
   ```

### Mini-Game Design Constraints

- `base_duration`: 5.0-15.0 seconds depending on complexity
- Input: tap/click only - no drag, no keyboard
- Target resolution: 1280x720 - use anchors and containers, no hardcoded pixel positions
- Every run must end in exactly one `win()` or `lose()` call
- Only load files from your own `minigames/[your_game]/` or shared `assets/`

## Naming Conventions

| What | Convention |
|------|-----------|
| Mini-game folder | `snake_case` |
| Scene & script files | `PascalCase.tscn` / `PascalCase.gd` matching folder name |
| Asset files | `snake_case.ext` |
| GDScript variables/functions/signals | `snake_case` |
| GDScript constants | `UPPER_SNAKE_CASE` |
| Classes/nodes | `PascalCase` |

Git commits: `type(scope): description` e.g. `feat(slipper_hunt): add sprite swap logic`

## GDScript Gotchas (Python Background)

| Python | GDScript |
|--------|---------|
| `class Child(Parent):` | `extends ParentClass` (file-based, no import) |
| `__init__` | `setup()` (per this project's contract) |
| `None` / `True` / `False` | `null` / `true` / `false` |
| `len(arr)` | `arr.size()` |
| `time.sleep(n)` | `await get_tree().create_timer(n).timeout` |
| `randint(0, n)` | `randi() % n` |
| f-strings | `"value: %s" % x` |
| `@property` getter | regular function e.g. `func actual_duration() -> float:` |
| event callbacks | `signal_name.connect(fn)` |
| get child node | `$NodeName` or `get_node("NodeName")` |

`@onready var x = $NodeName` resolves the node reference when `_ready()` fires - use this instead of assigning node refs in `setup()`.

## Audio Assets

Required filenames that code references by name (place in `assets/sfx/` and `assets/music/`):
- `assets/sfx/win.wav`
- `assets/sfx/lose.wav`
- `assets/sfx/tick.wav`
- `assets/music/bg_loop.wav`

A royalty-free `400 Sounds Pack/` is included in the repo root for sourcing audio.
