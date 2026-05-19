# AstroSwarm

A visual swarm-behavior simulator built in **Godot 4**. Design species with unique traits, program their behavior using Scratch-style code blocks, place them in a dynamically resizable arena, record/replay simulation runs, and watch emergent behavior unfold.

---

## Quick Start

1. Open in Godot 4 and run (F5). You will land on the **Home Screen**.
2. Click **Play** and select a game mode to enter the **Arena**.
3. **Select a species** in the sidebar (Hunter, Scout, Worker, or create your own).
4. **Right-click + drag** in the arena to place a bot (an arrow preview sets placement facing/rotation).
5. Click **▶ Start** in the top-right to begin the simulation.
6. Use the **×1 / ×2 / ×3** buttons to scale the speed of time, or press **⏹ Stop** to reset all bots to their initial starting positions.
7. Click **💾 Manage Setups** in the sidebar to save your layout or load/delete recorded runs.

---

## Home Screen & Core Navigation

When launching AstroSwarm, you are greeted by the modern, premium main menu:
- **Play**: Navigates to the Game Mode selection scene (Space Minnows, Challenges, back button).
- **Settings**: Opens a player graphics/audio configuration scene.
- **Quit**: Exits the game cleanly (runs cleanly on Linux).

### Player Settings Scene
- **Display**: Switch between *Fullscreen* and *Windowed* mode.
- **Graphics**: 
  - Toggle *V-Sync* to eliminate screen tearing.
  - Set a *Max FPS* limit (Uncapped, 60, 120, 144) to control GPU usage.
  - Set *Anti-Aliasing (MSAA 2D)* (Disabled, 2x, 4x, 8x) for smoother rendering.
  - **Decoupled Physics & Framerate**: The simulation speed depends strictly on the Time Controls GUI scale and simulation delta time. Frame rendering rate limits (such as 60 FPS or 144 FPS) do not affect physics update cycles or simulation accuracy.
- **Audio Output & Volume**: 
  - Adjust the *Master Volume* slider.
  - Adjust the *Music Volume* and *Sound Effects (SFX) Volume* sliders. The volume maps dynamically to dedicated audio buses for future game music and SFX integration.

---

## Dynamic Arena & Camera Controls

The AstroSwarm simulator decouples physics boundaries from screen sizes to let you simulate swarms on large, custom-sized maps.

### Dynamic Arena Resizing
- Access global simulation settings to tweak **Arena Width** and **Arena Height** dimensions dynamically (ranging from 10m up to 100m).
- **Fit to Window**: A dynamic button instantly scales your current Arena dimensions to perfectly fit the aspect ratio of the active game window.
- **Dynamic Physics Clamping**: Robots are collision-clamped to these exact physical limits rather than the screen size, preventing invisible wall bugs.
- **Arena Boundaries**: The physical borders of your custom-sized arena are highlighted by a bold, bright-red boundary wall.

### Custom 2D Camera Navigation
- **Middle-Mouse Drag**: Pan around the physical arena space seamlessly.
- **Mouse Scroll Wheel**: Zoom in and out.
- **Adaptive Grid Rendering**: Grid lines automatically recalculate their drawing weight (`max(1.0, 1.0 / zoom)`) to stay crisp and visible under heavy zoom states. The red boundary border dynamically adjusts its thickness similarly.

---

## Interactive Simulation Controls

### Placement Drag Arrow
When placing a bot in the arena (**Right-click + drag**), the line preview renders as a procedural, styled arrowhead pointing in the exact direction the robot will face on spawning. The arrowhead dynamically shrinks or expands based on your drag length to prevent UI crowding.

### Unique Robot Names
Every robot placed in the simulator is dynamically assigned a unique human name pulled from a collection of **100 common boy and girl names** (e.g. Liam, Emma, Mateo, Ava).
- **Radial Menu**: Left-click on any paused robot in the arena to pull up the Radial Menu. Its custom name will be proudly displayed in bold white text directly at the center of the radial menu, adding character to your swarm!

---

## File & Run Manager Scene

Clicking **Manage Setups** in the simulator sidebar transitions you into a dedicated, clean, dual-column management interface.

### Column 1: Saved Setups (Configurations)
- Manage layout configurations (species traits, block behaviors, robot starting positions).
- Input a custom setup name in the **LineEdit** input box. The input box uses high-contrast dark placeholder text so it remains clearly visible against white backgrounds.
- Saving automatically appends a `.save` file format.
- Click **Save Current**, **Load Selected Setup**, or **Delete** setups. Files are securely isolated within the dedicated `user://saves/` directory.

### Column 2: Saved Runs (Replay System)
- When starting a simulation, the engine records the coordinates and orientations of all active robots every 100ms in the background.
- Upon stopping or clearing the simulation, the sequence is saved as a timestamped `.run` file within the `user://runs/` directory.
- Select a run and click **Load Selected Run** to boot the Simulator into a dedicated **Replay Mode**.
- **Interactive Timeline Scrubbing**: Replay mode hides placement and species widgets, and turns the top bar count label into a long **HSlider Timeline**. You can scrub backwards and forwards through the entire run seamlessly like an interactive video playback.
- **Export to Video**: Selecting a run and clicking **🎬 Export to Video** loads the Simulator in headless export mode. The arena renders each recorded frame, captures the viewport to a PNG sequence, then stitches the frames into a standard **H.264 mp4** via a bundled `ffmpeg` binary. A progress modal reports capture percentage and encoding status; on completion an **Open Folder** button reveals the saved file at `~/.local/share/godot/app_userdata/AstroSwarm/exports/replay_TIMESTAMP.mp4`. Output is 10 FPS (matching the recording interval) and plays in browsers, Discord, QuickTime, VLC, and any modern video player.

