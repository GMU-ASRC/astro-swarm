extends Node

signal hosts_changed(hosts: Array)
signal opponent_joined()
signal opponent_left()
signal connection_failed()
signal match_started(settings: Dictionary)
signal command_received(slot: int, kind: String, payload: Dictionary)
signal pilot_received(slot: int, thrust: float, turn: float)
signal snapshot_received(data: Dictionary)
signal event_received(kind: String, payload: Dictionary)

const GAME_PORT := 7777
const BEACON_PORT := 7778
const BEACON_INTERVAL := 1.0
const HOST_TIMEOUT := 3.5
const BEACON_TAG := "astroswarm_lan"
const HOST_SLOT := 0
const CLIENT_SLOT := 1

var is_online: bool = false
var is_host: bool = false
var local_slot: int = HOST_SLOT
var opponent_peer_id: int = 0
var host_name: String = ""
var match_settings: Dictionary = {}

var _beacon_sender: PacketPeerUDP = null
var _beacon_listener: PacketPeerUDP = null
var _beacon_timer: float = 0.0
var _found_hosts: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(display_name: String) -> bool:
	close()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(GAME_PORT, 1) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	is_online = true
	is_host = true
	local_slot = HOST_SLOT
	host_name = display_name
	_start_beacon()
	return true

func join_game(address: String) -> bool:
	close()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, GAME_PORT) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	is_online = true
	is_host = false
	local_slot = CLIENT_SLOT
	return true

func close():
	_stop_beacon()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_online = false
	is_host = false
	opponent_peer_id = 0
	local_slot = HOST_SLOT

func has_opponent() -> bool:
	return opponent_peer_id != 0

func start_listening():
	stop_listening()
	_found_hosts.clear()
	_beacon_listener = PacketPeerUDP.new()
	if _beacon_listener.bind(BEACON_PORT, "0.0.0.0") != OK:
		_beacon_listener = null

func stop_listening():
	if _beacon_listener != null:
		_beacon_listener.close()
	_beacon_listener = null

func start_match(settings: Dictionary):
	if not is_host:
		return
	match_settings = settings
	_stop_beacon()
	_receive_match_start.rpc(settings)
	match_started.emit(settings)

func send_command(kind: String, payload: Dictionary = {}):
	if is_host:
		command_received.emit(HOST_SLOT, kind, payload)
	elif is_online:
		_receive_command.rpc_id(1, kind, payload)

func send_pilot(thrust: float, turn: float):
	if is_host:
		pilot_received.emit(HOST_SLOT, thrust, turn)
	elif is_online:
		_receive_pilot.rpc_id(1, thrust, turn)

func broadcast_snapshot(data: Dictionary):
	if is_host and has_opponent():
		_receive_snapshot.rpc_id(opponent_peer_id, data)

func broadcast_event(kind: String, payload: Dictionary = {}):
	if is_host and has_opponent():
		_receive_event.rpc_id(opponent_peer_id, kind, payload)

@rpc("authority", "call_remote", "reliable")
func _receive_match_start(settings: Dictionary):
	match_settings = settings
	match_started.emit(settings)

@rpc("any_peer", "call_remote", "reliable")
func _receive_command(kind: String, payload: Dictionary):
	if is_host and multiplayer.get_remote_sender_id() == opponent_peer_id:
		command_received.emit(CLIENT_SLOT, kind, payload)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_pilot(thrust: float, turn: float):
	if is_host and multiplayer.get_remote_sender_id() == opponent_peer_id:
		pilot_received.emit(CLIENT_SLOT, thrust, turn)

@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_snapshot(data: Dictionary):
	snapshot_received.emit(data)

@rpc("authority", "call_remote", "reliable")
func _receive_event(kind: String, payload: Dictionary):
	event_received.emit(kind, payload)

func _process(delta: float):
	if _beacon_sender != null:
		_beacon_timer -= delta
		if _beacon_timer <= 0.0:
			_beacon_timer = BEACON_INTERVAL
			_send_beacon()
	if _beacon_listener != null:
		_read_beacons()
		_expire_hosts()

func _start_beacon():
	_beacon_sender = PacketPeerUDP.new()
	_beacon_sender.set_broadcast_enabled(true)
	_beacon_sender.bind(0)
	_beacon_timer = 0.0

func broadcast_addresses() -> Array:
	var out: Array = ["255.255.255.255"]
	for address in local_addresses():
		var parts: PackedStringArray = address.split(".")
		var subnet_broadcast: String = "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
		if not out.has(subnet_broadcast):
			out.append(subnet_broadcast)
	return out

func local_addresses() -> Array:
	var out: Array = []
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
			out.append(address)
	return out

func is_listening() -> bool:
	return _beacon_listener != null

func _stop_beacon():
	if _beacon_sender != null:
		_beacon_sender.close()
	_beacon_sender = null

func _send_beacon():
	if has_opponent():
		return
	var message: Dictionary = {"tag": BEACON_TAG, "name": host_name, "port": GAME_PORT}
	var packet: PackedByteArray = JSON.stringify(message).to_utf8_buffer()
	for address in broadcast_addresses():
		_beacon_sender.set_dest_address(address, BEACON_PORT)
		_beacon_sender.put_packet(packet)

func _read_beacons():
	var changed: bool = false
	while _beacon_listener.get_available_packet_count() > 0:
		var packet: PackedByteArray = _beacon_listener.get_packet()
		var address: String = _beacon_listener.get_packet_ip()
		var message = JSON.parse_string(packet.get_string_from_utf8())
		if not (message is Dictionary) or message.get("tag", "") != BEACON_TAG or address == "":
			continue
		if not _found_hosts.has(address):
			changed = true
		_found_hosts[address] = {"address": address, "name": str(message.get("name", address)), "seen": Time.get_ticks_msec()}
	if changed:
		hosts_changed.emit(found_hosts())

func _expire_hosts():
	var now: int = Time.get_ticks_msec()
	var expired: Array = []
	for address in _found_hosts.keys():
		if now - int(_found_hosts[address]["seen"]) > int(HOST_TIMEOUT * 1000.0):
			expired.append(address)
	for address in expired:
		_found_hosts.erase(address)
	if not expired.is_empty():
		hosts_changed.emit(found_hosts())

func found_hosts() -> Array:
	return _found_hosts.values()

func _on_peer_connected(peer_id: int):
	if is_host:
		if has_opponent():
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)
			return
		opponent_peer_id = peer_id
		opponent_joined.emit()

func _on_peer_disconnected(peer_id: int):
	if peer_id == opponent_peer_id:
		opponent_peer_id = 0
		opponent_left.emit()

func _on_connected_to_server():
	opponent_peer_id = 1
	opponent_joined.emit()

func _on_connection_failed():
	close()
	connection_failed.emit()

func _on_server_disconnected():
	opponent_peer_id = 0
	opponent_left.emit()
