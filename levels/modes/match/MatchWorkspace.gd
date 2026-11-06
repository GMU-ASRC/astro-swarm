extends "res://ui/workspace/ShipWorkspace.gd"

signal program_changed(role: int, scripts: Array)

const MATCH_CONFIG := preload("res://levels/modes/match/MatchConfig.gd")

const MATCH_PALETTE := {
	"config": ["set_speed", "set_turn", "set_view", "set_fov"],
	"condition": ["when_start", "when_always", "when_sees", "when_sees_enemy", "when_sees_ally", "when_alone", "when_not_see", "when_sees_dust", "when_sees_enemy_planet", "when_far_from_home", "when_near_wall", "when_not_near_wall", "when_sees_wall"],
	"logic": ["if_see", "if_not_see", "if_sees_dust", "if_not_sees_dust", "if_far_from_home", "if_near_wall", "if_not_near_wall", "elif_see", "elif_not_see", "elif_sees_dust", "elif_far_from_home", "elif_near_wall", "else"],
	"action": ["do_forward", "do_backward", "do_stop", "do_random_walk", "do_turn_left", "do_turn_right", "do_turn_left_by", "do_turn_right_by", "do_face", "do_face_dust", "do_face_enemy_planet", "do_face_home"],
}

var programs: Dictionary = {}
var current_role: int = MATCH_CONFIG.Role.COLLECTOR

func _enter_tree():
	pass

func _exit_tree():
	pass

func _back_label() -> String:
	return " ← Close "

func _build_genome_ui():
	$TopBar/HBox/Title.text = "FLEET ALGORITHMS"
	var spacer: Control = $TopBar/HBox/Spacer
	var group := ButtonGroup.new()
	for role in MATCH_CONFIG.PROGRAMMABLE_ROLES:
		var button := Button.new()
		button.text = MATCH_CONFIG.ROLE_NAMES[role]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.button_pressed = role == current_role
		button.pressed.connect(_switch_role.bind(role))
		top_hbox.add_child(button)
		top_hbox.move_child(button, spacer.get_index())
	_update_header()

func _switch_role(role: int):
	if role == current_role:
		return
	_save_blocks()
	current_role = role
	_update_header()
	_load_blocks()

func _update_header():
	var header: Label = $Body/Right/RightVBox/HeaderBar/Header/HeaderLabel
	header.text = "%s program" % MATCH_CONFIG.ROLE_NAMES[current_role]

func _build_palette():
	for child in palette_list.get_children():
		child.queue_free()
	for category in ["config", "condition", "logic", "action"]:
		_build_palette_category(category, MATCH_PALETTE[category])

func _load_blocks():
	_populate_canvas(programs.get(current_role, []))

func _save_blocks():
	if _loading:
		return
	var scripts: Array = canvas.collect_scripts()
	programs[current_role] = scripts
	program_changed.emit(current_role, scripts)
	_update_errors()
