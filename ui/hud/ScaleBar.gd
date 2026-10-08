extends CanvasLayer

const PX_PER_METER := 40.0
const NICE_METERS := [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0]
const TARGET_WIDTH := 120.0
const MARGIN := Vector2(18, 18)
const TICK_HEIGHT := 12.0
const LINE_WIDTH := 4.0
const PADDING := Vector2(10, 6)
const FONT_SIZE := 13

const SCALE_COLOR := Color(0.255, 0.463, 0.843, 1.0)
const LABEL_EMBOLDEN := 1.0

var camera: Camera2D
var _canvas: Control
var _last_zoom: float = -1.0
var _label_font: FontVariation

func _ready():
	layer = 5
	_label_font = FontVariation.new()
	_label_font.base_font = ThemeDB.fallback_font
	_label_font.variation_embolden = LABEL_EMBOLDEN
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_scale)
	_canvas.resized.connect(_canvas.queue_redraw)
	add_child(_canvas)

func _process(_delta: float):
	if camera == null:
		return
	if not is_equal_approx(camera.zoom.x, _last_zoom):
		_last_zoom = camera.zoom.x
		_canvas.queue_redraw()

func _scale_length(zoom_level: float) -> float:
	var best: float = NICE_METERS[0]
	for meters in NICE_METERS:
		if meters * PX_PER_METER * zoom_level <= TARGET_WIDTH:
			best = meters
	return best

func _draw_scale():
	if camera == null or camera.zoom.x <= 0.0:
		return
	var zoom_level: float = camera.zoom.x
	var meters: float = _scale_length(zoom_level)
	var bar_width: float = meters * PX_PER_METER * zoom_level
	var font: Font = _label_font
	var label: String = "%d m" % int(meters)
	var label_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)

	var area_size := Vector2(maxf(bar_width, label_size.x) + PADDING.x * 2.0, label_size.y + TICK_HEIGHT + PADDING.y * 3.0)
	var area_position: Vector2 = _canvas.size - MARGIN - area_size

	var right: float = area_position.x + area_size.x - PADDING.x
	var left: float = right - bar_width
	var baseline: float = area_position.y + area_size.y - PADDING.y
	_canvas.draw_line(Vector2(left, baseline), Vector2(right, baseline), SCALE_COLOR, LINE_WIDTH)
	_canvas.draw_line(Vector2(left, baseline), Vector2(left, baseline - TICK_HEIGHT), SCALE_COLOR, LINE_WIDTH)
	_canvas.draw_line(Vector2(right, baseline), Vector2(right, baseline - TICK_HEIGHT), SCALE_COLOR, LINE_WIDTH)

	var label_position := Vector2(right - label_size.x, area_position.y + PADDING.y + font.get_ascent(FONT_SIZE))
	_canvas.draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, SCALE_COLOR)
