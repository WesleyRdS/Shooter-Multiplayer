extends Node

signal new_server
signal remove_server

var clean_up_timer = Timer.new() #limpar servidor que esta inativo
var socket_udp = PacketPeerUDP.new()
var listen_port = Network.DEFAULT_PORT
var knows_servers = {}

export (int) var server_cleanup_threshold = 3

func _init():
	clean_up_timer.wait_time = server_cleanup_threshold
	clean_up_timer.one_shot = false
	clean_up_timer.autostart = true
	clean_up_timer.connect("timeout", self, "clean_up")
	add_child(clean_up_timer)
 

func _ready():
	knows_servers.clear()
	
	if socket_udp.listen(listen_port) != OK:
		print("GameServer LAN service: Error listening on port" + str(listen_port))
	else:
		print("GameServer LAN service: Listening on port" + str(listen_port))
	
func _process(delta):
	if socket_udp.get_available_packet_count() > 0:
		var server_ip = socket_udp.get_packet_ip()
		var server_port = socket_udp.get_packet_port()
		var array_bytes = socket_udp.get_packet() #API de baixo nivel, obteremos uma variavel de todos os bytes em um array e com isso obteremos o pacote UDP
		
		if server_ip != '' and server_port > 0:
			if  not knows_servers.has(server_ip):
				var serverMessage = array_bytes.get_string_from_ascii()
				var gameInfo = parse_json(serverMessage)
				gameInfo.ip = server_ip
				gameInfo.lastSeen = OS.get_unix_time()
				knows_servers[server_ip] = gameInfo
				emit_signal("new_server", gameInfo)
				print(socket_udp.get_packet_ip())
			else:
				var gameInfo = knows_servers[server_ip]
				gameInfo.lastSeen = OS.get_unix_time()
				
				
func clean_up():
	var now = OS.get_unix_time()
	for server_ip in knows_servers:
		var serverInfo = knows_servers[server_ip]
		if (now - serverInfo.lastSeen) > server_cleanup_threshold:
			knows_servers.erase(server_ip)
			print("Remove old server: %s" % server_ip)
			emit_signal("remove_server", server_ip)
			
func _exit_tree():
	socket_udp.close()


