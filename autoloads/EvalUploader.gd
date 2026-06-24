extends Node

const URL := "https://astroswarm.autonomousrobotics.club/api/evaluations"
const API_KEY := "damage-option-ozone"

func submit(algorithm: Array, placements: Array, level_id: String):
	if not PlayerData.has_profile() or PlayerData.player_id == "":
		return
	var body := JSON.stringify({
		"player_id": PlayerData.player_id,
		"username": PlayerData.username,
		"level_id": level_id,
		"algorithm": algorithm,
		"placements": placements,
	})
	var req := HTTPRequest.new()
	req.timeout = 20.0
	add_child(req)
	req.request_completed.connect(func(_result, _code, _headers, _response):
		req.queue_free()
	)
	var headers := [
		"X-API-Key: " + API_KEY,
		"Content-Type: application/json",
	]
	if req.request(URL, headers, HTTPClient.METHOD_POST, body) != OK:
		req.queue_free()
