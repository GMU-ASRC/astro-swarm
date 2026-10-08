extends CanvasLayer

signal step_changed(index: int)

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const HUD_BUTTONS := preload("res://ui/hud/HudButtons.gd")
const BLOB_PATH := "res://assets/sprites/dr_blob/dr_blob.png"

const BOX_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const BOX_BORDER := Color(0.09, 0.09, 0.14, 1.0)
const BOX_TEXT := Color(0.05, 0.05, 0.08, 1.0)
const TITLE_COLOR := Color(0.176, 0.298, 0.62, 1.0)
const HINT_COLOR := Color(0.35, 0.35, 0.42, 1.0)
const BLOB_SIZE := 260.0
const BOX_MARGIN := 24.0

var lessons: Array = []
var voice_dir: String = ""

var _index: int = 0
var _title: Label
var _body: Label
var _counter: Label
var _extra: VBoxContainer
var _back_button: Button
var _next_button: Button
var _voice: AudioStreamPlayer

func _ready():
	layer = 20
	_voice = AudioStreamPlayer.new()
	_voice.bus = "SFX"
	add_child(_voice)
	_build()

func show_step(index: int):
	_index = clampi(index, 0, lessons.size() - 1)
	var lesson: Dictionary = lessons[_index]
	_title.text = str(lesson.get("title", ""))
	_body.text = str(lesson.get("text", ""))
	_counter.text = "%d / %d" % [_index + 1, lessons.size()]
	_back_button.disabled = _index == 0
	_next_button.visible = _index < lessons.size() - 1
	for child in _extra.get_children():
		child.queue_free()
	_play_voice(_index + 1)
	step_changed.emit(_index)

func extra_area() -> VBoxContainer:
	return _extra

func current_index() -> int:
	return _index

func _build():
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var blob := TextureRect.new()
	blob.texture = load(BLOB_PATH)
	blob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blob.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	blob.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blob.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	blob.offset_left = BOX_MARGIN
	blob.offset_top = -BLOB_SIZE - BOX_MARGIN
	blob.offset_right = BOX_MARGIN + BLOB_SIZE
	blob.offset_bottom = -BOX_MARGIN
	root.add_child(blob)

	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_left = BOX_MARGIN * 2.0 + BLOB_SIZE
	box.offset_right = -BOX_MARGIN
	box.offset_top = -BOX_MARGIN
	box.offset_bottom = -BOX_MARGIN
	box.add_theme_stylebox_override("panel", _box_style())
	root.add_child(box)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	box.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	header.add_child(_label(13, BOX_TEXT, "DR. BLOB"))
	_title = _label(13, TITLE_COLOR)
	header.add_child(_title)

	_body = _label(15, BOX_TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_body)

	_extra = VBoxContainer.new()
	_extra.add_theme_constant_override("separation", 6)
	column.add_child(_extra)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)
	_counter = _label(10, HINT_COLOR)
	_counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_counter)
	_back_button = HUD_BUTTONS.make("< BACK", HUD_BUTTONS.Kind.NEUTRAL, 10)
	_back_button.pressed.connect(func(): show_step(_index - 1))
	footer.add_child(_back_button)
	_next_button = HUD_BUTTONS.make("NEXT >", HUD_BUTTONS.Kind.PRIMARY, 10)
	_next_button.pressed.connect(func(): show_step(_index + 1))
	footer.add_child(_next_button)

func _play_voice(line_id: int):
	_voice.stop()
	if voice_dir == "":
		return
	for extension in [".mp3", ".wav", ".ogg"]:
		var path: String = "%s/line_%02d%s" % [voice_dir, line_id, extension]
		if ResourceLoader.exists(path):
			_voice.stream = load(path)
			_voice.play()
			return

func _label(font_size: int, color: Color, text: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _box_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BOX_COLOR
	style.border_color = BOX_BORDER
	style.set_border_width_all(4)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(22)
	return style
