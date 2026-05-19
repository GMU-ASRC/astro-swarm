# AstroSwarm

[![Godot](https://img.shields.io/badge/Godot-4.7-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![Language](https://img.shields.io/badge/language-GDScript-355570)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20windows%20%7C%20macOS-lightgrey)](#building-from-source)
[![Video Export](https://img.shields.io/badge/video%20export-FFmpeg-007808?logo=ffmpeg&logoColor=white)](https://ffmpeg.org/)
[![Status](https://img.shields.io/badge/status-in%20development-orange)](#)

AstroSwarm is a visual swarm-behaviour simulator built in Godot 4. Design species with unique physical traits, program their behaviour with a block editor, place them in a resizable arena, record and replay full sessions, and export the results to H.264 video for sharing.

---

## Table of contents

- [Features](#features)
- [Getting started](#getting-started)
- [Controls](#controls)
- [Block reference](#block-reference)
- [Default species](#default-species)
- [Recording and replay](#recording-and-replay)
- [Take-over mode](#take-over-mode)
- [Video export](#video-export)
- [Player settings](#player-settings)
- [Building from source](#building-from-source)

---

## Features

- **Visual block editor.** Compose per-species behaviour from condition and action blocks (Always, When I see anyone, When I touch a wall, Move forward, Wander, Face target, Flee, and more).
- **Per-species physical parameters.** Speed, turn rate, vision range, and field-of-view configurable as sliders or as in-line block parameters.
- **Resizable arena.** Physics bounds run from 10 m to 100 m on each axis, independent of window size. Pan with middle-mouse drag, zoom with the scroll wheel; grid line weight scales with zoom.
- **Setup save and load.** Persist species, behaviours, and starting placements as portable `.save` files.
- **Run recording and scrubbable replay.** Positions and rotations are sampled every 100 ms during a live simulation, written to `.run` files, and replayed with an interactive timeline slider.
- **Take-over control.** Switch any robot mid-simulation from rule-driven to keyboard-driven, then release back to AI.
- **Video export.** Render a recorded run to a standard H.264 MP4 via a bundled ffmpeg binary, with one-click reveal in the OS file manager.

## Getting started

1. Open the project in Godot 4.7 (or newer) and press F5 to launch.
2. From the home screen, select **Play** to enter the Arena.
3. In the sidebar, pick a species (Hunter, Scout, or Worker) or add a new one.
4. Right-click and drag in the arena to place a robot; the drag direction sets the spawn heading.
5. Click **Start** in the top bar to begin the simulation. Use `1x`, `2x`, or `3x` to scale time.
6. Click **Stop** to reset robots to their initial placements, or **Manage Setups** in the sidebar to save the configuration and access recorded runs.

## Controls

### Arena

| Input | Action |
|---|---|
| Right-click + drag | Place a robot; drag length and direction set its facing |
| Left-click on a robot | Open the radial action menu (Take Over, Release, Remove) |
| Middle-mouse drag | Pan the camera |
| Scroll wheel | Zoom in or out |

### Time controls

| Input | Action |
|---|---|
| Start / Pause / Resume | Toggle the simulation |
| Stop | Reset robots to initial placements and save the recording |
| 1x / 2x / 3x | Time-scale multiplier |

The Stop button is only visible while the simulation is actively running.

## Block reference

Behaviours are composed in the workspace by stacking blocks of three categories.

| Category | Purpose | Examples |
|---|---|---|
| Config | Sets a per-species physical parameter | Set speed to, Set turn rate to, Set vision range to, Set FOV to |
| Condition | Begins a rule; subsequent action blocks fire while the condition holds | Always, When I see anyone, When I see nobody, When I touch a wall, When I see a wall, When I see a [species], When I don't see a [species] |
| Action | Drives the robot while its parent condition is active | Move forward, Move backward, Stop, Wander randomly, Turn left at, Turn right at, Turn left by, Turn right by, Face the target, Flee the target, Throttle to |

Condition blocks group the following action blocks until the next condition. Action blocks before any condition implicitly run under `Always`.

## Default species

| Species | Speed | Turn rate | Vision | FOV | Default behaviour |
|---|---|---|---|---|---|
| Hunter | 5.25 m/s | 3.0 rad/s | 5.5 m | 55 deg | Face anyone seen; always move forward |
| Scout | 3.75 m/s | 2.0 rad/s | 4.5 m | 110 deg | Wander; always move forward |
| Worker | 2.4 m/s | 1.4 rad/s | 3.25 m | 180 deg | Flee anyone seen; always move forward |

## Recording and replay

- Pressing **Start** begins sampling each robot's position and rotation at 10 Hz in the background.
- On **Stop** or **Clear**, captured frames are written as a timestamped `.run` file into `user://runs/`.
- In **Manage Setups**, select a run and click **Load Selected Run** to enter replay mode. The top bar's count label is replaced with a draggable timeline slider; scrubbing seeks the replay without re-running AI or physics.

## Take-over mode

Open the radial menu on any robot and select **Take Over** to drive that robot manually. A yellow ring renders around the controlled robot for the duration.

| Input | Action |
|---|---|
| W / Up arrow | Move forward |
| S / Down arrow | Move backward |
| A / Left arrow | Turn left |
| D / Right arrow | Turn right |
| Esc | Release control |

Take-over respects each species' configured speed and turn rate, so a controlled Hunter still outruns a controlled Worker. Only one robot can be controlled at a time; selecting Take Over on a second robot releases the first. Stopping or clearing the arena also releases control. Recording continues during take-over, so a manually driven session replays correctly.

## Video export

The **Export to Video** button on the run manager renders a `.run` file to MP4:

1. The scene loads in headless export mode with all UI overlays hidden except the time readout.
2. The arena is stepped through every recorded frame; each frame is captured from the viewport and written to `user://export_frames/`.
3. A bundled ffmpeg binary stitches the PNG sequence into H.264 at 10 fps using the `libopenh264` encoder. The output container is MP4.
4. The output file is placed in `user://exports/`, the temporary PNGs are cleaned up, and an **Open Folder** action reveals the file in the OS file manager.

While capturing, the OS window title displays per-frame progress ("AstroSwarm - Exporting 47 / 200"). The export modal returns for the ffmpeg encoding phase and the final completion state.

`user://` resolves to:

- Linux: `~/.local/share/godot/app_userdata/AstroSwarm/`
- Windows: `%APPDATA%\Godot\app_userdata\AstroSwarm\`
- macOS: `~/Library/Application Support/Godot/app_userdata/AstroSwarm/`

### Bundled ffmpeg

Static ffmpeg binaries live in `bin/<platform>/` (`linux`, `windows`, `macos`) and are preferred over a system installation on `PATH`. In an exported build the binary is copied out of the `.pck` to `user://bin/` on first use and made executable. See `bin/README.md` for sourcing, licensing notes (LGPL on Linux and Windows, GPL on macOS), and codec swap instructions.

If no bundled binary is present and `ffmpeg` is not on `PATH`, the export modal surfaces the failure and leaves the captured PNG frames in `user://export_frames/` for manual stitching.

## Player settings

Available under the home-screen **Settings** menu:

- **Display.** Fullscreen and windowed toggle.
- **Graphics.** V-Sync, max FPS cap (uncapped / 60 / 120 / 144), 2D MSAA (disabled / 2x / 4x / 8x).
- **Audio.** Output device picker, master / music / SFX bus volume sliders.

These settings apply to the running engine only and reset to defaults when the application restarts.

## Building from source

The project targets Godot 4.7. Clone the repository, open `project.godot` in the editor, and use **Project -> Export** to produce a build for Linux, Windows, or macOS.

To include the bundled ffmpeg binaries in an exported build, add the following pattern to the export preset's non-resource filter:

```
include_filter="bin/*"
```

Without that filter the binaries are stripped from the export and the export pipeline falls back to the user's system `PATH`.