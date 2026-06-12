extends Node

signal upload_finished(success: bool, message: String)

const URL := "https://astroswarm.autonomousrobotics.club/api/runs"
const API_KEY := "damage-option-ozone"

func _emit_deferred(success: bool, message: String):
	upload_finished.emit.call_deferred(success, message)

func upload(run_path: String, video_path: String, setup: Dictionary):
	var run_bytes := FileAccess.get_file_as_bytes(run_path)
	if run_bytes.is_empty():
		_emit_deferred(false, "Run file missing")
		return
	var config_bytes := _make_config_bytes(setup)
	var video_bytes := FileAccess.get_file_as_bytes(video_path)
	var boundary := "AstroSwarmBoundary%d" % Time.get_ticks_msec()

	var body := PackedByteArray()
	body.append_array(_file_part(boundary, "run", run_path.get_file(), "application/octet-stream", run_bytes))
	body.append_array(_file_part(boundary, "config", "run.cfg", "text/plain", config_bytes))
	if not video_bytes.is_empty():
		body.append_array(_file_part(boundary, "video", video_path.get_file(), "video/mp4", video_bytes))
	body.append_array(("--%s--\r\n" % boundary).to_utf8_buffer())

	var req := HTTPRequest.new()
	req.timeout = 60.0
	add_child(req)
	req.request_completed.connect(func(_result, code, _headers, _response):
		req.queue_free()
		upload_finished.emit(code >= 200 and code < 300, "HTTP %d" % code)
	)
	var headers := [
		"X-API-Key: " + API_KEY,
		"Content-Type: multipart/form-data; boundary=" + boundary,
	]
	if req.request_raw(URL, headers, HTTPClient.METHOD_POST, body) != OK:
		req.queue_free()
		_emit_deferred(false, "Request failed to start")

func _file_part(boundary: String, field: String, filename: String, mime: String, data: PackedByteArray) -> PackedByteArray:
	var header := "--%s\r\nContent-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n" % [boundary, field, filename, mime]
	var part := header.to_utf8_buffer()
	part.append_array(data)
	part.append_array("\r\n".to_utf8_buffer())
	return part

func _make_config_bytes(setup: Dictionary) -> PackedByteArray:
	var config := ConfigFile.new()
	config.set_value("run", "created", Time.get_datetime_string_from_system())
	config.set_value("run", "species", setup.get("robot_types", []).size())
	config.set_value("run", "placements", setup.get("placements", []).size())
	var settings: Dictionary = setup.get("settings", {})
	for key in settings.keys():
		config.set_value("settings", key, settings[key])
	var tmp_path := "user://upload_temp.cfg"
	config.save(tmp_path)
	var bytes := FileAccess.get_file_as_bytes(tmp_path)
	DirAccess.remove_absolute(tmp_path)
	return bytes
