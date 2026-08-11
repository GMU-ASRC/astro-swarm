extends CanvasLayer

signal finished

const FONT_REG := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const STAGE := preload("res://ui/tutorial/TutorialStage.gd")
const BLOB_PATH := "res://assets/sprites/dr_blob/dr_blob.png"

const BLOB_SIZE := 260.0
const BOX_MARGIN := 24.0
const STAGE_HEIGHT := 230.0
const C_BOX_BG := Color(1.0, 1.0, 1.0, 1.0)
const C_BOX_BORDER := Color(0.09, 0.09, 0.14, 1.0)
const C_BOX_TEXT := Color(0.05, 0.05, 0.08, 1.0)
const C_HINT := Color(0.35, 0.35, 0.42, 1.0)
const C_STAGE_BG := Color(0.05, 0.05, 0.09, 0.94)

var lines: Array = []
var voice_dir: String = "res://va/survive"
var show_visuals: bool = true
var final_hint: String = "CLICK TO READY UP"

var _index: int = -1
var _root: Control
var _stage
var _text_label: Label
var _hint_label: Label
var _voice: AudioStreamPlayer

func _ready():
	layer = 40
	_build()
	_advance()

func _build():
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	_root.add_child(dim)

	var blob := TextureRect.new()
	blob.texture = load(BLOB_PATH)
	blob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blob.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	blob.custom_minimum_size = Vector2(BLOB_SIZE, BLOB_SIZE)
	blob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blob.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	blob.offset_left = BOX_MARGIN
	blob.offset_top = -BLOB_SIZE - BOX_MARGIN
	blob.offset_right = BOX_MARGIN + BLOB_SIZE
	blob.offset_bottom = -BOX_MARGIN
	_root.add_child(blob)

	var holder := VBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.offset_left = BOX_MARGIN * 2.0 + BLOB_SIZE
	holder.offset_right = -BOX_MARGIN
	holder.offset_top = -(STAGE_HEIGHT + 380.0) if show_visuals else -380.0
	holder.offset_bottom = -BOX_MARGIN
	holder.add_theme_constant_override("separation", 12)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)

	if show_visuals:
		_build_stage(holder)

	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_BOX_BG
	style.border_color = C_BOX_BORDER
	style.set_border_width_all(4)
	style.set_corner_radius_all(0)
	box.add_theme_stylebox_override("panel", style)
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(box)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var name_label := _lbl("DR. BLOB", 13, C_BOX_TEXT)
	column.add_child(name_label)

	_text_label = _lbl("", 15, C_BOX_TEXT)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_text_label)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)

	_hint_label = _lbl("CLICK TO CONTINUE", 10, C_HINT)
	footer.add_child(_hint_label)

	var skip := Button.new()
	skip.text = "SKIP"
	skip.add_theme_font_override("font", FONT_REG)
	skip.add_theme_font_size_override("font_size", 10)
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(_close)
	footer.add_child(skip)

	_voice = AudioStreamPlayer.new()
	_voice.bus = "SFX"
	add_child(_voice)

func _build_stage(holder: VBoxContainer):
	var stage_frame := PanelContainer.new()
	var stage_style := StyleBoxFlat.new()
	stage_style.bg_color = C_STAGE_BG
	stage_style.border_color = C_BOX_BORDER
	stage_style.set_border_width_all(4)
	stage_style.set_corner_radius_all(0)
	stage_frame.add_theme_stylebox_override("panel", stage_style)
	stage_frame.size_flags_vertical = Control.SIZE_SHRINK_END
	stage_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(stage_frame)

	_stage = STAGE.new()
	_stage.custom_minimum_size = Vector2(0, STAGE_HEIGHT)
	stage_frame.add_child(_stage)

func _on_dim_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_close()
		else:
			_advance()
		get_viewport().set_input_as_handled()

func _advance():
	_index += 1
	if _index >= lines.size():
		_close()
		return
	var entry: Dictionary = lines[_index]
	_text_label.text = str(entry.get("text", ""))
	_hint_label.text = final_hint if _index == lines.size() - 1 else "CLICK TO CONTINUE  (%d / %d)" % [_index + 1, lines.size()]
	if _stage != null:
		_stage.show_visual(str(entry.get("visual", "swarm")))
	_play_voice(int(entry.get("id", _index + 1)))

func _play_voice(line_id: int):
	_voice.stop()
	var stream := _load_voice(line_id)
	if stream == null:
		return
	_voice.stream = stream
	_voice.play()

func _load_voice(line_id: int) -> AudioStream:
	for extension in [".mp3", ".wav", ".ogg"]:
		var path: String = "%s/line_%02d%s" % [voice_dir, line_id, extension]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null

func _close():
	if _voice != null:
		_voice.stop()
	finished.emit()
	queue_free()

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_REG)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
