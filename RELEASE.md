# 0.0.9

## Updates

- Level 2 sends two evaders per defender, `E = 2 * D`, one every `15 / D` seconds after the head start, so the stream lasts about 30 seconds at any line size
- Level 3 plays two waves of one evader per defender at once, `E = 2 * D`, with a defender picker of 5, 25, 50, 100, 250 or 500
- Level 2 offers 250 and 500 defenders
- Removed the bottom-left hint text and the tutorial button from every level
- Restyled the entries screens to match the website entry page, with links to open each entry and your profile on the website
- Hid the pilot level from the Levels screen and moved every level after it down one: Swarm is now Level 6 and Supply Level 7. Saves, progress and tutorial flags move to the new ids on first launch
- Level 5 gets the same 5, 10, 15 or 20 defender picker as Level 4
- Level 6 (Swarm) passes once the two swarms hold merged for a second, even if the mill never reaches the planet, and its agents see wider but not as far
- Level 7 (Supply) lets you pick 10 or 25 defenders, with half as many evaders per planet, and attrition is on, so a capture takes the defender too
- The Level 7 jump gate is now the right edge of planet A and the left edge of planet B. The shuttle crosses instantly, and a defender that drifts in arrives about 2.5 seconds later
- Calling a defender across with E now waits out the same 2.5 second crossing before it appears
- The supply deployment window is 30 seconds
- Supply planets are attacked all at once: evaders arrive one at a time onto a random planet, and every planet keeps fighting live while you are on another one. The gates stay open and E keeps working through the assault
- The supply shuttle no longer draws a vision cone
- The evader spawn box is no longer drawn on the supply levels
- The planet board sits fully on screen on the supply levels
- The demo mode is only listed in dev mode
- Updated the Dr. Blob voice lines for Levels 1, 4, 5, 6 and 7

## Additions

- A Credits tab in the settings, with a link to the website
- A backend server URL setting in dev mode
- The Genome moon, where every algorithm is a genome you can create, copy, rename, delete and make active, with a genome switcher and Save as New in the workspace
- Switching genomes during a level, 3 switches per run, with a Level Switches upgrade in the Genome moon that adds up to 5 more. A mid-run switch needs a 5 second cooldown and a defender lost since the last switch, and recolors the defenders
- Entries upload their genome schedule, each genome with the defender count it took over at
- Eight new achievements for genomes, switching, moons and upgrades
- Entries pay AstroCoin as well as XP when claimed, up to 5 paid entries per level per day
- The Genome moon unlocks at commander level 4 or on completing Level 4, whichever comes first
- A reveal screen for each newly unlocked moon that takes you straight to it, and a Dr. Blob tutorial the first time each moon is opened
- Level 8 - Triad: the supply level across three planets, with planet A as the hub (right edge to planet B, bottom edge to planet C), a 10, 25 or 50 defender picker and a third of the line in evaders per planet
- Jump gate edge art for the supply levels
- Sur2, a dev-only one-minute Survive cut for recording video: no tutorial, power-ups or upload, blue ships run each player's genome and capture by touch, each player's genome flies the evaders sent at the rival, and the left and right edges are jump gates

## Fixes

- Fixed typing a value below a block's slider minimum snapping it back up; typed values now only stop at zero and the maximum

# 0.0.8

## Updates

- Renumbered the levels again: the wave levels took slots 3 and 4, a siege level took 5, and the pilot and swarm levels moved up to 6 and 7 (478510a)
- Rebuilt the level scenes on shared bases, so waves, scatters and assaults are written once and each level only says what it changes (478510a)
- Capped the wave levels at five waves in game, while the benchmark keeps sending them until the line is spent or the clock stops (5b8c7d8)
- Played every wave out before ending a run, rather than stopping on the first breach (d810ea4)
- Ran both wave phases with the arena reset between them (4c37016)
- Dropped the submit button and the automatic submission copy now that every finished run uploads on its own (99a232f)
- Listed the levels one per row on the Levels screen (4d7c49e)
- Generated each moon from its own seed, so terrain, palette and spin are all distinct (4d7c49e)
- Moved the voice line folders onto the new level numbering (7dac01f)
- Replaced the old video upload with a simulator entry upload and removed the run uploader it used (4d82475)
- Refreshed the readme for the new levels, the spawn zones and the upload (7dac01f, e4952d4, 4d82475, 4d7c49e)
- Bumped the version to 0.0.8 (1f0b8b4)

## Additions

- Level 3 - Defense · Waves, where evaders arrive one at a time from fresh bearings and the score is the share the line destroys (478510a)
- Level 4 - Defense · Attrition, where a capture also destroys the defender that made it, so five defenders buy at most five kills (478510a)
- Level 5 - Defense · Siege, where five evaders spawn together around the arena edges and arrive in a stagger (478510a)
- Level 7 - Swarm · Merge, where you fly a leader that two milling swarms read as one of their own, merge them, and walk the mill onto the planet (478510a)
- Level 8 - Supply · Allocation: two planets on two seeds, ten defenders that all start on planet A, and a deployment window where the shuttle calls them across a jump gate before both assaults play out in turn (4d7c49e)
- A planet board that tracks both Level 8 planets at once, a pip per evader, so the fight you are not standing on stays readable (4d7c49e)
- Spawn zones in the simulator: draw a zone for a species, then drive it from the new Arena program tab in the block editor (4d82475)
- An Every [N] seconds event block, in both the simulator and the arena program (4d82475)
- Simulator entry upload: send a recorded run to the website with a title and a description, and it is published with the recording and every species' logic (4d82475, dc31737)
- A demo mode with its own ships, lasers and HUD (c425a01)
- Dr. Blob voice lines for the swarm and supply levels (478510a, 4d7c49e)

## Fixes

- Fixed a level refusing to submit a second entry after a restart (16fb2f5)
- Fixed the simulator upload dialog growing past the bottom of the screen (dc31737)
