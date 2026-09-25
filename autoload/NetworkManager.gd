extends Node
# Autoload this script as "NetworkManager" (Project Settings -> Autoload)
#
# LAN peer-to-peer multiplayer: no external server required.
# - host_game() starts an ENet server and returns a short invite code
#   (the code encodes this device's LAN IP + port).
# - join_with_code() decodes a code and connects directly to that IP.
# - start_quick_match() does both: hosts AND broadcasts/listens on the
#   local network's UDP broadcast address so two devices can find each
#   other automatically without typing a code.
#
# NOTE: this only works between devices that can reach each other directly
# (same WiFi network, or one phone's hotspot). It cannot matchmake over
# the general internet without a relay server.

signal player_connected(profile: Dictionary)   # fired once we've received the other side's profile
signal player_disconnected()
signal connection_failed()
signal connection_succeeded()
signal move_received(from: Vector2i, to: Vector2i)
signal opponent_resigned()
signal lobby_found(info: Dictionary)
signal invite_code_ready(code: String)   # fired after host_game_internet() resolves the public IP

const GAME_PORT := 47321
const DISCOVERY_PORT := 47322
const MAX_PLAYERS := 2
const PUBLIC_IP_SERVICE := "https://api.ipify.org?format=text"

var peer: ENetMultiplayerPeer = null
var is_host := false
var remote_peer_id: int = -1

var local_profile: Dictionary = {}
var remote_profile: Dictionary = {}

var udp_discovery: PacketPeerUDP = null
var seeking_match := false
var hosting_open_lobby := false
var _broadcast_timer := 0.0
var _my_quick_code := ""

var _http_request: HTTPRequest = null


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_peer_disconnected)

	_http_request = HTTPRequest.new()
	add_child(_http_request)


func _process(delta: float) -> void:
	if udp_discovery:
		_poll_discovery()
		if seeking_match:
			_broadcast_timer -= delta
			if _broadcast_timer <= 0.0:
				_broadcast_timer = 1.0
				_broadcast_seek()


# Hosting (LAN)
func _close_existing_peer() -> void:
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	remote_peer_id = -1


func host_game() -> String:
	_close_existing_peer()
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(GAME_PORT, MAX_PLAYERS)
	if err != OK:
		push_warning("NetworkManager: failed to host (err %d)" % err)
		peer = null
		return ""
	multiplayer.multiplayer_peer = peer
	is_host = true
	remote_peer_id = -1
	return generate_invite_code()


func generate_invite_code() -> String:
	var ip = _get_local_ip()
	if ip == "":
		return ""
	return _encode_ip_port(ip, GAME_PORT)


func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254"):
			return ip
	return ""


# Hosting (Internet, requires port forwarding)
# You must forward UDP port 47321 on your router to this device before
# calling this. The invite code will encode your public IP instead of your
# LAN IP, so anyone on the internet with the code (and no port-forwarding
# of their own) can connect straight to you.
func host_game_internet() -> void:
	_close_existing_peer()
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(GAME_PORT, MAX_PLAYERS)
	if err != OK:
		push_warning("NetworkManager: failed to host (err %d)" % err)
		peer = null
		invite_code_ready.emit("")
		return
	multiplayer.multiplayer_peer = peer
	is_host = true
	remote_peer_id = -1

	if _http_request.request_completed.is_connected(_on_public_ip_response):
		_http_request.request_completed.disconnect(_on_public_ip_response)
	_http_request.request_completed.connect(_on_public_ip_response, CONNECT_ONE_SHOT)
	var req_err = _http_request.request(PUBLIC_IP_SERVICE)
	if req_err != OK:
		invite_code_ready.emit("")


func _on_public_ip_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		invite_code_ready.emit("")
		return
	var ip = body.get_string_from_utf8().strip_edges()
	if ip == "" or ip.count(".") != 3:
		invite_code_ready.emit("")
		return
	invite_code_ready.emit(_encode_ip_port(ip, GAME_PORT))


func _encode_ip_port(ip: String, port: int) -> String:
	var parts = ip.split(".")
	if parts.size() != 4:
		return ""
	var bytes := PackedByteArray()
	for p in parts:
		bytes.append(int(p) & 0xFF)
	bytes.append((port >> 8) & 0xFF)
	bytes.append(port & 0xFF)
	return bytes.hex_encode().to_upper()


