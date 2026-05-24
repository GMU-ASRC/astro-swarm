# AstroSwarm

[![Godot](https://img.shields.io/badge/Godot-4.6.3-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![Language](https://img.shields.io/badge/language-GDScript-355570)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20windows%20%7C%20macOS-lightgrey)](#building-from-source)
[![Video Export](https://img.shields.io/badge/video%20export-FFmpeg-007808?logo=ffmpeg&logoColor=white)](https://ffmpeg.org/)
[![Status](https://img.shields.io/badge/status-in%20development-orange)](#)

AstroSwarm is a visual swarm-behaviour simulator built in Godot 4. Design species with unique traits, program their behaviour with a drag-and-drop block editor, drop them into a resizable arena, then record, replay, and export full sessions to video. It's wrapped in a pixel-art game shell with its own animated menus, kept visually separate from the simulator.

## Features

- **Visual block editor.** Build per-species behaviour by stacking condition and action blocks — no coding required.
- **Custom species.** Tune speed, turn rate, vision range, and field of view, or start from the Hunter, Scout, and Worker presets.
- **Resizable arena.** Simulate swarms on custom-sized maps with free camera pan and zoom, plus walls and obstacles.
- **Save, record & replay.** Save setups, record live runs, and scrub them back on an interactive timeline.
- **Take-over control.** Drive any robot mid-simulation with the keyboard or a gamepad, including a 2-player multiplayer mode.
- **Pixel-art game shell.** An animated home screen and menus themed independently from the simulator.
- **Video export.** Render recorded runs to H.264 MP4 via a bundled ffmpeg binary, with one-click reveal in the file manager.

## Getting started

1. Open the project in Godot 4.6 (or newer) and press F5.
2. From the home screen, choose **Simulator**.
3. Pick a species (or create your own), then left-drag in the arena to place robots.
4. Press **Start** and scale time with the speed controls.
5. Save layouts and export recorded runs from **Manage Setups**.

## Controls

- **Place robots** — left-click + drag (with the Place Robots tool); the drag direction sets the facing.
- **Robot menu** — right-click a robot to take over, release, remove, toggle its trail, or pin its coordinates.
- **Camera** — middle-mouse drag to pan, scroll wheel to zoom.
- **Drive a taken-over robot** — WASD / arrow keys, or a gamepad's left stick.

## Block reference

Behaviour is built from three block types:

- **Config** — set a physical parameter (speed, turn rate, vision range, FOV).
- **Condition** — start a rule (Always; When I see anyone / nobody; When I touch or see a wall; When I see / don't see a species).
- **Action** — run while the condition holds (move, stop, wander, turn, face target, flee).

Actions placed before any condition run under `Always`.

## Default species

| Species | Speed | Turn rate | Vision | FOV | Default behaviour |
|---|---|---|---|---|---|
| Hunter | 5.25 m/s | 3.0 rad/s | 5.5 m | 55° | Face anyone it sees |
| Scout | 3.75 m/s | 2.0 rad/s | 4.5 m | 110° | Wander |
| Worker | 2.4 m/s | 1.4 rad/s | 3.25 m | 180° | Flee anyone it sees |

All move forward by default; add your own species with the **+** button.

## Recording and replay

Starting a run records every robot's position and rotation in the background; on **Stop** or **Clear** it's saved as a `.run` file. Load one from **Manage Setups** to scrub it back and forth on an interactive timeline.

## Take-over mode

Right-click a robot and choose **Take Over** to drive it manually. Control is keyboard-based by default; enable **Controller Mode** (and **Multiplayer** for two controllers) in **Arena Settings**. Controlled robots show a **P1**/**P2** badge — press **Esc** or the gamepad's **B** to release. Stopping or clearing the arena releases all of them.

## Video export

From **Manage Setups**, **Export to Video** renders a recorded run to an H.264 MP4 through a bundled ffmpeg binary, then offers a one-click reveal of the output folder.

## Player settings

Display (window mode), graphics (V-Sync, FPS cap, anti-aliasing), rebindable keybinds, and audio volumes — all persisted between sessions.

## Building from source

The project targets Godot 4.6. Clone the repository, open `project.godot`, and use **Project -> Export** to build for Linux, Windows, or macOS. See `bin/README.md` for bundling the ffmpeg binaries used by video export.
