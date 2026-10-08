extends Control

signal retry_requested
signal next_requested
signal levels_requested

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const HUD_BUTTONS := preload("res://ui/hud/HudButtons.gd")

const PASS_COLOR := Color(0.40, 0.85, 0.45, 1.0)
const FAIL_COLOR := Color(1.0, 0.42, 0.32, 1.0)
const ACCENT_COLOR := Color(0.451, 0.616, 1.0, 1.0)
const TEXT_COLOR := Color(0.93, 0.94, 1.0, 1.0)
const DIM_COLOR := Color(0.6, 0.62, 0.74, 1.0)
const NOTE_COLOR := Color(1.0, 0.70, 0.20, 1.0)
const CARD_COLOR := Color(0.129, 0.122, 0.196, 1.0)
const CARD_EDGE := Color(0.318, 0.306, 0.463, 1.0)
const ROW_COLOR := Color(0.16, 0.149, 0.243, 1.0)
const ROW_ALT_COLOR := Color(0.18, 0.171, 0.275, 1.0)
const BACKDROP_COLOR := Color(0, 0, 0, 0.6)

const CARD_WIDTH := 520.0
const POP_SECONDS := 0.18

var _card: PanelContainer
var _status_label: Label
var _title_label: Label
var _headline_label: Label
var _stats_box: VBoxContainer
var _note_label: Label
var _button_row: HBoxContainer

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()

func show_result(passed: bool, status: String, title: String, headline: String, stats: Array, has_next: bool):
	_status_label.text = status
	_title_label.text = title
	_title_label.add_theme_color_override("font_color", PASS_COLOR if passed else FAIL_COLOR)
	_headline_label.text = headline
	_fill_stats(stats)
	_note_label.text = ""
	_note_label.visible = false
	_fill_buttons(passed, has_next)
	visible = true
	_pop_in()

func add_note(text: String):
	_note_label.text = text if _note_label.text == "" else _note_label.text + "\n" + text
	_note_label.visible = true

func _build():
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOR
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_card.add_theme_stylebox_override("panel", _card_style())
	center.add_child(_card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_card.add_child(content)

	_status_label = _label("", 10, ACCENT_COLOR)
	content.add_child(_status_label)

	_title_label = _label("", 26, TEXT_COLOR)
	content.add_child(_title_label)

	_headline_label = _label("", 12, TEXT_COLOR)
	_headline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_headline_label)

	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 2)
	content.add_child(_stats_box)

	_note_label = _label("", 10, NOTE_COLOR)
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_label.visible = false
	content.add_child(_note_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	content.add_child(spacer)

	_button_row = HBoxContainer.new()
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row.add_theme_constant_override("separation", 12)
	content.add_child(_button_row)

func _fill_stats(stats: Array):
	for child in _stats_box.get_children():
		child.queue_free()
	_stats_box.visible = not stats.is_empty()
	for i in stats.size():
		_stats_box.add_child(_stat_row(str(stats[i][0]), str(stats[i][1]), i % 2 == 1))

func _stat_row(caption: String, value: String, alternate: bool) -> PanelContainer:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ROW_ALT_COLOR if alternate else ROW_COLOR
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	row.add_child(line)
	var caption_label := _label(caption.to_upper(), 10, DIM_COLOR)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(caption_label)
	var value_label := _label(value, 10, TEXT_COLOR)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(value_label)
	return row

func _fill_buttons(passed: bool, has_next: bool):
	for child in _button_row.get_children():
		child.queue_free()
	if has_next and passed:
		_add_button("NEXT LEVEL >", HUD_BUTTONS.Kind.PRIMARY, next_requested)
		_add_button("TRY AGAIN", HUD_BUTTONS.Kind.NEUTRAL, retry_requested)
	else:
		_add_button("TRY AGAIN", HUD_BUTTONS.Kind.PRIMARY, retry_requested)
		if has_next:
			_add_button("NEXT LEVEL >", HUD_BUTTONS.Kind.NEUTRAL, next_requested)
	_add_button("LEVELS", HUD_BUTTONS.Kind.NEUTRAL, levels_requested)

func _add_button(text: String, kind: int, pressed_signal: Signal):
	var button := HUD_BUTTONS.make(text, kind, 11)
	button.pressed.connect(func(): pressed_signal.emit())
	_button_row.add_child(button)

func _pop_in():
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.92, 0.92)
	_card.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_card, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "modulate:a", 1.0, POP_SECONDS)

func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLOR
	style.border_color = CARD_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 24
	return style

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
