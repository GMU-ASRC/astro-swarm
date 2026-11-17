extends VBoxContainer

const RANKS := preload("res://progression/Ranks.gd")

const DEFAULT_AMOUNT := 100
const MAX_AMOUNT := 100000
const AMOUNT_STEP := 10

var _amount_box: SpinBox
var _status_label: Label

func _ready():
	add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Give XP"

	_amount_box = SpinBox.new()
	_amount_box.min_value = 1
	_amount_box.max_value = MAX_AMOUNT
	_amount_box.step = AMOUNT_STEP
	_amount_box.value = DEFAULT_AMOUNT
	_amount_box.suffix = "XP"
	_amount_box.custom_minimum_size = Vector2(180, 0)
	_amount_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var give_button := Button.new()
	give_button.text = " Give XP "
	give_button.focus_mode = Control.FOCUS_NONE
	give_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	give_button.pressed.connect(_give_xp)

	var amount_row := HBoxContainer.new()
	amount_row.add_theme_constant_override("separation", 8)
	amount_row.add_child(_amount_box)
	amount_row.add_child(give_button)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.52, 0.62, 1))

	for node in [title, amount_row, _status_label]:
		add_child(node)

	PlayerData.xp_changed.connect(_on_xp_changed)
	_refresh_status()

func _on_xp_changed(_current: int, _needed: int):
	_refresh_status()

func _give_xp():
	PlayerData.add_xp(int(_amount_box.value))

func _refresh_status():
	_status_label.text = "%s, %d / %d XP to %s." % [
		RANKS.rank_name(PlayerData.level),
		PlayerData.xp,
		PlayerData.xp_needed(),
		RANKS.next_rank_name(PlayerData.level),
	]
