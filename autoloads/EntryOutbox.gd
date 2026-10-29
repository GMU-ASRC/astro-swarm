extends Node

signal pending_count_changed(count: int)

const OUTBOX_DIR := "user://entry_outbox"
const API_KEY := "world-unfair-file"
const RETRY_INTERVAL := 60.0
const RETRY_TIMEOUT := 120.0
const OFFLINE_CODES := [0, 502, 503, 504]

var _is_flushing: bool = false

func _ready():
	DirAccess.make_dir_recursive_absolute(OUTBOX_DIR)
	var retry_timer := Timer.new()
	retry_timer.wait_time = RETRY_INTERVAL
	retry_timer.timeout.connect(flush)
	add_child(retry_timer)
	retry_timer.start()
	flush.call_deferred()

func is_offline_code(code: int) -> bool:
	return code in OFFLINE_CODES

func pending_count() -> int:
	return _pending_file_names().size()

func pending_entries(api_paths: Array) -> Array:
	var entries: Array = []
	for file_name in _pending_file_names():
		var entry: Dictionary = _read_entry(OUTBOX_DIR.path_join(file_name))
		if entry.is_empty() or not (entry["path"] in api_paths):
			continue
		var payload = JSON.parse_string(entry["body"])
		if payload is Dictionary:
			entries.append(payload)
	entries.reverse()
	return entries

func post_entry(api_path: String, payload: Dictionary, timeout: float, on_done: Callable):
	var stamped_payload: Dictionary = payload.duplicate()
	stamped_payload["created_at"] = _current_timestamp()
	var body := JSON.stringify(stamped_payload, "", false)
	_send(api_path, body, timeout, func(code: int, response: PackedByteArray):
		var saved_offline := is_offline_code(code)
		if saved_offline:
			_save(api_path, body)
		else:
			flush()
		on_done.call(code, response, saved_offline)
	)

func flush():
	if _is_flushing:
		return
	var file_names := _pending_file_names()
	if file_names.is_empty():
		return
	_is_flushing = true
	_send_next(file_names)

func _send_next(file_names: Array):
	if file_names.is_empty():
		_finish_flush()
		return
	var file_path: String = OUTBOX_DIR.path_join(file_names.pop_front())
	var entry: Dictionary = _read_entry(file_path)
	if entry.is_empty():
		DirAccess.remove_absolute(file_path)
		_send_next(file_names)
		return
	_send(entry["path"], entry["body"], RETRY_TIMEOUT, func(code: int, _response: PackedByteArray):
		if is_offline_code(code):
			_finish_flush()
			return
		DirAccess.remove_absolute(file_path)
		_send_next(file_names)
	)

func _finish_flush():
	_is_flushing = false
	pending_count_changed.emit(pending_count())

func _send(api_path: String, body: String, timeout: float, on_response: Callable):
	var request := HTTPRequest.new()
	request.timeout = timeout
	add_child(request)
	request.request_completed.connect(func(_result, code, _headers, response):
		request.queue_free()
		on_response.call(code, response)
	)
	var headers := [
		"X-API-Key: " + API_KEY,
		"Content-Type: application/json",
	]
	if request.request(PlayerSettings.server_url() + api_path, headers, HTTPClient.METHOD_POST, body) != OK:
		request.queue_free()
		on_response.call(0, PackedByteArray())

func _save(api_path: String, body: String):
	var unix_millis := int(Time.get_unix_time_from_system() * 1000.0)
	var file_name := "%d_%06d.json" % [unix_millis, randi() % 1000000]
	var file := FileAccess.open(OUTBOX_DIR.path_join(file_name), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"path": api_path, "body": body}))
	file.close()
	pending_count_changed.emit(pending_count())

func _read_entry(file_path: String) -> Dictionary:
	var entry = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if entry is Dictionary and entry.get("path") is String and entry.get("body") is String:
		return entry
	return {}

func _pending_file_names() -> Array:
	var file_names: Array = Array(DirAccess.get_files_at(OUTBOX_DIR)).filter(func(file_name): return file_name.ends_with(".json"))
	file_names.sort()
	return file_names

func _current_timestamp() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"
