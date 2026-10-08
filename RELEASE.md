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
