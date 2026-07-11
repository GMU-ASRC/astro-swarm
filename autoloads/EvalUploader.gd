extends Node

const URL := "https://astroswarm.autonomousrobotics.club/api/evaluations"
const API_KEY := "world-unfair-file"

signal submit_finished(success: bool, code: int, response)

func game_version() -> String:
	return "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.5"))

func submit(algorithm: Array, placements: Array, level_id: String, collisions: bool = false):
	if not PlayerData.has_profile() or PlayerData.player_id == "":
		submit_finished.emit(false, 0, {})
		return
	var body := JSON.stringify({
		"player_id": PlayerData.player_id,
		"username": PlayerData.username,
		"level_id": level_id,
		"algorithm": algorithm,
		"placements": placements,
		"game_version": game_version(),
		"collisions": collisions,
	})
	var req := HTTPRequest.new()
	req.timeout = 20.0
	add_child(req)
	req.request_completed.connect(func(_result, code, _headers, response):
		var data = JSON.parse_string(response.get_string_from_utf8())
		submit_finished.emit(code >= 200 and code < 300, code, data)
		req.queue_free()
	)
	var headers := [
		"X-API-Key: " + API_KEY,
		"Content-Type: application/json",
	]
	if req.request(URL, headers, HTTPClient.METHOD_POST, body) != OK:
		req.queue_free()
		submit_finished.emit(false, 0, {})
