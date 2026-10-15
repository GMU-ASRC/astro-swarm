extends CanvasLayer

signal travel_requested

const HUD_BUTTONS := preload("res://ui/hud/HudButtons.gd")
const MOON_VISUAL := preload("res://levels/menus/moons/MoonVisual.gd")

const MOON_SIZE := 320.0
const FLASH_SECONDS := 0.7
const GROW_SECONDS := 0.9
const TEXT_DELAY := 0.5
const C_BACKDROP := Color(0.02, 0.02, 0.04, 0.94)
const C_ACCENT := Color(0.451, 0.616, 1.0, 1.0)
const C_TEXT := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM := Color(0.6, 0.62, 0.74, 1.0)

var moon: Dictionary = {}
var moon_seed: int = 0

func _ready():
	layer = 45
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var backdrop := ColorRect.new()
	backdrop.color = C_BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)

	var moon_holder := CenterContainer.new()
	moon_holder.custom_minimum_size = Vector2(MOON_SIZE, MOON_SIZE)
	column.add_child(moon_holder)
	var moon_visual: Control = MOON_VISUAL.make(moon_seed, MOON_SIZE)
	moon_holder.add_child(moon_visual)

	var text_column := VBoxContainer.new()
	text_column.add_theme_constant_override("separation", 10)
	text_column.modulate.a = 0.0
	column.add_child(text_column)
	text_column.add_child(_label("NEW MOON UNLOCKED", 16, C_ACCENT))
	text_column.add_child(_label(str(moon.get("title", "")).to_upper(), 40, C_TEXT))
	text_column.add_child(_label(str(moon.get("description", "")), 16, C_DIM))

	var travel_btn: Button = HUD_BUTTONS.make("TRAVEL TO %s >" % str(moon.get("title", "")).to_upper(), HUD_BUTTONS.Kind.PRIMARY, 16)
	travel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	travel_btn.pressed.connect(func(): travel_requested.emit())
	text_column.add_child(travel_btn)

	var flash := ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)

	_animate(flash, moon_visual, text_column)

func _animate(flash: ColorRect, moon_visual: Control, text_column: Control):
	moon_visual.pivot_offset = Vector2(MOON_SIZE, MOON_SIZE) * 0.5
	moon_visual.scale = Vector2(0.3, 0.3)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flash, "modulate:a", 0.0, FLASH_SECONDS).set_ease(Tween.EASE_OUT)
	tween.tween_property(moon_visual, "scale", Vector2.ONE, GROW_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(text_column, "modulate:a", 1.0, 0.4).set_delay(TEXT_DELAY)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
