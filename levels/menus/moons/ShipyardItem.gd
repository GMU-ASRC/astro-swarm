extends PanelContainer

signal purchase_requested(item: Dictionary)

const HUD_BUTTONS := preload("res://ui/hud/HudButtons.gd")
const FRAME := preload("res://assets/sprites/upgrades/card_frame.svg")
const COIN := preload("res://assets/sprites/upgrades/astro_coin.svg")

const FRAME_MARGIN := 12
const PADDING_X := 30
const PADDING_Y := 20
const COLUMN_GAP := 28
const ICON_SIZE := 72.0
const COIN_SIZE := 24.0
const COST_WIDTH := 150.0
const BUTTON_WIDTH := 170.0
const TITLE_FONT_SIZE := 22
const DETAIL_FONT_SIZE := 18
const BUTTON_FONT_SIZE := 16

const C_TEXT := Color(0.93, 0.94, 1.0, 1.0)
const C_ACCENT := Color(0.451, 0.616, 1.0, 1.0)
const C_COIN := Color(1.0, 0.88, 0.40, 1.0)
const C_COIN_SHORT := Color(0.75, 0.64, 0.22, 1.0)
const C_SETTLED := Color(0.40, 0.85, 0.45, 1.0)

var _item: Dictionary = {}
var _layout: BoxContainer
var _cost_icon: TextureRect
var _cost_label: Label
var _buy_button: Button

func setup(item: Dictionary):
	_item = item
	_build_frame()
	_build_columns()
	refresh()

func refresh():
	pass

func _build_columns():
	pass

func _build_frame():
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_stylebox_override("panel", _frame_style())
	_layout = _make_layout()
	add_child(_layout)

func _make_layout() -> BoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", COLUMN_GAP)
	return line

func _make_cost_box(alignment: BoxContainer.AlignmentMode) -> HBoxContainer:
	var cost := HBoxContainer.new()
	cost.custom_minimum_size = Vector2(COST_WIDTH, 0)
	cost.alignment = alignment
	cost.add_theme_constant_override("separation", 6)
	_cost_icon = _pixel_image(COIN, COIN_SIZE)
	cost.add_child(_cost_icon)
	_cost_label = _label("", DETAIL_FONT_SIZE, C_COIN)
	cost.add_child(_cost_label)
	return cost

func _make_buy_button() -> Button:
	_buy_button = HUD_BUTTONS.make("", HUD_BUTTONS.Kind.PRIMARY, BUTTON_FONT_SIZE)
	_buy_button.custom_minimum_size = Vector2(BUTTON_WIDTH, 0)
	_buy_button.pressed.connect(func(): purchase_requested.emit(_item))
	return _buy_button

func _show_price(price: int, button_text: String):
	var affordable: bool = PlayerData.coins >= price
	_cost_icon.visible = true
	_cost_label.text = str(price)
	_cost_label.add_theme_color_override("font_color", C_COIN if affordable else C_COIN_SHORT)
	_buy_button.text = button_text
	_buy_button.disabled = not affordable

func _show_settled(status_text: String, button_text: String):
	_cost_icon.visible = false
	_cost_label.text = status_text
	_cost_label.add_theme_color_override("font_color", C_SETTLED)
	_buy_button.text = button_text
	_buy_button.disabled = true

func _frame_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = FRAME
	style.set_texture_margin_all(FRAME_MARGIN)
	style.content_margin_left = PADDING_X
	style.content_margin_right = PADDING_X
	style.content_margin_top = PADDING_Y
	style.content_margin_bottom = PADDING_Y
	return style

func _pixel_image(texture: Texture2D, display_size: float) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.custom_minimum_size = Vector2(display_size, display_size)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
