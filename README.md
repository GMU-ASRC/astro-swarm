# AstroSwarm

[![Godot](https://img.shields.io/badge/Godot-4.6.3-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![Language](https://img.shields.io/badge/language-GDScript-355570)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20windows%20%7C%20macOS-lightgrey)](#building-from-source)
[![Video Export](https://img.shields.io/badge/video%20export-FFmpeg-007808?logo=ffmpeg&logoColor=white)](https://ffmpeg.org/)
[![Status](https://img.shields.io/badge/status-in%20development-orange)](#)

AstroSwarm is a 2D pixel-art **tower-defense game (in development)** built in Godot 4. Press **Play** to enter your **player base** — a procedurally generated home planet orbited by moons you unlock as you level up, with XP and **AstroCoin** progression saved to a local profile. It also includes a full **swarm-behaviour simulator** sandbox: design species, program their behaviour with a drag-and-drop block editor, then record, replay, and export sessions to video. The pixel-art game shell is themed separately from the simulator.

> Multiplayer and the tower-defense matches are not implemented yet — the base GUI, progression, and persistence come first.

## Features

- **Player base & progression.** A procedurally generated home planet, moons that orbit it and unlock as you level up, an XP bar, and AstroCoin currency — all saved to a local profile.
- **Visual block editor.** Build per-species behaviour by stacking condition and action blocks — no coding required.
- **Custom species.** Tune speed, turn rate, vision range, and field of view, or start from the Hunter, Scout, and Worker presets.
- **Resizable arena.** Simulate swarms on custom-sized maps with free camera pan and zoom, plus walls and obstacles.
- **Save, record & replay.** Save setups, record live runs, and scrub them back on an interactive timeline.
- **Take-over control.** Drive any robot mid-simulation with the keyboard or a gamepad, including a 2-player multiplayer mode.
- **Pixel-art game shell.** An animated home screen and menus themed independently from the simulator.
- **Video export.** Render recorded runs to H.264 MP4 via a bundled ffmpeg binary, with one-click reveal in the file manager.

## Getting started

1. Open the project in Godot 4.6 (or newer) and press F5.
2. From the home screen, choose **Play** for your base (enter a callsign on first launch), or **Simulator** for the sandbox.
3. In the base, the **DEV TOOLS** buttons grant XP/AstroCoin so you can level up and unlock moons.
4. In the simulator, pick a species, left-drag to place robots, press **Start**, then save/replay/export from **Manage Setups**.

## Player base

Reached from **Play** — your home planet sits centre-screen with unlocked moons orbiting it, over the animated starfield:

- **Home planet & moons.** A procedural Terran-Wet planet plus No-Atmosphere moons, each generated from a saved seed so they look identical every run. Moons revolve on their own random orbits, passing in front of and behind the planet.
- **Progression.** Earn XP to level up; moons unlock with level (up to 5). AstroCoin is the in-game currency. Username, level, XP, coins, and all seeds persist to a local config file.
- **First launch.** A modal asks for your callsign before you claim your planet.

Multiplayer matches (the eventual XP/coin source) are stubbed for now — the DEV buttons stand in.

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
