extends RefCounted

const CURRENT_VERSION := 2

const RENAMED_LEVEL_IDS := {
	"farp6": "farp9",
	"farp7": "farp6",
	"farp8": "farp7",
}

static func renamed_id(level_id: String) -> String:
	return RENAMED_LEVEL_IDS.get(level_id, level_id)

static func migrate_completed_levels(completed_levels: Array) -> Array:
	var migrated: Array = []
	for level_id in completed_levels:
		migrated.append(renamed_id(str(level_id)))
	return migrated

static func migrate_layouts(layouts: Dictionary) -> Dictionary:
	var migrated: Dictionary = {}
	for level_id in layouts:
		migrated[renamed_id(str(level_id))] = layouts[level_id]
	return migrated

static func migrate_tutorial_flags(settings: ConfigFile, flag_prefix: String):
	var seen: Dictionary = {}
	for old_id in RENAMED_LEVEL_IDS:
		seen[old_id] = settings.get_value("progress", flag_prefix + old_id, false)
	for old_id in RENAMED_LEVEL_IDS:
		settings.set_value("progress", flag_prefix + renamed_id(old_id), seen[old_id])
