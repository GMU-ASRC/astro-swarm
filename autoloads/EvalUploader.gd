extends Node

const URL := "https://astroswarm.autonomousrobotics.club/api/evaluations"
const BEST_URL := URL + "/best"
const RUN_URL := URL + "/run"
const API_KEY := "world-unfair-file"

signal submit_finished(success: bool, code: int, response)
signal best_fetched(success: bool, response)
signal xp_claimed(entry_id: String, success: bool, xp: int, message: String)

func game_version() -> String:
	return "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.7"))

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
		var data = _parse_json(response)
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

func submit_run(level_id: String, algorithm: Array, placements: Array, run: Dictionary):
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
		"run": run,
	})
	var req := HTTPRequest.new()
	req.timeout = 30.0
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
	if req.request(RUN_URL, headers, HTTPClient.METHOD_POST, body) != OK:
		req.queue_free()
		submit_finished.emit(false, 0, {})

func fetch_best(level_id: String):
	var req := HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	req.request_completed.connect(func(_result, code, _headers, response):
		var data = _parse_json(response)
		best_fetched.emit(code >= 200 and code < 300, data)
		req.queue_free()
	)
	var headers := ["X-API-Key: " + API_KEY]
	if req.request("%s?level_id=%s" % [BEST_URL, level_id], headers, HTTPClient.METHOD_GET) != OK:
		req.queue_free()
		best_fetched.emit(false, {})

func claim_xp(entry_id: String):
	var req := HTTPRequest.new()
	req.timeout = 20.0
	add_child(req)
	req.request_completed.connect(func(_result, code, _headers, response):
		req.queue_free()
		_finish_claim(entry_id, code, _parse_json(response))
	)
	var headers := [
		"X-API-Key: " + API_KEY,
		"Content-Type: application/json",
	]
	var url: String = "%s/%s/claim-xp" % [URL, entry_id]
	if req.request(url, headers, HTTPClient.METHOD_POST, "{}") != OK:
		req.queue_free()
		xp_claimed.emit(entry_id, false, 0, "Could not reach the server")

func _finish_claim(entry_id: String, code: int, data):
	if code < 200 or code >= 300:
		var reason: String = "Claim failed (%d)" % code
		if typeof(data) == TYPE_DICTIONARY and data.has("error"):
			reason = str(data["error"])
		xp_claimed.emit(entry_id, false, 0, reason)
		return
	var xp: int = 0
	var already: bool = false
	if typeof(data) == TYPE_DICTIONARY:
		xp = int(data.get("xp", 0))
		already = bool(data.get("already_claimed", false))
	if not already and xp > 0:
		PlayerData.add_xp(xp)
	xp_claimed.emit(entry_id, true, xp, "")

func _parse_json(response: PackedByteArray):
	var text := response.get_string_from_utf8().strip_edges()
	if text == "":
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data
