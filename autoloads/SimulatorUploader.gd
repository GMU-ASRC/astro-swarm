extends Node

signal upload_finished(success: bool, message: String, entry_url: String)

const ENTRIES_PATH := "/api/simulator/entries"
const ENTRY_PAGE_PATH := "/simulator/"
const REQUEST_TIMEOUT := 120.0
const SimulatorEntryPayload := preload("res://levels/components/SimulatorEntryPayload.gd")

var is_uploading: bool = false

func upload_run(run_path: String, title: String, description: String):
	if is_uploading:
		return
	if not PlayerData.has_profile() or PlayerData.player_id == "":
		_finish_deferred(false, "Create a commander profile from Play before uploading.")
		return
	if title.strip_edges() == "":
		_finish_deferred(false, "Enter a title for the entry.")
		return

	var file := FileAccess.open(run_path, FileAccess.READ)
	if file == null:
		_finish_deferred(false, "Could not open the run file.")
		return
	var run_data = file.get_var()
	file.close()
	if typeof(run_data) != TYPE_DICTIONARY or not run_data.has("setup") or not run_data.has("frames"):
		_finish_deferred(false, "This file is not a recorded simulator run.")
		return

	var built: Dictionary = SimulatorEntryPayload.build(run_data, title, description)
	if built.has("error"):
		_finish_deferred(false, built.error)
		return
	var payload: Dictionary = built.payload
	payload["player_id"] = PlayerData.player_id
	payload["username"] = PlayerData.username
	payload["game_version"] = EvalUploader.game_version()

	is_uploading = true
	EntryOutbox.post_entry(ENTRIES_PATH, payload, REQUEST_TIMEOUT, func(code: int, response: PackedByteArray, saved_offline: bool):
		_on_request_completed(code, response, saved_offline)
	)

func _on_request_completed(code: int, body: PackedByteArray, saved_offline: bool):
	is_uploading = false
	if saved_offline:
		upload_finished.emit(true, "The website could not be reached. The entry was saved on this computer and will upload automatically when the website is back.", "")
		return
	var response = JSON.parse_string(body.get_string_from_utf8()) if body.size() > 0 else null
	if code >= 200 and code < 300 and response is Dictionary and response.has("id"):
		upload_finished.emit(true, "Uploaded. Your entry is live on the website.", PlayerSettings.server_url() + ENTRY_PAGE_PATH + str(response["id"]))
		return
	var reason := "HTTP %d" % code
	if code == 0:
		reason = "no response from the server"
	if response is Dictionary and response.has("error"):
		reason = str(response["error"])
	upload_finished.emit(false, "Upload failed: %s" % reason, "")

func _finish_deferred(success: bool, message: String):
	upload_finished.emit.call_deferred(success, message, "")
