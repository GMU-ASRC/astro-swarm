extends ConfirmationDialog

const MAIN_THEME := preload("res://ui/MainTheme.tres")
const DIALOG_WIDTH := 420.0
const DESCRIPTION_HEIGHT := 96.0
const SUCCESS_COLOR := Color(0.18, 0.54, 0.32, 1.0)
const ERROR_COLOR := Color(0.85, 0.32, 0.27, 1.0)
const SimulatorEntryPayload := preload("res://levels/components/SimulatorEntryPayload.gd")

var run_path: String = ""

var _title_edit: LineEdit
var _description_edit: TextEdit
var _status_label: Label
var _open_button: Button
var _entry_url: String = ""

func _ready():
	title = "Upload to Website"
	theme = MAIN_THEME
	ok_button_text = "Upload"
	cancel_button_text = "Close"
	dialog_hide_on_ok = false
	_build_layout()
	confirmed.connect(_on_upload_pressed)
	SimulatorUploader.upload_finished.connect(_on_upload_finished)
	visibility_changed.connect(func():
		if not visible:
			queue_free()
	)

func _build_layout():
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(DIALOG_WIDTH, 0)
	box.add_theme_constant_override("separation", 8)

	var owner_label := Label.new()
	owner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if PlayerData.has_profile():
		owner_label.text = "Uploading %s as %s" % [run_path.get_file(), PlayerData.username]
	else:
		owner_label.text = "Create a commander profile from Play before uploading."
	box.add_child(owner_label)

	box.add_child(_field_label("Title"))
	_title_edit = LineEdit.new()
	_title_edit.max_length = SimulatorEntryPayload.MAX_TITLE_LENGTH
	_title_edit.text = run_path.get_file().get_basename().replace("_", " ")
	box.add_child(_title_edit)

	box.add_child(_field_label("Description (optional)"))
	_description_edit = TextEdit.new()
	_description_edit.custom_minimum_size = Vector2(0, DESCRIPTION_HEIGHT)
	_description_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(_description_edit)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status_label)

	_open_button = Button.new()
	_open_button.text = "Open Entry in Browser"
	_open_button.visible = false
	_open_button.pressed.connect(func(): OS.shell_open(_entry_url))
	box.add_child(_open_button)

	add_child(box)

func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	return label

func _on_upload_pressed():
	if SimulatorUploader.is_uploading:
		return
	var description := _description_edit.text.left(SimulatorEntryPayload.MAX_DESCRIPTION_LENGTH)
	_set_status("Uploading...", Color(1, 1, 1, 0.8))
	get_ok_button().disabled = true
	SimulatorUploader.upload_run(run_path, _title_edit.text, description)

func _on_upload_finished(success: bool, message: String, entry_url: String):
	_set_status(message, SUCCESS_COLOR if success else ERROR_COLOR)
	if success:
		_entry_url = entry_url
		_open_button.visible = entry_url != ""
		get_ok_button().visible = false
		_title_edit.editable = false
		_description_edit.editable = false
	else:
		get_ok_button().disabled = false

func _set_status(text: String, color: Color):
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)
