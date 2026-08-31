extends RefCounted

const WILD := [
	{"type": "when_start", "params": {}, "children": [
		{"type": "set_speed", "params": {"value": 2.4}},
		{"type": "set_fov",   "params": {"value": 140.0}},
		{"type": "set_view",  "params": {"value": 4.5}},
	]},
	{"type": "when_always", "params": {}, "children": [
		{"type": "do_random_walk", "params": {}},
	]},
]

const HERDED := [
	{"type": "when_start", "params": {}, "children": [
		{"type": "set_speed", "params": {"value": 3.4}},
		{"type": "set_fov",   "params": {"value": 50.0}},
		{"type": "set_view",  "params": {"value": 4.5}},
	]},
	{"type": "when_always", "params": {}, "children": [
		{"type": "do_forward",   "params": {}},
		{"type": "do_turn_left", "params": {"value": 90.0}},
	]},
	{"type": "when_sees_ally", "params": {}, "children": [
		{"type": "do_turn_right", "params": {"value": 90.0}},
	]},
]
