extends RefCounted

const ALL := [
	{
		"id": "thrusters",
		"title": "THRUSTERS",
		"detail": "UNLOCKS THE THROTTLE BLOCK",
		"icon": "res://assets/sprites/upgrades/thrusters.svg",
		"cost": 150,
		"unlocked_blocks": ["do_throttle"],
	},
]

static func is_owned(addon: Dictionary) -> bool:
	return PlayerData.has_ship_addon(addon["id"])

static func purchase(addon: Dictionary) -> bool:
	if is_owned(addon):
		return false
	if not PlayerData.spend_coins(int(addon["cost"])):
		return false
	PlayerData.add_ship_addon(addon["id"])
	return true

static func is_block_locked(block_type: String) -> bool:
	for addon in ALL:
		if addon["unlocked_blocks"].has(block_type):
			return not is_owned(addon)
	return false

static func strip_locked_blocks(scripts: Array) -> Array:
	var kept_scripts: Array = []
	for stack in scripts:
		var kept_stack: Dictionary = stack.duplicate()
		kept_stack["blocks"] = _unlocked_blocks(stack.get("blocks", []))
		if not kept_stack["blocks"].is_empty():
			kept_scripts.append(kept_stack)
	return kept_scripts

static func _unlocked_blocks(blocks: Array) -> Array:
	var kept: Array = []
	for block in blocks:
		if is_block_locked(block.get("type", "")):
			continue
		var kept_block: Dictionary = block.duplicate()
		if block.has("children"):
			kept_block["children"] = _unlocked_blocks(block["children"])
		kept.append(kept_block)
	return kept
