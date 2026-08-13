extends Node

const URL := "https://astroswarm.autonomousrobotics.club/api/survive/matches"
const API_KEY := "world-unfair-file"

signal submit_finished(success: bool, code: int, response)

func game_version() -> String:
	return "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.7"))

func submit(match_data: Dictionary):
	if not PlayerData.has_profile() or PlayerData.player_id == "":
		submit_finished.emit(false, 0, {})
		return
	var payload: Dictionary = match_data.duplicate(true)
	payload["player_id"] = PlayerData.player_id
	payload["username"] = PlayerData.username
	payload["game_version"] = game_version()
	var req := HTTPRequest.new()
	req.timeout = 20.0
	add_child(req)
	req.request_completed.connect(func(_result, code, _headers, response):
		var data = _parse_json(response)
		submit_finished.emit(code >= 200 and code < 300, code, data)
		req.queue_free()
	)
	var headers := [
		"X-API-Key: " + API_KEY,
		"Content-Type: application/json",
	]
	if req.request(URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
		req.queue_free()
		submit_finished.emit(false, 0, {})

func _parse_json(response: PackedByteArray):
	var text := response.get_string_from_utf8().strip_edges()
	if text == "":
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data
