extends "res://levels/modes/ScatterBase.gd"

const EVADER_COUNT := 10
const SPAWN_INTERVAL := 3.0
const FIRST_EVADER_DELAY := 10.0
const DEFENDER_OPTIONS := [5, 25, 50, 100]
const SPACING_FILL := 0.8
const SCENE_SCALE := 1.5
const LEVEL_ARENA := ARENA * SCENE_SCALE

var _defender_count: int = DEFENDER_OPTIONS[0]
var _count_picker: OptionButton

func _level_id() -> String:
	return "farp2"

func _arena_size() -> Vector2:
	return LEVEL_ARENA

func _planet_center() -> Vector2:
	return LEVEL_ARENA * 0.5

func _level_title() -> String:
	return "LEVEL 2 - PROGRAM THE SCATTER"

func _level_subtitle() -> String:
	return "Your defenders are dropped at random inside the blue ring, facing random directions. You cannot move them - only your algorithm decides the outcome. Pick how many defenders to field, press REROLL for a new scatter, then LAUNCH."

func _setup_level():
	_defender_count = _saved_defender_count()
	_use_evader_stream(EVADER_COUNT, SPAWN_INTERVAL, FIRST_EVADER_DELAY)
	_stream.wins_by_capture = true
	super()
	_build_count_picker()

func _shows_hint_text() -> bool:
	return false

func _launch_label() -> String:
	return "LAUNCH EVADERS (S) >"

func _launch():
	_start_active()
	_stream.start()
	_phase_label.text = "EVADERS INCOMING"

func _scatter_count() -> int:
	return _defender_count

func _scatter_spacing() -> float:
	var band_area: float = PI * (SCATTER_MAX * SCATTER_MAX - PLACE_MIN * PLACE_MIN)
	return minf(SCATTER_SPACING, sqrt(band_area / float(_defender_count)) * SPACING_FILL)

func _saved_defender_count() -> int:
	var saved_size: int = PlayerData.get_level_placements(_level_id()).size()
	return saved_size if DEFENDER_OPTIONS.has(saved_size) else DEFENDER_OPTIONS[0]

func _build_count_picker():
	_count_picker = OptionButton.new()
	_count_picker.focus_mode = Control.FOCUS_NONE
	HUD_BUTTONS.apply(_count_picker, HUD_BUTTONS.Kind.NEUTRAL, 9)
	for option in DEFENDER_OPTIONS:
		_count_picker.add_item("%d DEFENDERS" % option)
	_count_picker.select(DEFENDER_OPTIONS.find(_defender_count))
	_count_picker.item_selected.connect(_on_count_selected)
	_top_bar.add_child(_count_picker)

func _on_count_selected(index: int):
	if _phase != Phase.SETUP:
		_count_picker.select(DEFENDER_OPTIONS.find(_defender_count))
		return
	_defender_count = DEFENDER_OPTIONS[index]
	_reroll_level()
