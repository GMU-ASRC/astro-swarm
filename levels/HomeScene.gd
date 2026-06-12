extends Control

const VERSION := "v0.0.1-alpha"
const VERSION_URL := "https://astroswarm.autonomousrobotics.club/api/version"
const API_KEY := "damage-option-ozone"

func _ready():
	get_tree().paused = false
	$VBox/ButtonBox/PlayButton.pressed.connect(_on_play)
	$VBox/ButtonBox/SimulatorButton.pressed.connect(_on_simulator)
	$VBox/ButtonBox/SettingsButton.pressed.connect(_on_settings)
	$VBox/ButtonBox/QuitButton.pressed.connect(_on_quit)
	$VersionLabel.text = VERSION
	_check_for_update()

func _check_for_update():
	var req := HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)
	req.request_completed.connect(_on_version_response.bind(req))
	if req.request(VERSION_URL, ["X-API-Key: " + API_KEY], HTTPClient.METHOD_GET) != OK:
		req.queue_free()

func _on_version_response(_result, code, _headers, body, req):
	req.queue_free()
	if code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		return
	var latest: String = str(data.get("tag_name", data.get("version", "")))
	if latest != "" and _is_newer(latest, VERSION):
		$UpdateBadge.text = "Update available: %s" % latest
		$UpdateBadge.visible = true

func _is_newer(latest: String, current: String) -> bool:
	var a := _parse_version(latest)
	var b := _parse_version(current)
	for i in 3:
		if a[i] != b[i]:
			return a[i] > b[i]
	return false

func _parse_version(version: String) -> Array:
	var s := version.strip_edges().to_lower()
	if s.begins_with("v"):
		s = s.substr(1)
	s = s.split("-")[0]
	var parts := s.split(".")
	var nums := [0, 0, 0]
	for i in mini(3, parts.size()):
		nums[i] = int(parts[i])
	return nums

func _on_play():
	get_tree().change_scene_to_file("res://levels/PlayerBaseScene.tscn")

func _on_simulator():
	get_tree().change_scene_to_file("res://levels/Arena.tscn")

func _on_settings():
	get_tree().change_scene_to_file("res://levels/SettingsScene.tscn")

func _on_quit():
	get_tree().quit()