# Joining
func join_with_code(code: String) -> bool:
	code = code.strip_edges().to_upper()
	if code.length() != 12:
		return false
	var bytes := code.hex_decode()
	if bytes.size() != 6:
		return false
	var ip := "%d.%d.%d.%d" % [bytes[0], bytes[1], bytes[2], bytes[3]]
	var port := (bytes[4] << 8) | bytes[5]
	return join_ip(ip, port)


func join_ip(ip: String, port: int) -> bool:
	_close_existing_peer()
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		peer = null
		return false
	multiplayer.multiplayer_peer = peer
	is_host = false
	remote_peer_id = -1
	return true


# LAN quick match (broadcast discovery)
# Every device that presses "Quick Match" both hosts a game AND
# broadcasts/listens for other seekers on the LAN broadcast address.
# If two devices hear each other at once, the one with the
# lexicographically smaller invite code connects to the other, to
# avoid both sides trying to connect to each other simultaneously.
func start_quick_match(profile: Dictionary) -> String:
	local_profile = profile
	var code = host_game()
	if code == "":
		return ""
	_my_quick_code = code
	hosting_open_lobby = true
	seeking_match = true
	_broadcast_timer = 0.0

	udp_discovery = PacketPeerUDP.new()
	udp_discovery.set_broadcast_enabled(true)
	var err = udp_discovery.bind(DISCOVERY_PORT)
	if err != OK:
		push_warning("NetworkManager: could not bind discovery port (err %d)" % err)
	return code


func stop_matchmaking() -> void:
	seeking_match = false
	hosting_open_lobby = false
	if udp_discovery:
		udp_discovery.close()
		udp_discovery = null


func _broadcast_seek() -> void:
	if not udp_discovery:
		return
	var msg = {"type": "seek", "name": local_profile.get("name", ""), "elo": local_profile.get("elo", 1200)}
	udp_discovery.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	udp_discovery.put_packet(JSON.stringify(msg).to_utf8_buffer())


func _poll_discovery() -> void:
	while udp_discovery.get_available_packet_count() > 0:
		var pkt = udp_discovery.get_packet()
		var sender_ip = udp_discovery.get_packet_ip()
		var data = JSON.parse_string(pkt.get_string_from_utf8())
		if typeof(data) != TYPE_DICTIONARY:
			continue

		if data.get("type", "") == "seek" and hosting_open_lobby:
			var reply = {
				"type": "offer",
				"name": local_profile.get("name", ""),
				"elo": local_profile.get("elo", 1200),
				"code": _my_quick_code,
			}
			udp_discovery.set_dest_address(sender_ip, DISCOVERY_PORT)
			udp_discovery.put_packet(JSON.stringify(reply).to_utf8_buffer())

		elif data.get("type", "") == "offer" and seeking_match:
			var other_code = str(data.get("code", ""))
			# Tiebreak: only the side with the "smaller" code initiates the
			# connection; the other side just keeps listening as host.
			if other_code != "" and other_code > _my_quick_code:
				lobby_found.emit(data)


# Connection lifecycle
func _on_peer_connected(id: int) -> void:
	remote_peer_id = id
	if is_host:
		rpc_id(id, "rpc_send_profile", local_profile)


func _on_connected_ok() -> void:
	remote_peer_id = 1
	connection_succeeded.emit()
	rpc_id(1, "rpc_send_profile", local_profile)


func _on_connection_failed() -> void:
	connection_failed.emit()


func _on_peer_disconnected() -> void:
	remote_peer_id = -1
	player_disconnected.emit()


func disconnect_game() -> void:
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	remote_peer_id = -1
	remote_profile = {}


# Gameplay sync
func send_move(from: Vector2i, to: Vector2i) -> void:
	if remote_peer_id != -1:
		rpc_id(remote_peer_id, "rpc_send_move", from.x, from.y, to.x, to.y)


func send_resign() -> void:
	if remote_peer_id != -1:
		rpc_id(remote_peer_id, "rpc_resign")


@rpc("any_peer", "reliable")
func rpc_send_profile(profile: Dictionary) -> void:
	remote_profile = profile
	player_connected.emit(profile)


@rpc("any_peer", "reliable")
func rpc_send_move(fx: int, fy: int, tx: int, ty: int) -> void:
	move_received.emit(Vector2i(fx, fy), Vector2i(tx, ty))

@rpc("any_peer", "reliable")
func rpc_resign() -> void:
	opponent_resigned.emit()
