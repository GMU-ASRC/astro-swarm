extends RefCounted

const HOLD_PROGRAM := [
	{"type": "when_always", "params": {}, "children": [
		{"type": "do_stop", "params": {}},
	]},
]

const PATROL_PROGRAM := [
	{"type": "when_always", "params": {}, "children": [
		{"type": "do_forward", "params": {}},
		{"type": "do_turn_left", "params": {"value": 30.0}},
	]},
]

const CHASE_PROGRAM := [
	{"type": "when_always", "params": {}, "children": [
		{"type": "do_forward", "params": {}},
		{"type": "do_turn_left", "params": {"value": 30.0}},
	]},
	{"type": "when_sees_enemy", "params": {}, "children": [
		{"type": "do_face", "params": {}},
		{"type": "do_forward", "params": {}},
	]},
]

const MILL_PROGRAM := [
	{"type": "when_start", "params": {}, "children": [
		{"type": "set_speed", "params": {"value": 3.5}},
		{"type": "set_fov", "params": {"value": 60.0}},
		{"type": "set_view", "params": {"value": 6.0}},
	]},
	{"type": "when_always", "params": {}, "children": [
		{"type": "do_forward", "params": {}},
		{"type": "do_turn_left", "params": {"value": 60.0}},
	]},
	{"type": "when_sees_ally", "params": {}, "children": [
		{"type": "do_turn_right", "params": {"value": 60.0}},
	]},
]

const LESSONS := [
	{
		"title": "WELCOME TO TRAINING",
		"text": "Dr. Blob here, Commander. Before you defend anything for real, I will walk you through how this place works: the planet, the evaders, your defenders, how they sense the world, how you program them, and what a mill is. Press NEXT whenever you are ready.",
		"demo": "planet",
	},
	{
		"title": "THE PLANET AND THE EVADERS",
		"text": "The planet in the middle is what you protect. Red ships are evaders. They know one thing: drive straight at the planet and never stop. Any evader that reaches the planet is a point against you.",
		"demo": "planet",
	},
	{
		"title": "YOUR DEFENDERS",
		"text": "Blue ships are your defenders. You do not fly them. Every defender runs the same program, which you build out of blocks in the workspace. Here three defenders run a simple patrol: move forward and keep turning left.",
		"demo": "patrol",
		"program": "patrol",
	},
	{
		"title": "BINARY SENSORS",
		"text": "Each defender has one sensor: the cone in front of it. The sensor is binary. It does not measure distance or direction. It only answers yes or no. Watch the readout in the top left: the defender turns green the moment an evader is inside its cone, and back to blue when it leaves.",
		"demo": "sensor",
	},
	{
		"title": "WHAT A SENSOR CAN TELL",
		"text": "A sensor can tell what kind of ship is in the cone, an enemy or an ally, and that is all. It cannot count them, and it cannot say where in the cone they are. Here another defender sits in the cone, so SEES ALLY stays yes, while SEES ENEMY flips only when the evader passes through.",
		"demo": "sensor_types",
	},
	{
		"title": "THE WORKSPACE",
		"text": "Programs are stacks of blocks. EVENTS such as Always or When I see an enemy start a rule. CONDITIONS such as If I see branch inside a rule. ACTIONS move the ship. CONFIG blocks set speed, turn rate, vision range and field of view. This program patrols, and charges the moment it sees an enemy.",
		"demo": "chase",
		"program": "chase",
	},
	{
		"title": "DETECTION AND CAPTURE",
		"text": "Detection is a defender seeing an evader. Capture is a defender touching one. On Level 1 a detection is enough and the evader vanishes. On Level 2 a defender has to touch it. The readout counts both as these defenders chase down evader after evader.",
		"demo": "chase",
	},
	{
		"title": "MILLING",
		"text": "A mill is a swarm that settles into a circle and keeps flying around it, with nobody in charge. It comes from one simple rule on a binary sensor: keep moving forward and turning left, but turn right for as long as I see an ally. Every ship runs that rule and the circle forms on its own.",
		"demo": "mill",
		"program": "mill",
	},
	{
		"title": "MILLS AND CIRCLINESS",
		"text": "Circliness scores how good a mill is, from 0 to 1. A perfect mill holds a clean ring and every ship flies around the center rather than toward or away from it. If the swarm splits into smaller mills, each one is scored and I average them, so several tidy circles still score well.",
		"demo": "mill",
	},
	{
		"title": "YOU ARE READY",
		"text": "That is everything you need. Open the workspace to build your own program, or head straight to Level 1 and put it to work. You can come back to training from the level list at any time. Good luck, Commander.",
		"demo": "mill",
		"finish": true,
	},
]

static func program(name: String) -> Array:
	match name:
		"patrol": return PATROL_PROGRAM
		"chase": return CHASE_PROGRAM
		"mill": return MILL_PROGRAM
	return HOLD_PROGRAM
