extends RefCounted

const TUTORIAL := preload("res://ui/tutorial/BlobTutorial.gd")
const TUTORIAL_LINES := preload("res://ui/tutorial/MoonTutorialLines.gd")

const SHIPYARD := "shipyard"
const GENOME := "genome"

const SHIPYARD_SCENE := "res://levels/menus/moons/UpgradeMoonScene.tscn"
const GENOME_SCENE := "res://levels/menus/moons/GenomeMoonScene.tscn"
const MOONS_SCENE := "res://levels/menus/moons/MoonsScene.tscn"

const MOONS := [
	{"id": SHIPYARD, "title": "Shipyard", "description": "Upgrade your spaceship", "scene": SHIPYARD_SCENE},
	{"id": GENOME, "title": "Genome", "description": "Create and organize your algorithms", "scene": GENOME_SCENE},
]

static func for_index(index: int) -> Dictionary:
	if index >= 0 and index < MOONS.size():
		return MOONS[index]
	return {"id": "outpost_%d" % index, "title": "Outpost Moon", "description": "Coming soon", "scene": ""}

static func is_openable(moon: Dictionary) -> bool:
	return str(moon.get("scene", "")) != ""

static func show_tutorial_once(host: Node, moon_id: String):
	var seen_flag: String = "tutorial_seen_moon_" + moon_id
	var lines: Array = TUTORIAL_LINES.for_moon(moon_id)
	if lines.is_empty() or PlayerSettings.get_flag(seen_flag):
		return
	var tutorial := TUTORIAL.new()
	tutorial.lines = lines
	tutorial.voice_dir = "res://va/moons/" + moon_id
	tutorial.show_visuals = false
	tutorial.final_hint = "CLICK TO CLOSE"
	tutorial.finished.connect(func(): PlayerSettings.set_flag(seen_flag, true))
	host.add_child(tutorial)