---

## Core Concepts & Block Coding

### Species
Each species is an independent bot type with its own color, physical stats, and a behavior stack of visual code blocks.

| Species | Speed | Turn Rate | Vision | FOV | Default Behavior |
|---------|-------|-----------|--------|-----|------------------|
| **Hunter** | 5.25 m/s | 3.0 rad/s | 5.5 m | 55° | See agent → face it; always move forward |
| **Scout** | 3.75 m/s | 2.0 rad/s | 4.5 m | 110° | Always wander + move forward |
| **Worker** | 2.4 m/s | 1.4 rad/s | 3.25 m | 180° | See agent → flee; always move forward |

### Block Categories
- 🟢 **Config Blocks** (Green): Slider parameters controlling physics variables.
- 🟣 **Condition Blocks** (Purple): Triggers rules (e.g., *Always*, *When I see anyone*, *When I touch a wall*).
- 🔵 **Action Blocks** (Blue): Defines behavior outputs (e.g., *Move forward*, *Wander randomly*, *Turn left*, *Face target*).

---

## Project Structure

```
astro-swarm/
├── project.godot                    # Godot project config (stretch disabled, stretch aspect)
├── autoloads/
│   ├── SimulationManager.gd         # Central state, setup/run serializer, names list, export flags
│   └── GameManager.gd               # Scene navigation helper
├── entities/
│   └── robot/
│       ├── Robot.gd                  # Position clamping, unique names, color rendering
│       ├── Robot.tscn                # Robot node (CharacterBody2D + VisionCone + Interpreter)
│       ├── Sensor.gd                 # Vision cone (Area2D), target tracking
│       └── Interpreter.gd           # Rule engine evaluator
├── levels/
│   ├── Arena.gd                     # Main scene + frame-by-frame export pipeline (_run_video_export)
│   ├── Arena.tscn                   # Scene tree (walls, sidebar, topbar, drag indicator)
│   ├── DragIndicator.gd             # Custom drag arrow renderer
│   ├── DragIndicator.tscn           # Node2D instance with DragIndicator script
│   └── SaveManagerScene.gd/.tscn    # Setup / Run manager interface
├── ui/
│   ├── MainTheme.tres               # Global CSS styling system overrides
│   ├── hud/
│   │   ├── Sidebar.gd/.tscn         # Species palette, Settings/Manage Setups scene navigation
│   │   └── TopBar.gd/.tscn          # Timer, interactive HSlider, speed scales, Play/Stop
│   ├── workspace/
│   │   ├── Workspace.gd/.tscn       # Block coding editor
│   │   └── ScratchBlock.gd/.tscn    # Individual visual block widget
│   └── modal/
│       ├── SettingsModal.gd/.tscn   # Simulation bounds settings modal
│       └── ExportProgressModal.gd   # Code-built overlay for export (progress, status, Open Folder, Done)
├── bin/                             # Bundled ffmpeg binaries (one per target platform)
│   ├── linux/ffmpeg                 # BtbN LGPL build
│   ├── windows/ffmpeg.exe           # BtbN LGPL build
│   ├── macos/ffmpeg                 # evermeet.cx build
│   └── README.md                    # ffmpeg sourcing, licensing, codec swap notes
└── assets/                          # Font & game asset directory
```

---

## Technical Notes

- **OS Location for Saves**: Setup and replay files are saved securely under your local system path at `~/.local/share/godot/app_userdata/AstroSwarm/`. Subfolders: `saves/` (`.save` setup files), `runs/` (`.run` recordings), and `exports/` (rendered `.mp4` videos).
- **Navigation Safety**: Scenes explicitly unpause the scene tree upon loading, avoiding stuck UI button interactions.
- **Rendering Optimization**: Interactive timeline scrubbing operates under `is_replaying` flags in `Robot.gd`, skipping CPU-intensive physics calculations to ensure smooth scrubbing.
- **Video Export Pipeline**: `Arena._run_video_export()` steps through the replay frame-by-frame, awaiting `RenderingServer.frame_post_draw` per step to capture the viewport as a PNG, then invokes `ffmpeg -c:v libopenh264 -pix_fmt yuv420p` against a bundled binary in `bin/<platform>/`. The lookup (`_resolve_ffmpeg`) prefers the bundled binary over the system `PATH`; in exported builds it extracts the binary from the `.pck` to `user://bin/` on first use and `chmod +x`'s it on Linux/macOS. Output is a standard H.264 mp4 written to `user://exports/`. Codec choice (libopenh264 over libx264) keeps the pipeline compatible with both LGPL and GPL ffmpeg builds — see `bin/README.md` for sourcing and licensing details.