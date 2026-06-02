# UM Micro Games

> This file is the single source of truth for all developers working on this project.
> Read it fully before touching any file.

A WarioWare-style micro-game collection set in Universiti Malaya (UM). Players chain through
mini-games at increasing speed, each themed around a specific UM faculty. Built in **Godot 4**
using **GDScript**.

**Goal:** "Can You Graduate from UM?" — complete all 12 faculty mini-games with at least 1 life remaining.  
**Win condition per mini-game:** Complete the task before the timer expires.  
**Lose condition:** Time runs out or the player makes a fatal mistake — costs 1 life (♥).  
**Lives:** Each run starts with 3 lives (♥♥♥). Reach 0 and you **Drop Out**.  
**Progression:** Speed scales up every 3 games. All mini-games are shuffled each run.  
**Endings:** Complete all 12 with lives remaining → Graduation ceremony + grade reveal (3♥ = First Class, 2♥ = Second Class Upper, 1♥ = Second Class Lower).

---

## Table of Contents

1. [Team & Roles](#1-team--roles)
2. [Getting Started](#2-getting-started)
3. [Engine & Tooling](#3-engine--tooling)
4. [Folder Structure](#4-folder-structure)
5. [Naming Conventions](#5-naming-conventions)
6. [Shared Components](#6-shared-components)
7. [The MiniGameBase Contract](#7-the-minigamebase-contract)
8. [How to Build Your Scene](#8-how-to-build-your-scene)
9. [Mini-Game Design Rules](#9-mini-game-design-rules)
10. [Git Workflow](#10-git-workflow)
11. [Week 12: Scene Registration](#11-week-12-scene-registration)
12. [GDScript vs Python Quick Reference](#12-gdscript-vs-python-quick-reference)

---

## 1. Team & Roles

| Name | Role | Game Task (Build 2 Games) | Danger Zone Task |
|------|------|---------------------------|-----------------|
| ALSHAMRANI MOHAMMED | **The Stitcher** | — | Combines all finished game files together in Week 12 |
| Mairaj | **Lead Programmer** | SyntaxSaviour (FCSIT) · SlipperHunt (API) | Codes the basic 10-second timer/Win/Lose script for all of us to use |
| Khaira Nafisa Binti Mohamed Fuad | **Art Director** | Build a Circuit (Engineering) · Rhythm Game (Creative Arts) | Decides the art style/colors so our 12 games look like they belong together |
| Auni Nafisa Binti Osman | **Lead Designer** | Virus Scanner (Medicine) · Lab Explosion (Science) | Enforces the strict file naming rules so our game doesn't crash when merged |
| Shahir Izzat Danial bin Mohd Aziz Shah | **Systems Balancer** | — | Tests all 12 games in Week 12 to make sure they aren't too hard or too easy. Files a GitHub Issue for any game that needs fixing. Deadline: end of Week 13 |
| Yusrina | **Audio Lead** | The Friday Slipper Hunt (API) · Bas UM Mode Crush (FBE) | Finds royalty-free sound effects & music for us all to use |

### Role Details

**Lead Programmer (Mairaj)**
- Builds and maintains everything in `shared/`
- Must be the first to push to GitHub — others are blocked until the shared framework is live
- Available to help teammates with GDScript questions
- Maintains the mini-game registry list in `GameManager.gd`
- Does NOT merge others' scenes into the registry until Week 12

**The Stitcher (ALSHAMRANI MOHAMMED)**
- In Week 12: clone the repo, add every finished mini-game path to the registry array in `GameManager.gd`, run the full game end-to-end, and fix any missing scene references
- Does NOT rewrite anyone's code — only wires up scene paths

**Art Director (Khaira)**
- Decides and documents the visual style (color palette, font, resolution) in a `STYLE_GUIDE.md` file added to `assets/`
- Drops shared sprites into `assets/ui/` and `assets/fonts/`
- Reviews each member's mini-game for visual consistency

**Lead Designer (Auni)**
- Audits every push for naming convention violations before Week 12
- Maintains a checklist of submitted mini-games in a `CHECKLIST.md` file in the root

**Systems Balancer (Shahir)**
- In Week 12: plays every mini-game and rates it Easy / Fair / Hard
- Files a GitHub Issue for any game that is too easy or too hard, tagging the developer
- Verifies that `time_scale` progression feels right across the full run

**Audio Lead (Yusrina)**
- A royalty-free sound pack is included in the repo under `400 Sounds Pack/` — browse it to find suitable sounds
- Copy your chosen files into `assets/sfx/` and `assets/music/` and rename them to the required filenames below
- Required filenames — **do not rename these** (code will reference them by name):
  - `assets/sfx/win.wav`
  - `assets/sfx/lose.wav`
  - `assets/sfx/tick.wav`
  - `assets/music/bg_loop.wav`

---

## 2. Getting Started

Follow these steps exactly, in order, before writing any code.

### Step 1 — Install Godot 4.6

1. Go to [https://godotengine.org/download](https://godotengine.org/download)
2. Download **Godot Engine 4.x (Standard)** for your OS (Windows / macOS / Linux)
3. Unzip it. There is no installer — the extracted `.exe` (Windows) or app (macOS) is the editor

> **Important:** Download Godot 4, NOT Godot 3. The APIs are completely different.

### Step 2 — Clone the repository

```bash
git clone https://github.com/[org]/um-microgames.git
cd um-microgames
```

Or use GitHub Desktop / any Git GUI if you prefer.

### Step 3 — Open the project in Godot

1. Launch the Godot editor
2. On the Project Manager screen, click **Import**
3. Navigate to the folder you cloned and select `project.godot`
4. Click **Import & Edit**

### Step 4 — Verify the main scene

The main scene should already be set to `GameManager.tscn`. To check or set it:

1. Go to **Project → Project Settings**
2. Click the **Application** section on the left, then **Run**
3. Confirm **Main Scene** is set to `res://shared/GameManager.tscn`
4. If not, click the folder icon and select `shared/GameManager.tscn`

### Step 5 — Run the project

Press **F5** (or click the Play button ▶ at the top right) to run the game.  
You should see the HUD timer bar and your mini-games playing in sequence.

---

## 3. Engine & Tooling

| Tool | Version | Notes |
|------|---------|-------|
| Godot | **4.6 (Standard)** | Use Godot 4, NOT Godot 3. API is different. |
| GDScript | Built-in | Python-like syntax. No external dependencies. |
| Version Control | Git + GitHub | See Section 10. Do NOT use zip sharing. |
| OS | Any (Linux / Windows / macOS) | Godot is cross-platform. |

---

## 4. Folder Structure

```
um-micro-games/
│
├── README.md                        ← You are here (single source of truth)
├── project.godot                    ← Godot project file (do not rename)
├── icon.svg
│
├── shared/                          ← LEAD PROGRAMMER OWNS THIS. Do not edit without permission.
│   ├── MiniGameBase.gd              ← Base class all mini-games extend
│   ├── GameManager.gd               ← State machine: lives, progress, screen transitions
│   ├── GameManager.tscn             ← Main scene (already set as startup scene)
│   ├── HUD.tscn                     ← Timer bar + lives + progress + WIN/LOSE overlay
│   ├── HUD.gd
│   ├── TitleScreen.tscn / .gd       ← "Can You Graduate from UM?" splash
│   ├── IntroScreen.tscn / .gd       ← 5-second run intro
│   ├── DropOutScreen.tscn / .gd     ← Game-over screen (0 lives)
│   └── GraduationScreen.tscn / .gd  ← Victory + grade reveal
│
├── minigames/                       ← EACH MEMBER OWNS ONLY THEIR OWN SUBFOLDER
│   ├── syntax_saviour/              ← Reference example — study this first
│   │   ├── SyntaxSaviour.tscn
│   │   ├── SyntaxSaviour.gd
│   │   └── assets/
│   │
│   ├── slipper_hunt/
│   │   ├── SlipperHunt.tscn
│   │   ├── SlipperHunt.gd
│   │   └── assets/
│   │
│   └── [faculty_gamename]/          ← Follow this exact pattern for every new game
│       ├── [FacultyGamename].tscn
│       ├── [FacultyGamename].gd
│       └── assets/                  ← Art/audio specific to this mini-game only
│
└── assets/                          ← SHARED ASSETS — Art Director & Audio Lead manage this
    ├── fonts/
    │   └── main_font.ttf
    ├── sfx/
    │   ├── win.ogg
    │   ├── lose.ogg
    │   └── tick.ogg
    ├── music/
    │   └── bg_loop.ogg
    └── ui/
        ├── timer_bar.png
        └── result_bg.png
```

---

## 5. Naming Conventions

**Violating these will cause merge conflicts and scene-loading failures.**

### Files & Folders

| What | Convention | Example |
|------|-----------|---------|
| Mini-game folder | `snake_case` | `syntax_saviour`, `slipper_hunt` |
| Scene file | `PascalCase.tscn` matching folder | `SyntaxSaviour.tscn` |
| Script file | `PascalCase.gd` matching scene | `SyntaxSaviour.gd` |
| Asset files | `snake_case.ext` | `blue_slipper.png`, `error_sound.ogg` |

### GDScript

| What | Convention | Example |
|------|-----------|---------|
| Variables | `snake_case` | `time_remaining`, `is_active` |
| Functions | `snake_case` | `func setup():`, `func _on_button_pressed():` |
| Constants | `UPPER_SNAKE_CASE` | `const MAX_TIME = 10.0` |
| Classes / Nodes | `PascalCase` | `MiniGameBase`, `SyntaxSaviour` |
| Signal names | `snake_case` | `signal game_won` |

### Git Commits

Use the format: `type(scope): description`

```
feat(syntax_saviour): add snippet shuffle logic
fix(game_manager): prevent crash on last game
art(slipper_hunt): add slipper sprites
audio(shared): add win/lose sound effects
```

---

## 6. Shared Components

These files live in `shared/` and are **owned by the Lead Programmer**. You use them but do not edit them.

### `MiniGameBase.gd` — the class you extend

Every mini-game script must start with `extends MiniGameBase`. This gives your game:

| What you get | Type | How to use it |
|---|---|---|
| `base_duration` | `float` | Set this in `setup()` to control how long your game lasts (5–10 seconds) |
| `instruction_text` | `String` | Set this in `setup()` — shown in the HUD as the player hint |
| `actual_duration()` | `float` (read-only) | Computed as `base_duration / time_scale`. Never assign to it. |
| `time_scale` | `float` | Set automatically by GameManager — do not set manually |
| `win()` | method | Call this when the player succeeds. GameManager handles the rest. |
| `lose()` | method | Call this when the player fails or time runs out. GameManager handles the rest. |

### `GameManager.gd` / `GameManager.tscn` — the state machine

**Do not touch these files.** GameManager runs the full game loop:
- Drives the screen sequence: Title → Intro → Playing → Dropout / Graduation
- Shuffles and loads all mini-games in sequence
- Tracks lives (3♥) and faculty progress (0/12) — decrements a life on each `lose()`, increments progress on each `win()`
- Injects `time_scale` into your game before it loads (so your game runs faster in later rounds)
- Listens for your `win()` / `lose()` calls and transitions to the next game
- Calls `lose()` on the current mini-game automatically when the HUD timer reaches zero
- Increases game speed every 3 rounds
- Shows Dropout screen if lives reach 0; Graduation screen if all games are completed with lives remaining

Your only interaction with GameManager is registering your scene path in its list (see [Section 11](#11-week-12-scene-registration)).

### `HUD.tscn` — the timer bar overlay

**Do not touch this file.** The HUD is automatically displayed on top of every mini-game. It:
- Shows lives remaining (♥♥♥) in the top-left
- Shows faculty progress (e.g. `3/12`) in the top-right
- Shows the countdown timer bar (green → yellow → red)
- Displays your `instruction_text` hint below the bar
- Flashes "NICE! ✓" or "TOO SLOW! ✗" after `win()` or `lose()` is called
- **Automatically triggers `lose()` when the timer reaches zero** — you do not need to handle timeout yourself

You never call HUD methods directly. Calling `win()` or `lose()` in your script is all it takes.

### Screen scenes — `TitleScreen`, `IntroScreen`, `DropOutScreen`, `GraduationScreen`

**Do not touch these files.** All managed automatically by GameManager:
- `TitleScreen.tscn` — "Can You Graduate from UM?" splash, shown at start and after "Play Again"
- `IntroScreen.tscn` — 5-second intro ("You have 3 lives. 12 faculties. One degree."), tap to skip
- `DropOutScreen.tscn` — shown when all 3 lives are lost; "Try Again" restarts the run
- `GraduationScreen.tscn` — shown when all mini-games are completed with lives remaining; displays grade based on lives left

---

## 7. The MiniGameBase Contract

Every mini-game **must** follow this contract. This is non-negotiable.

### What you extend

```gdscript
extends MiniGameBase
```

### What you must implement

| Method | Required | What to do inside it |
|--------|----------|----------------------|
| `setup()` | **Yes** | Set `base_duration`, set `instruction_text`, connect button signals, randomise your scene |
| Call `win()` | **Yes** | Call this anywhere in your script when the player succeeds |
| Call `lose()` | **Yes** | Call this anywhere in your script when the player fails |

### What you must NOT do

- Do **NOT** create your own timer. The HUD timer runs automatically and calls `lose()` for you when time is up.
- Do **NOT** call `get_tree().change_scene_to_*()`. GameManager handles all transitions.
- Do **NOT** override `_ready()`. Override `setup()` instead.
- Do **NOT** modify files in `shared/` without telling the Lead Programmer.
- Do **NOT** add nodes named `HUD`, `GameManager`, `TitleScreen`, `IntroScreen`, `DropOutScreen`, or `GraduationScreen` in your scene.
- Do **NOT** call `win()` or `lose()` more than once — a guard prevents double-firing but avoid it.

### Minimal working example

```gdscript
extends MiniGameBase

func setup() -> void:
    base_duration = 8.0
    instruction_text = "Tap the correct button!"
    $CorrectButton.pressed.connect(_on_correct)
    $WrongButton.pressed.connect(_on_wrong)

func _on_correct() -> void:
    win()   # Done. GameManager and HUD handle everything else.

func _on_wrong() -> void:
    lose()  # Done.
```

### Reference example

Open `minigames/syntax_saviour/SyntaxSaviour.gd` — this is a complete, working implementation of the contract. It shows how to:
- Pick a random puzzle in `setup()`
- Shuffle button labels so the correct answer isn't always in the same position
- Disable buttons immediately on tap to prevent double-input
- Reveal the correct answer on a wrong choice before calling `lose()`

---

## 8. How to Build Your Scene

Each mini-game needs a `.tscn` scene file alongside its `.gd` script. Here is how to build it from scratch in the Godot editor.

The scene setup for every mini-game is described in the comment block at the top of its `.gd` file. **Read that comment first** — it is the blueprint for your scene.

The steps below use `SyntaxSaviour` as the concrete example.

---

### Step 1 — Create a new scene

1. In Godot, go to **Scene → New Scene** (or press **Ctrl+N**)
2. Click **Other Node** when asked to choose a root node type
3. Search for `Node2D` and double-click it
4. The scene now has a single root node called `Node2D`

### Step 2 — Rename the root node

1. In the **Scene panel** (top-left), single-click the `Node2D` to select it
2. Press **F2** (or double-click) to rename it
3. Name it exactly as your class (e.g., `SyntaxSaviour`)

> The root node name must match your script's class name. Case-sensitive.

### Step 3 — Attach your script

1. With the root node selected, look at the top of the **Inspector panel** (right side)
2. Click the **Script icon** (a small scroll) or go to **Node → Attach Script**
3. Click the folder icon and navigate to your `.gd` file (e.g., `minigames/syntax_saviour/SyntaxSaviour.gd`)
4. Click **Load**

### Step 4 — Add child nodes

Add the nodes listed in your script's scene setup comment, one by one. For each node:

1. Select the parent node in the **Scene panel**
2. Click the **+** button (Add Child Node) or press **Ctrl+A**
3. Search for the node type and double-click it
4. Rename the node exactly as specified (names are case-sensitive and must match `$NodeName` references in the script)

**SyntaxSaviour node tree (from the script's scene setup comment):**

```
SyntaxSaviour  (Node2D)               ← root node (already created)
├── ColorRect                         ← background; Anchor Preset: Full Rect
│                                        Color: Color(0.118, 0.118, 0.180, 1)
└── VBoxContainer                     ← main layout; Anchor Preset: Full Rect
    ├── TitleLabel  (Label)           ← text: "Spot the bug!"; font size: 28; align: CENTER
    ├── CodeDisplay  (RichTextLabel)  ← name MUST be "CodeDisplay"; bbcode_enabled: true
    │                                    fit_content: true; custom_minimum_size: (0, 220)
    └── HBoxContainer                 ← button row; alignment: CENTER
        ├── ChoiceButton0  (Button)   ← name MUST be exactly "ChoiceButton0"
        ├── ChoiceButton1  (Button)   ← name MUST be exactly "ChoiceButton1"
        └── ChoiceButton2  (Button)   ← name MUST be exactly "ChoiceButton2"
                                         Each button: custom_minimum_size: (280, 70)
```

> **Why do names matter?** Your script references nodes by name: `$VBoxContainer/CodeDisplay`.
> If the name in the scene doesn't match the name in the script, Godot will crash at runtime.

### Step 5 — Set node properties

For each node in your tree, select it and set its properties in the **Inspector panel** on the right. Common properties:

- **Anchor Preset**: click the layout icon at the top of the Inspector → choose "Full Rect", "Center", etc.
- **Custom Minimum Size**: scroll down to find it in the Inspector under the Control section
- **Color** (on ColorRect): click the color swatch
- **Font Size** (on Label): scroll to **Theme Overrides → Font Sizes → Font Size** and enter a value

### Step 6 — Save the scene

1. Press **Ctrl+S**
2. Navigate to your mini-game folder (e.g., `minigames/syntax_saviour/`)
3. Name the file exactly as `YourGameName.tscn` (e.g., `SyntaxSaviour.tscn`)
4. Click **Save**

### Step 7 — Test it

Press **F5** to run the full game. Your mini-game will appear in the rotation if its path is already in `GameManager.gd`. If it is not registered yet, see [Section 11](#11-week-12-scene-registration).

To run only your scene in isolation (for quick testing), press **F6** instead of F5.

---

## 9. Mini-Game Design Rules

Each mini-game must satisfy **all** of the following:

| Rule | Requirement |
|------|------------|
| **Duration** | Set `base_duration` in `setup()` — recommended range is `5.0`–`15.0` seconds depending on your game's complexity |
| **Input** | Must be completable with **tap / click only**. No drag, no keyboard required. |
| **Clarity** | The goal must be obvious within 1 second of the scene loading. No tutorial text walls. |
| **Resolution** | Design for **1280×720**. Use anchors and containers — do not hardcode pixel positions. |
| **One outcome** | Every run of your mini-game must end in either `win()` or `lose()`. No infinite states. |
| **No external files** | Do not `load()` files outside your own `minigames/[your_game]/` folder or `assets/`. |
| **Faculty tie-in** | The mini-game must clearly reference its assigned faculty (location, activity, or stereotype). |

---

## 10. Git Workflow

Every member works on their **own branch**. Nobody commits directly to `main`.

### One-time setup (run once)

```bash
git clone https://github.com/[org]/um-microgames.git
cd um-microgames
git checkout -b your-name        # e.g. git checkout -b mairaj
git push -u origin your-name     # publish your branch to GitHub
```

Use your own name (lowercase, no spaces) as the branch name — e.g. `mairaj`, `khaira`, `auni`, `shahir`, `yusrina`, `alshamrani`.

### Daily workflow

```bash
git pull origin main             # Get the latest shared framework changes first
# ... make your changes ...
git add minigames/your_game_folder/       # Stage ONLY your folder
git commit -m "feat(your_game): what you did"
git push origin your-name        # Push to YOUR branch, not main
```

### When your game is ready

Tell the Lead Programmer or The Stitcher your branch is ready. They will review and merge it into `main`. Do not merge it yourself.

### Rules

1. **Always work on your own branch.** Never commit directly to `main`.
2. **Only stage and commit files inside your own `minigames/[your_game]/` folder.**
3. Never force-push (`git push --force`).
4. If you get a merge conflict: stop, ping the Lead Programmer on the group chat.
5. The `shared/` folder is owned by the Lead Programmer. Do not edit it.

### .gitignore

The root `.gitignore` must exclude Godot's generated files (already configured in this repo):

```
# Godot generated files
.godot/
*.translation
*.import

# OS files
.DS_Store
Thumbs.db
```

---

## 11. Week 12: Scene Registration

When your mini-game is finished, **submit your scene path** as a comment on the Week 12 GitHub Issue, in this exact format:

```
"res://minigames/your_game_folder/YourGameName.tscn"
```

Example:
```
"res://minigames/syntax_saviour/SyntaxSaviour.tscn"
```

**The Stitcher** (ALSHAMRANI MOHAMMED) will then add every submitted path to the array in `GameManager.gd`:

```gdscript
var minigame_scenes: Array[String] = [
    "res://minigames/syntax_saviour/SyntaxSaviour.tscn",
    "res://minigames/slipper_hunt/SlipperHunt.tscn",
    # The Stitcher adds one line per finished mini-game here
]
```

The Stitcher will run the full game end-to-end and fix any missing scene references before the final submission.

---

## 12. GDScript vs Python Quick Reference

All team members come from a Python background. Here is how GDScript maps to Python:

| Python | GDScript | Notes |
|--------|----------|-------|
| `def func():` | `func func() -> void:` | `-> void` is the return type annotation |
| `self.x` | `self.x` | Identical |
| `print()` | `print()` | Identical |
| `class Child(Parent):` | `extends ParentClass` | File-based, no import needed |
| `time.sleep(n)` | `await get_tree().create_timer(n).timeout` | Async wait — use `await` |
| Event callbacks | `signal_name.connect(fn)` | Godot's event system |
| `__init__` | `setup()` | Use `setup()` per our contract, not `_ready()` |
| — | `@onready var x = $NodeName` | Gets a child node by name when the scene loads |
| `# comment` | `# comment` | Identical |
| `None` | `null` | GDScript uses `null` |
| `True` / `False` | `true` / `false` | Lowercase in GDScript |
| `len(arr)` | `arr.size()` | GDScript uses `.size()` |
| `arr.append(x)` | `arr.append(x)` | Identical |
| `randint(0, n)` | `randi() % n` | Built-in, no import needed |
| f-string `f"{x}"` | `"value: %s" % x` | GDScript uses `%` formatting |
