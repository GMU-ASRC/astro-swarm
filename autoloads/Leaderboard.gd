extends Node

const URL := "https://astroswarm.autonomousrobotics.club/api/leaderboard"
const API_KEY := "world-unfair-file"

func submit_time(time_seconds: float, algorithm: Array = []):
	if PlayerData.player_id.length() != 36:
		return
	var body := {
		"player_id": PlayerData.player_id,
		"username": PlayerData.username.substr(0, 30),
		"time_seconds": clampf(time_seconds, 2.0, 90.0),
		"algorithm": algorithm,
	}
	var req := HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	req.request_completed.connect(func(_result, _code, _headers, _response): req.queue_free())
	var headers := ["Content-Type: application/json", "X-API-Key: " + API_KEY]
	if req.request(URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body)) != OK:
		req.queue_free()
