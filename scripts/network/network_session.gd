extends Node

## Owns transport, server authority, stable session entity IDs, and the single
## client-to-server gameplay command entry point. Offline play intentionally
## uses the same command path as a host.

signal session_mode_changed(mode: SessionMode)
signal command_received(sender_peer_id: int, command_type: StringName, entity_ids: Array, payload: Dictionary)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal connection_failed
signal disconnected_from_server

enum SessionMode { OFFLINE, HOST, CLIENT }

const SERVER_PEER_ID := 1
const DEFAULT_PORT := 27820
const DEFAULT_MAX_CLIENTS := 8
const MAX_COMMAND_ENTITIES := 64
const MAX_COMMANDS_PER_SECOND := 90

var mode := SessionMode.OFFLINE
var _next_entity_id := 10_000
var _next_command_sequence := 1
var _entities_by_id: Dictionary = {}
var _last_sequence_by_peer: Dictionary = {}
var _rate_window_by_peer: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int = DEFAULT_PORT, max_clients: int = DEFAULT_MAX_CLIENTS) -> Error:
	disconnect_session()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_clients)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	_set_mode(SessionMode.HOST)
	return OK

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	disconnect_session()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	_set_mode(SessionMode.CLIENT)
	return OK

func disconnect_session() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_last_sequence_by_peer.clear()
	_rate_window_by_peer.clear()
	_set_mode(SessionMode.OFFLINE)

func is_simulation_authority() -> bool:
	return mode != SessionMode.CLIENT

func get_local_peer_id() -> int:
	return SERVER_PEER_ID if mode == SessionMode.OFFLINE else multiplayer.get_unique_id()

func register_entity(entity: Entity, requested_id: int = 0) -> int:
	if requested_id > 0:
		var existing: Entity = _entities_by_id.get(requested_id)
		if existing == null or existing == entity:
			_entities_by_id[requested_id] = entity
			_next_entity_id = maxi(_next_entity_id, requested_id + 1)
			return requested_id
	if not is_simulation_authority():
		return 0
	while _entities_by_id.has(_next_entity_id):
		_next_entity_id += 1
	var assigned_id := _next_entity_id
	_next_entity_id += 1
	_entities_by_id[assigned_id] = entity
	return assigned_id

func unregister_entity(entity_id: int, entity: Entity) -> void:
	if entity_id > 0 and _entities_by_id.get(entity_id) == entity:
		_entities_by_id.erase(entity_id)

func get_entity(entity_id: int) -> Entity:
	var entity: Entity = _entities_by_id.get(entity_id)
	return entity if is_instance_valid(entity) else null

func submit_command(command_type: StringName, entity_ids: Array, payload: Dictionary = {}) -> void:
	var sequence := _next_command_sequence
	_next_command_sequence += 1
	if is_simulation_authority():
		_accept_command(get_local_peer_id(), sequence, command_type, entity_ids, payload)
	else:
		_receive_command.rpc_id(SERVER_PEER_ID, sequence, command_type, entity_ids, payload)

@rpc("any_peer", "call_remote", "reliable", 0)
func _receive_command(sequence: int, command_type: StringName, entity_ids: Array, payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	_accept_command(multiplayer.get_remote_sender_id(), sequence, command_type, entity_ids, payload)

func _accept_command(sender_peer_id: int, sequence: int, command_type: StringName, entity_ids: Array, payload: Dictionary) -> void:
	if command_type.is_empty() or entity_ids.is_empty() or entity_ids.size() > MAX_COMMAND_ENTITIES:
		return
	if sequence <= int(_last_sequence_by_peer.get(sender_peer_id, 0)):
		return
	if not _consume_rate_limit(sender_peer_id):
		return
	_last_sequence_by_peer[sender_peer_id] = sequence
	command_received.emit(sender_peer_id, command_type, entity_ids.duplicate(), payload.duplicate(true))

func _consume_rate_limit(peer_id: int) -> bool:
	var now := Time.get_ticks_msec()
	var window: Dictionary = _rate_window_by_peer.get(peer_id, {"started": now, "count": 0})
	if now - int(window["started"]) >= 1000:
		window = {"started": now, "count": 0}
	window["count"] = int(window["count"]) + 1
	_rate_window_by_peer[peer_id] = window
	return int(window["count"]) <= MAX_COMMANDS_PER_SECOND

func _set_mode(new_mode: SessionMode) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	session_mode_changed.emit(mode)

func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	_last_sequence_by_peer.erase(peer_id)
	_rate_window_by_peer.erase(peer_id)
	peer_left.emit(peer_id)

func _on_connection_failed() -> void:
	connection_failed.emit()
	disconnect_session()

func _on_server_disconnected() -> void:
	disconnected_from_server.emit()
	disconnect_session()
