extends Control

@onready var save_list: ItemList = $VBox/Content/VBox/SaveList
@onready var run_list: ItemList = $VBox/Content/VBox2/RunList
@onready var save_name_edit: LineEdit = $VBox/Content/VBox/HBox/SaveNameEdit

func _ready():
	get_tree().paused = false
	DirAccess.make_dir_absolute("user://saves")
	DirAccess.make_dir_absolute("user://runs")
	_refresh_lists()

	$VBox/Header/BackButton.pressed.connect(_on_back)
	$VBox/Content/VBox/HBox/SaveCurrentBtn.pressed.connect(_on_save_current)
	$VBox/Content/VBox/HBox2/LoadSaveBtn.pressed.connect(_on_load_save)
	$VBox/Content/VBox/HBox2/DeleteSaveBtn.pressed.connect(_on_delete_save)

	$VBox/Content/VBox2/HBox/LoadRunBtn.pressed.connect(_on_load_run)
	$VBox/Content/VBox2/HBox/ExportVideoBtn.pressed.connect(_on_export_video)
	$VBox/Content/VBox2/HBox/DeleteRunBtn.pressed.connect(_on_delete_run)

func _refresh_lists():
	save_list.clear()
	run_list.clear()

	var saves = DirAccess.get_files_at("user://saves")
	for s in saves:
		if s.ends_with(".save"):
			save_list.add_item(s)

	var runs = DirAccess.get_files_at("user://runs")
	for r in runs:
		if r.ends_with(".run"):
			run_list.add_item(r)

func _on_back():
	get_tree().change_scene_to_file("res://levels/Arena.tscn")

func _on_save_current():
	var n = save_name_edit.text.strip_edges()
	if n.is_empty():
		var dt = Time.get_datetime_dict_from_system()
		n = "setup_%04d%02d%02d_%02d%02d%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	if not n.ends_with(".save"):
		n += ".save"
	SimulationManager.save_setup("user://saves/" + n)
	save_name_edit.text = ""
	_refresh_lists()

func _on_load_save():
	var selected = save_list.get_selected_items()
	if selected.size() > 0:
		var fn = save_list.get_item_text(selected[0])
		if SimulationManager.load_setup("user://saves/" + fn):
			_on_back()

func _on_delete_save():
	var selected = save_list.get_selected_items()
	if selected.size() > 0:
		var fn = save_list.get_item_text(selected[0])
		DirAccess.remove_absolute("user://saves/" + fn)
		_refresh_lists()

func _on_load_run():
	var selected = run_list.get_selected_items()
	if selected.size() > 0:
		var fn = run_list.get_item_text(selected[0])
		if SimulationManager.load_run("user://runs/" + fn):
			_on_back()

func _on_export_video():
	var selected = run_list.get_selected_items()
	if selected.size() > 0:
		var fn = run_list.get_item_text(selected[0])
		if SimulationManager.export_run("user://runs/" + fn):
			get_tree().change_scene_to_file("res://levels/Arena.tscn")

func _on_delete_run():
	var selected = run_list.get_selected_items()
	if selected.size() > 0:
		var fn = run_list.get_item_text(selected[0])
		DirAccess.remove_absolute("user://runs/" + fn)
		_refresh_lists()
