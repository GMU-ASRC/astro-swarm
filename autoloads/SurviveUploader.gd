extends Node

const MATCHES_PATH := "/api/survive/matches"

signal submit_finished(success: bool, code: int, response)

func game_version() -> String:
	return "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.9"))

func submit(match_data: Dictionary):
	if not PlayerData.has_profile() or PlayerData.player_id == "":
		submit_finished.emit(false, 0, {})
		return
	var payload: Dictionary = match_data.duplicate(true)
	payload["player_id"] = PlayerData.player_id
	payload["username"] = PlayerData.username
	payload["game_version"] = game_version()
	EntryOutbox.post_entry(MATCHES_PATH, payload, 20.0, func(code: int, response: PackedByteArray, saved_offline: bool):
		var data = {"saved_offline": true} if saved_offline else _parse_json(response)
		submit_finished.emit(code >= 200 and code < 300, code, data)
	)

func _parse_json(response: PackedByteArray):
	var text := response.get_string_from_utf8().strip_edges()
	if text == "":
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data
