extends Node
## Wi-Fi play: ENet connection + automatic table discovery via UDP broadcast.

signal tables_changed
signal joined_ok
signal join_failed
signal lost_server

const GAME_PORT := 7777
const DISC_PORT := 7778
const MAGIC := "prsi1"

var hosting := false
var table_name := ""
var found := {}  # ip -> {"name": String, "t": int}

var _announce := PacketPeerUDP.new()
var _listen := PacketPeerUDP.new()
var _listening := false
var _timer := 0.0


func _ready() -> void:
	multiplayer.connected_to_server.connect(func(): joined_ok.emit())
	multiplayer.connection_failed.connect(func():
		_reset_peer()
		join_failed.emit())
	multiplayer.server_disconnected.connect(func():
		_reset_peer()
		lost_server.emit())


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func host(name: String) -> int:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(GAME_PORT, 3)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	hosting = true
	table_name = name
	_announce = PacketPeerUDP.new()
	_announce.set_broadcast_enabled(true)
	_announce.bind(0)
	return OK


func join(ip: String) -> int:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), GAME_PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	hosting = false
	_announce.close()
	_reset_peer()


func _reset_peer() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func start_discovery() -> void:
	stop_discovery()
	found.clear()
	_listen = PacketPeerUDP.new()
	_listening = _listen.bind(DISC_PORT) == OK
	tables_changed.emit()


func stop_discovery() -> void:
	if _listening:
		_listen.close()
	_listening = false


func local_ips() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		if a.contains(":"):
			continue
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and int(a.split(".")[1]) >= 16 and int(a.split(".")[1]) <= 31):
			out.append(a)
	return out


func _broadcast_targets() -> Array:
	var t: Array = ["255.255.255.255", "127.0.0.1"]
	for ip in local_ips():
		var p: PackedStringArray = ip.split(".")
		t.append("%s.%s.%s.255" % [p[0], p[1], p[2]])
	return t


func _process(delta: float) -> void:
	_timer += delta
	if hosting and _timer >= 1.0:
		_timer = 0.0
		var msg := JSON.stringify({"g": MAGIC, "n": table_name, "p": GAME_PORT}).to_utf8_buffer()
		for dst in _broadcast_targets():
			_announce.set_dest_address(dst, DISC_PORT)
			_announce.put_packet(msg)
	if _listening:
		var changed := false
		while _listen.get_available_packet_count() > 0:
			var pkt := _listen.get_packet()
			var ip := _listen.get_packet_ip()
			var d = JSON.parse_string(pkt.get_string_from_utf8())
			if d is Dictionary and d.get("g", "") == MAGIC:
				if not found.has(ip):
					changed = true
				found[ip] = {"name": str(d.get("n", "?")), "t": Time.get_ticks_msec()}
		var now := Time.get_ticks_msec()
		for ip in found.keys():
			if now - int(found[ip]["t"]) > 4500:
				found.erase(ip)
				changed = true
		if changed:
			tables_changed.emit()
