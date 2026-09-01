# AstroSwarm

[![Godot](https://img.shields.io/badge/Godot-4.6.3-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)
[![Language](https://img.shields.io/badge/language-GDScript-355570)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20windows%20%7C%20macOS-lightgrey)](#building-from-source)
[![Video Export](https://img.shields.io/badge/video%20export-FFmpeg-007808?logo=ffmpeg&logoColor=white)](https://ffmpeg.org/)
[![Status](https://img.shields.io/badge/status-in%20development-orange)](#)
[![Version](https://img.shields.io/badge/version-v0.0.8--alpha-blue)](#)

AstroSwarm is a 2D pixel-art **tower-defense game (in development)** built in Godot 4. It also includes a full **swarm-behavior simulator** sandbox: design species, program their behavior with a drag-and-drop block editor, then record, replay, and export sessions to video. The pixel-art game shell is themed separately from the simulator.

## Features

- **Player base & progression.** A procedurally generated home planet, moons that orbit it and unlock as you level up, an XP bar, and AstroCoin currency — all saved to a local profile.
- **Timed Local battles.** Deploy a squad from your base to destroy the swarm guarding a central star, then program your ship's flight logic in the Workspace Moon's block editor.
- **Benchmarked levels.** Seven FARP levels: program the defenders for levels 1 to 5 and have your algorithm graded headlessly by the evaluation service, or fly the evader yourself in level 6 against the best algorithm other players have submitted. Every entry is published to the companion website and browsable in-game from My Entries.
- **Visual block editor.** Build per-species behavior by stacking condition and action blocks — no coding required.
- **Custom species.** Tune speed, turn rate, vision range, and field of view, or start from the Hunter, Scout, and Worker presets.
- **Resizable arena.** Simulate swarms on custom-sized maps with free camera pan and zoom, plus walls and obstacles.
- **Save, record & replay.** Save setups, record live runs, and scrub them back on an interactive timeline.
- **Take-over control.** Drive any robot mid-simulation with the keyboard or a gamepad, including a 2-player multiplayer mode.
- **Pixel-art game shell.** An animated home screen and menus themed independently from the simulator.
- **Video export.** Render recorded runs to H.264 MP4 via a bundled ffmpeg binary, with one-click reveal in the file manager.

## Getting started

1. Open the project in Godot 4.6 (or newer) and press F5.
2. From the home screen, choose **Play** for your base (enter a callsign on first launch), or **Simulator** for the sandbox.
3. In the simulator, pick a species, left-drag to place robots, press **Start**, then save/replay/export from **Manage Setups**.

## Player base

Reached from **Play** — your home planet sits center-screen with unlocked moons orbiting it, over the animated starfield:

- **Home planet & moons.** A procedural Terran-Wet planet plus No-Atmosphere moons, each generated from a saved seed so they look identical every run. Moons revolve on their own random orbits, passing in front of and behind the planet.
- **Progression.** Earn XP to level up; moons unlock with level (up to 5). AstroCoin is the in-game currency. Username, level, XP, coins, and all seeds persist to a local config file.
- **First launch.** A modal asks for your callsign before you claim your planet.

The top-right buttons open **Moons**, **Shop** (currently disabled), and the ship **Workspace**; choose a game mode (**Timed Local**) and press **Find Match** to play. Online matchmaking isn't wired up yet.

## Timed Local

Deploy up to five ships (left-click + drag in your deploy zone) to wipe out the protector swarm orbiting the star before time runs out. Middle-drag to pan, scroll to zoom. Lose your whole fleet and it's game over.

**Raiders.** A squad of enemy ships defends the protectors. Rather than orbiting, they run a block program of their own: wander the arena, turn away from the star/planet and the outer rim to stay in play, and face-and-fire on any of your ships they spot — so they roam in to intercept your attack.

## Survive

A local two-player mode, picked from the game-mode dropdown next to **Levels**. Two commanders, two home planets, and one three-minute match on a **split screen** — the left half follows player 1, the right half follows player 2.

**Dr. Blob** opens every match with a click-through tutorial: he stands bottom-left with his line in a text box beside him, and an animated panel above it demonstrates each point with the real ship sprites. His script lives in `va/survive/voice.md`; drop `line_01.mp3`, `line_02.mp3`, … next to it and the tutorial plays them.

**Ready up.** After the tutorial each player presses their drive key (or gamepad **A**) to ready. When both are ready a **5-second countdown** starts; either player pressing the key again unreadies and cancels it.

- **The swarm.** 24 purple ships spawn across the map and Lévy-walk on their own. The moment one gets *any* other ship in its vision cone — a player, a blue ship, or another purple one — it turns blue. It reverts to purple after 5 seconds with nothing in sight. Nothing in the arena collides except the outer rim — ships pass straight through each other *and* through the planets — so herding is purely a matter of what they can see.
- **Blue behavior.** 3.4 m/s, 50° FOV, 4.5 m vision, always moving forward and turning left at 90°/s, turning right at 90°/s when it sees an ally — so a herd settles into a cluster and holds position. Park that cluster on your planet.
- **The waves.** No evaders for the first minute. Red evaders then spawn every 5 seconds from t=60 to t=90, cool off, and spawn again from t=120 to t=150 — 14 in total, alternating targets so **each planet gets exactly 7**. They fly straight at their target and explode on contact; each one that lands is a point against that player.
- **Defense.** A blue ship that sees an evader destroys it with a laser at 100% accuracy and self-destructs in the same instant. One blue for one red, which is why the swarm is stocked 10 ships deeper than the evader count.
- **Stealing.** Nothing anchors a blue ship to the base it was herded to — fly into your rival's base and herd their defenders away.
- **Freeze.** Two charges each for the whole match (`Q` for player 1, `/` for player 2, or the right shoulder button); a charge locks the rival's ship for 15 seconds. The remaining charges show as snowflake pips down the outer edge of each player's half, and a **FROZEN** countdown appears there while a freeze is running.
- **Winning.** Fewest evaders on your planet when the clock runs out. Equal counts is a tie.

**Controls.** Player 1 flies the gold ship on `WASD`, player 2 the green ship on the arrow keys. Controllers are never picked up automatically — press **A** on a pad and it attaches to the next free player slot, so only the pads you actually want are used no matter how many are plugged in. **B** detaches it again, and a pad that disconnects releases its slot. Each player's readout shows which device is driving them, `[ KEYBOARD ]` or `[ GAMEPAD ]` with the pad's name.

**Research data.** Each player's APM (actions per minute) is sampled every 5 seconds across the match — this runs in the background and is never mentioned in the tutorial. The end-of-match screen announces the winner over a full stat table (evaders through, defenders left, ships herded, freezes used, actions, average and peak APM), and the same report is uploaded and published on the companion website under **Survive**.

## Levels

The **Levels** screen lists seven FARP levels. All of them defend (or attack) the same central planet, and all of them measure the same three events:

| Event | Definition |
|---|---|
| **Detected** | The first time any defender sees the evader inside its vision cone. |
| **Captured** | The first time any defender physically touches (collides with) the evader. |
| **Goal time** | The time the evader reaches the center planet. |

Seeing the evader is not enough to stop it — a defender has to reach out and *touch* it.

On Levels 1 and 2 a run ends the moment either happens: a capture wins it, the evader reaching the planet loses it. Levels 3 to 5 do not stop at the first capture. They keep sending evaders and score the **share the line destroyed**, and the result reports how many got through. On Levels 4 and 5 a capture also destroys the defender that made it, so those results report the **number of defenders lost** as well.

Levels 3 and 4 play **five waves** in game, which is enough to feel out an algorithm without sitting through a four-minute run. The server does not stop at five: it keeps throwing waves until your line is spent or the simulated clock runs out, so a defense that only survives the opening will score far worse on the benchmark than it looked in game.

- **Level 1 — Defense · Place.** Drag inside the blue ring to place between one and six defenders, aiming each one's vision cone with the drag direction; right-click one to remove it. Program how they all move and scan in the **Workspace**, then press **Launch Evader**. Your layout is saved between sessions.
- **Level 2 — Defense · Ring.** Five defenders are scattered at random positions and orientations inside the ring, spaced apart so they never clump, and you cannot move them — only the algorithm decides the outcome. **Reroll** scatters them again. The layout on screen when you launch is the one the server benchmarks and the one Level 6 pilots will face, so it is saved between sessions and only **Reroll** changes it.
- **Level 3 — Defense · Waves.** Evaders arrive one at a time, **five waves** in all, each from a fresh random bearing on the red ring, with the next launching as soon as the last is resolved. The defenders are scattered as in Level 2 and **Reroll** works the same way. A defender that touches an evader destroys it and keeps hunting, so nothing is spent. The score is the share of evaders destroyed alongside how many reached the planet.
- **Level 4 — Defense · Attrition.** The same five waves, with one rule changed: a capture destroys the defender as well as the evader. Five defenders buy at most five kills, and every one of them thins the line that has to cover the rest of the sky. The run ends early if the last defender is gone, and the result reports the defenders lost as well as the evaders through.
- **Level 5 — Defense · Siege.** No waves. Five evaders spawn at once, spread around the **edges of the arena** rather than a ring, and all drive at the planet, so they arrive in a stagger. A capture still destroys the defender that made it. The run plays out until every evader is destroyed or has reached the planet.
- **Level 6 — Evasion · Pilot.** You fly the evader yourself against the **best Level 2 algorithm submitted by another player**, standing exactly where that player placed their defenders; their name is shown in the top bar. (With no entries on the server yet, you face a house algorithm on a fixed ring.) Drag on the red ring to pick your start point, then drive with the movement keys from your **Settings** (WASD or the arrow keys by default). A **three-minute countdown** runs in the top right. Reaching the planet wins; reaching it *without ever being seen* is a **clean run**, and reaching the planet is worth a large XP payout.
- **Level 7 — Swarm · Merge.** Two milling swarms and one player-flown leader. Merge the groups, walk the merged mill onto the planet, then leave and let it hold together without you.

Each level has a **? Guide** button with a step-by-step walkthrough and a list of hints, and it opens automatically the first time you play that level.

### Level shortcuts

| Key | Action |
|---|---|
| `S` | Start the run |
| `P` | Replay — reset and try again |
| `R` | Reroll the defender scatter (Levels 2 to 5) |

They are inert while a run is in progress, since Level 6 steers the evader with the same keys.

A Level 1 or Level 2 entry uploads your algorithm and placements, and the evaluation service benchmarks them headlessly: the placement runs grade the layout you submitted against many enemy approach angles, then a ring-sweep measures detection and capture rates against defender count. A Level 3, 4 or 5 entry is benchmarked as an assault instead: 100 trials, each with its own defender scatter and spawn bearings, each run far past the five waves the level plays — until the defenders are spent or the clock stops — followed by a sweep that grows the defender count until the algorithm holds cleanly. A Level 6 or Level 7 entry uploads the **recorded flight itself** — every defender and evader movement — which the server renders into a watchable replay rather than re-simulating.

Only the current game version may submit. The server rejects an older build with a clear message rather than filing its entry, because level ids have moved between releases and an old client would file its run under the wrong level.

**My Entries** lists every entry you've submitted across all seven levels, each with a **Claim XP** button right in the list — it reads *Pending* until the server finishes processing the entry, and shows the amount once claimed. **View** opens an info screen pulled live from the server: capture and detection rates plus the outcome breakdown for a benchmarked level, or the result and the detected / captured / reached-planet times for a piloted run. XP is awarded from your best result on a level, so re-claiming a worse entry pays nothing; reaching the planet in level 6 is worth far more than a benchmark run.

## Controls

- **Place robots / deploy ships** — left-click + drag (Place Robots tool in the simulator, or inside the deploy zone in Timed Local); the drag direction sets the facing.
- **Robot menu** — right-click a robot to take over, release, remove, toggle its trail, or pin its coordinates.
- **Camera** — middle-mouse drag to pan, scroll wheel to zoom.
- **Drive a taken-over robot** — WASD / arrow keys, or a gamepad's left stick.

## Block reference

Behavior is built from four block types:

- **Config** — set a physical parameter (speed, turn rate, vision range, FOV, size).
- **Condition** — start a rule (On start; Always; When I see anyone / nobody; When I touch or see a wall). The simulator adds *When I see / don't see a [species]*; the ship workspace instead adds *When I see an enemy / ally*.
- **Logic** — branch inside a rule (If I see anyone / an enemy / an ally / an object / a wall / a [species]; If target within / beyond a distance; Else).
- **Action** — run while the condition holds (move, stop, random walk, turn, face target, flee, throttle, and — in the ship workspace — fire).

Actions placed before any condition run under `Always`. **Random walk** steers on a Lévy-flight pattern: mostly short hops with the occasional long straight run. For branching, place an **Else** block directly after its **If** at the same level — the `Else` runs when that `If`'s condition was false.

The FARP ship workspace shares the simulator's block set (minus the variable blocks): it swaps the species conditions for **enemy/ally** detection, and hides the **Fire**, **Throttle**, and **Set size** blocks, since a FARP defender stops the evader by intercepting it rather than shooting it. Sliders also accept keyboard arrow keys once focused.

## Default species

| Species | Speed | Turn rate | Vision | FOV | Default behavior |
|---|---|---|---|---|---|
| Hunter | 5.25 m/s | 3.0 rad/s | 5.5 m | 55° | Face anyone it sees |
| Scout | 3.75 m/s | 2.0 rad/s | 4.5 m | 110° | Random walk |
| Worker | 2.4 m/s | 1.4 rad/s | 3.25 m | 180° | Flee anyone it sees |

All move forward by default; add your own species with the **+** button.

## Recording and replay

Starting a run records every robot's position and rotation in the background; on **Stop** or **Clear** it's saved as a `.run` file. Load one from **Manage Setups** to scrub it back and forth on an interactive timeline.

## Take-over mode

Right-click a robot and choose **Take Over** to drive it manually. Control is keyboard-based by default; enable **Controller Mode** (and **Multiplayer** for two controllers) in **Arena Settings**. Controlled robots show a **P1**/**P2** badge — press **Esc** or the gamepad's **B** to release. Stopping or clearing the arena releases all of them.

## Video export

From **Manage Setups**, **Export to Video** renders a recorded run to an H.264 MP4 through a bundled ffmpeg binary, then offers a one-click reveal of the output folder.

## Player settings

Display (window mode, resolution, with Apply buttons), graphics (V-Sync, FPS cap, anti-aliasing), rebindable keybinds, audio volumes, and a Player tab to reset your profile — all persisted between sessions.

## Building from source

The project targets Godot 4.6. Clone the repository, open `project.godot`, and use **Project -> Export** to build for Linux, Windows, or macOS. See `bin/README.md` for bundling the ffmpeg binaries used by video export.

## Benchmarking

Submitted entries are graded off-engine. The game client uploads the algorithm, the placements, and (for levels 5 and 6) the recorded flight; the `astroworker` service in the companion web repository re-implements the match loop in Go and runs the trials itself. The game no longer ships a headless benchmarker and no dedicated-server build is needed.
