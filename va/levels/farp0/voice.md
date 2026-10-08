# Dr. Blob - Level 0 Training Voice Lines

Record one audio file per line and drop it in this folder as `line_01.mp3`,
`line_02.mp3` and so on (`.wav` and `.ogg` also work). Each line is one training
lesson: the lesson panel plays the file that matches the lesson number and stays
silent for any line with no recording, so the lines can be recorded one at a time.

[Line:1]
Dr. Blob here, Commander. Before you defend anything for real, I will walk you through how this place works: the planet, the evaders, your defenders, how they sense the world, how you program them, and what a mill is. Press NEXT whenever you are ready.

[Line:2]
The planet in the middle is what you protect. Red ships are evaders. They know one thing: drive straight at the planet and never stop. Any evader that reaches the planet is a point against you.

[Line:3]
Blue ships are your defenders. You do not fly them. Every defender runs the same program, which you build out of blocks in the workspace. Here three defenders run a simple patrol: move forward and keep turning left.

[Line:4]
Each defender has one sensor: the cone in front of it. The sensor is binary. It does not measure distance or direction. It only answers yes or no. Watch the readout in the top left: the defender turns green the moment an evader is inside its cone, and back to blue when it leaves.

[Line:5]
A sensor can tell what kind of ship is in the cone, an enemy or an ally, and that is all. It cannot count them, and it cannot say where in the cone they are. Here another defender sits in the cone, so SEES ALLY stays yes, while SEES ENEMY flips only when the evader passes through.

[Line:6]
Programs are stacks of blocks. EVENTS such as Always or When I see an enemy start a rule. CONDITIONS such as If I see branch inside a rule. ACTIONS move the ship. CONFIG blocks set speed, turn rate, vision range and field of view. This program patrols, and charges the moment it sees an enemy.

[Line:7]
Detection is a defender seeing an evader. Capture is a defender touching one. On Level 1 a detection is enough and the evader vanishes. On Level 2 a defender has to touch it. The readout counts both as these defenders chase down evader after evader.

[Line:8]
A mill is a swarm that settles into a circle and keeps flying around it, with nobody in charge. It comes from one simple rule on a binary sensor: keep moving forward and turning left, but turn right for as long as I see an ally. Every ship runs that rule and the circle forms on its own.

[Line:9]
Circliness scores how good a mill is, from 0 to 1. A perfect mill holds a clean ring and every ship flies around the center rather than toward or away from it. If the swarm splits into smaller mills, each one is scored and I average them, so several tidy circles still score well.

[Line:10]
That is everything you need. Open the workspace to build your own program, or head straight to Level 1 and put it to work. You can come back to training from the level list at any time. Good luck, Commander.
