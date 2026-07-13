extends Node

const LEVEL1_BENCH := preload("res://simulations/farp/Level1Bench.gd")
const LEVEL2_BENCH := preload("res://simulations/farp/Level2Bench.gd")
const LEVEL3_BENCH := preload("res://simulations/farp/Level3Bench.gd")

func _ready():
	if not _is_bench_mode():
		return
	var bench: Node = _bench_for_level(_level_id_arg())
	add_child(bench)
	bench.parse_args()
	bench.start()

func _is_bench_mode() -> bool:
	if OS.has_feature("dedicated_server"):
		return true
	return "--bench" in OS.get_cmdline_user_args() or "--bench" in OS.get_cmdline_args()

func _level_id_arg() -> String:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--level-id="):
			return arg.split("=", true, 1)[1]
	return "farp1"

func _bench_for_level(level_id: String) -> Node:
	match _level_number(level_id):
		2: return LEVEL2_BENCH.new()
		3: return LEVEL3_BENCH.new()
	return LEVEL1_BENCH.new()

func _level_number(level_id: String) -> int:
	var digits: String = ""
	for ch in level_id:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits == "":
		return 1
	return int(digits)
