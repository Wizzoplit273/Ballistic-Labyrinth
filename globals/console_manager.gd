extends Node

var registry: Array[Dictionary] = []

const ATTRIBUTE_ALIASES: Dictionary = {
	"name": ["name", "username", "user", "n", "u"],
	"admin": ["admin", "is_admin", "a"],
	"color": ["color", "colour", "rgb", "c"],
	"kills": ["kills", "kill", "k"],
	"score": ["score", "win", "wins", "s", "w"]
}

## confirm("yes") command isn't registered and stores a command in a temporary buffer
func _enter_tree() -> void:
	register_command(
		["help"],
		"shows available commands",
		false,
		true
	)
	register_command(
		["connect", "join"],
		"connects to a server using an IP address",
		false,
		true
	)
	register_command(
		["disconnect", "leave"],
		"leaves from the currently connected server",
		false,
		true
	)
	register_command(
		["start_server", "open_server"],
		"configures this game instance as a server",
		true,
		true
	)
	register_command(
		["close_server", "end_server", "stop_server", "disconnect_server"],
		"closes the server(host only)",
		true,
		true
	)
	register_command(
		["get"],
		"get attributes from yourself or a certain player",
		false,
		true
	)
	register_command(
		["set"],
		"set one of your attributes to a specific value",
		false,
		false
	)
	register_command(
		["assign"],
		"modify any attribute from any session except admin role",
		true,
		false
	)
	register_command(
		["bot", "ai"],
		"create or delete bots",
		true,
		false
	)
	register_command( # temporary quick configuration
		["chat_resize"],
		"resize chat text to a specific size",
		false,
		true
	)

func register_command(
	aliases: PackedStringArray,
	description: String,
	requires_admin: bool,
	is_local: bool) -> void:
	registry.append({
		"aliases": aliases,
		"description": description,
		"requires_admin": requires_admin,
		"is_local": is_local
	})

func print_output(text: String, pid: int = 0) -> void:
	if pid <= 0 or not NetworkManager.is_online or pid == multiplayer.get_unique_id():
		ChatManager.send_local_message(text, "shell")
	else: ChatManager.send_local_message.rpc_id(pid, text, "shell")

func execute_raw_string(raw_text: String) -> void:
	var text: String = raw_text.strip_edges()
	if text.begins_with("/"): text = text.substr(1)
	var tokens: PackedStringArray = text.split(" ", false)
	var invoked: String = ""
	if not text.is_empty(): invoked = tokens[0]
	if is_confirming_command:
		if invoked == "yes": execute_cmd(confirmed_cmd, confirmed_args, confirmed_flags)
		else: print_output("command aborted")
		return
	tokens.remove_at(0)
	var active_cmd: Dictionary = {}
	for cmd: Dictionary in registry:
		if invoked in cmd["aliases"]:
			active_cmd = cmd
			break
	if active_cmd.is_empty():
		print_output("command not found: %s" % invoked)
		return
	## temporary setup for testing the game
	## cmd_start_server isn't shown in help list but can be used nonetheless
	## in the future, client-only exports won't have cmd_start_server and cmd_close_server
	if active_cmd["requires_admin"] and active_cmd["aliases"][0] != "start_server":
		if not NetworkManager.is_online:
			print_output("command not found: %s" % invoked)
			return
		if SessionManager.data.get(multiplayer.get_unique_id()).get("admin") == false:
			print_output("command not found: %s" % invoked)
			return
	var flags: Array[PackedStringArray] = []
	var args: PackedStringArray = []
	var is_previous_token_argument_flag: bool = false
	for token: String in tokens:
		if token.begins_with("-"):
			if is_previous_token_argument_flag:
				print_output("invalid flag syntax: expected argument after = flag")
				return
			flags.append([token])
		elif token.begins_with("="):
			if is_previous_token_argument_flag:
				print_output("invalid flag syntax: expected argument after = flag")
				return
			flags.append([token])
			is_previous_token_argument_flag = true
		elif is_previous_token_argument_flag: flags[-1].append(token)
		else: args.append(token)
	execute_cmd(active_cmd, args, flags)

var is_confirming_command: bool = false
var confirmed_cmd: Dictionary = {}
var confirmed_args: PackedStringArray = []
var confirmed_flags: Array[PackedStringArray] = []
func confirm_cmd(cmd: Dictionary, args: PackedStringArray, flags: Array[PackedStringArray], pid: int = 0) -> void:
	is_confirming_command = true
	print_output(
		"are you sure you want to execute this command? " + cmd["aliases"][0] + "\n" +
		"use the \"yes\" command to confirm or cancel by typing a dummy command(one / suffices)\n",
		pid
	)
	confirmed_cmd = cmd
	confirmed_args = args
	confirmed_flags = flags

## wrapper function for commands that require confirmation
## to make a command cmd_foo confirm-only, this line is appended right before the actual
## command execution in the function body:
## if not is_cmd_confirmed(cmd_foo, args, flags): return
func is_cmd_confirmed(callback: Callable, args: PackedStringArray, flags: Array[PackedStringArray], pid: int = 0) -> bool:
	if is_confirming_command:
		is_confirming_command = false
		return true
	for cmd: Dictionary in registry:
		if cmd["callback"] != callback: continue
		confirm_cmd(cmd, args, flags, pid)
		return false
	return false

func execute_cmd(cmd: Dictionary, args: PackedStringArray, flags: Array[PackedStringArray]) -> void:
	if not NetworkManager.is_online or cmd["is_local"]:
		Callable(self, "cmd_" + cmd["aliases"][0]).call(args, flags)
		return
	if NetworkManager.is_online and multiplayer.is_server():
		request_network_cmd(cmd, args, flags)
		return
	request_network_cmd.rpc_id(1, cmd, args, flags)

@rpc("any_peer", "reliable")
func request_network_cmd(cmd: Dictionary, args: PackedStringArray, flags: Array[PackedStringArray]) -> void:
	var pid: int = multiplayer.get_remote_sender_id()
	if NetworkManager.is_online and not multiplayer.is_server(): return
	if pid == 0 and multiplayer.is_server(): pid = 1
	if not cmd in registry: return
	if cmd["is_local"]: return
	if cmd["requires_admin"] and not SessionManager.data[pid]["admin"]: return
	Callable(self, "cmd_" + cmd["aliases"][0]).call(args, flags, pid)

func cmd_help(args: PackedStringArray, _flags: Array[PackedStringArray], _pid: int = 0) -> void:
	var command_list: String = ""
	if args.is_empty():
		for command: Dictionary in registry:
			var is_admin: bool = false
			if NetworkManager.is_online: is_admin = SessionManager.data.get(multiplayer.get_unique_id()).get("admin")
			if command["requires_admin"] == true and not is_admin: continue
			var length: int = command["aliases"].size()
			var index: int = 0
			for alias: String in command["aliases"]:
				if index == length - 1: command_list += alias
				else: command_list += alias + "/"
				index += 1
			command_list += ": " + command["description"] + "\n"
		print_output(command_list)
		return
	for command: Dictionary in registry:
		if not args[0] in command["aliases"]: continue
		var length: int = command["aliases"].size()
		var index: int = 0
		for alias: String in command["aliases"]:
			if index == length - 1: command_list += alias
			else: command_list += alias + "/"
			index += 1
		command_list += ": " + command["description"] + "\n"
		print_output(command_list)
		return
	print_output("command not found: %s" % args[0])

func cmd_connect(args: PackedStringArray, flags: Array[PackedStringArray], _pid: int = 0) -> void:
	if NetworkManager.is_online:
		print_output("already online/connected")
		return
	if args.is_empty() and flags.is_empty():
		print_output("provide an IP address to connect to")
		return
	if not args.is_empty() and not flags.is_empty():
		print_output("invalid args/flag syntax: either provide IP directly or via ==ip flag")
		return
	if not args.is_empty():
		NetworkManager.start_client(args[0])
		return
	for flag: PackedStringArray in flags:
		if flag[0] != "==ip": continue
		NetworkManager.start_client(flag[1])
		return
	print_output("invalid flag syntax: provide IP via ==ip flag")

func cmd_disconnect(args: PackedStringArray, flags: Array[PackedStringArray], _pid: int = 0) -> void:
	if not NetworkManager.is_online:
		print_output("already offline/disconnected")
		return
	if multiplayer.is_server():
		print_output("can't disconnect with this command. Consider using close_server instead")
		return
	if not is_cmd_confirmed(cmd_disconnect, args, flags): return
	NetworkManager.disconnect_from_server()

func cmd_start_server(_args: PackedStringArray, _flags: Array[PackedStringArray], _pid: int = 0) -> void:
	if NetworkManager.is_online:
		print_output("server is already started")
		return
	NetworkManager.start_server()

func cmd_close_server(args: PackedStringArray, flags: Array[PackedStringArray], pid: int = 0) -> void:
	if not NetworkManager.is_online:
		print_output("already offline/disconnected")
		return
	if pid <= 0:
		print_output("cmd_close_server: invalid peer id sender")
		return
	if pid != 1 or not multiplayer.is_server():
		print_output("permission denied: only host can close the server", pid)
		return
	if not is_cmd_confirmed(cmd_close_server, args, flags, pid): return
	is_confirming_command = false
	NetworkManager.close_server()

func cmd_get(args: PackedStringArray, flags: Array[PackedStringArray], _pid: int = 0) -> void:
	if args.is_empty():
		print_output("usage: get PROPERTY [pid/=u NAME]")
		return
	var target_sid: int = 0
	if NetworkManager.is_online: target_sid = multiplayer.get_unique_id()
	if flags.is_empty():
		if args.size() > 1: target_sid = SessionManager.decode_session_id(args[1])
	else:
		var flag: PackedStringArray = []
		const ALIASES: PackedStringArray = ["=u", "=n", "==name", "==username", "==user"]
		for f: PackedStringArray in flags:
			if f[0] in ALIASES:
				flag = f
				break
		if flag.is_empty():
			print_output("usage: get PROPERTY [pid/=u NAME]")
			return
		var match_count: int = 0
		for key: int in SessionManager.data.keys():
			if match_count == 1 and key == 0: continue
			if SessionManager.data[key].get("name") != flag[1]: continue
			target_sid = key
			match_count += 1
		if match_count == 0:
			print_output("couldn't get player with name %s" % flag[1])
			return
		if match_count > 1:
			print_output("multiple players have the same name, consider searching by sid")
			return
	for key: PackedStringArray in ATTRIBUTE_ALIASES.values():
		if not args[0] in key: continue
		print_output(key[0] + ": " + SessionManager.data[target_sid].get(key[0]))
		return

func cmd_set(args: PackedStringArray, _flags: Array[PackedStringArray], pid: int = 0) -> void:
	if args.is_empty():
		print_output("usage: set PROPERTY VALUE", pid)
		return
	if args.size() < 2:
		print_output("provide a value to set your attribute to", pid)
		return
	var property: String = ""
	for value: PackedStringArray in ATTRIBUTE_ALIASES.values():
		if not args[0] in value: continue
		property = value[0]
		break
	if property.is_empty():
		print_output("nonexistent attribute %s" % args[0], pid)
		return
	const PROHIBITED = ["admin", "kills", "score"]
	if property in PROHIBITED:
		print_output("nonexistent attribute %s" % args[0], pid)
		return
	SessionManager.assign_from_str(pid, args[0], args[1])

func cmd_assign(args: PackedStringArray, flags: Array[PackedStringArray], pid: int = 0) -> void:
	if args.is_empty():
		print_output("usage: assign PROPERTY VALUE [=s/==sid SID]", pid)
		return
	if args.size() < 2:
		print_output("usage: assign PROPERTY VALUE [=s/==sid SID]", pid)
		return
	var property: String = ""
	for key: PackedStringArray in ATTRIBUTE_ALIASES.values():
		if not args[0] in key: continue
		property = key[0]
		break
	if property.is_empty():
		print_output("nonexistent attribute %s" % args[0])
		return
	if property == "admin":
		if pid <= 0:
			print_output("cmd_assign: invalid peer id sender")
			return
		if pid != 1 or not multiplayer.is_server():
			print_output("permission denied: only host can change admin permissions", pid)
			return
	var target_sid: int = multiplayer.get_unique_id()
	for flag: PackedStringArray in flags:
		if flag[0] != "=s" and flag[0] != "==sid": continue
		if flag.size() <= 1:
			print_output("provide an sid to modify its attribute", pid)
			return
		target_sid = SessionManager.decode_session_id(flag[1])
		break
	if property == "admin" and target_sid == 1:
		print_output("host can't change its own admin role")
		return
	if not target_sid in SessionManager.data.keys():
		print_output("player with SID = " +
		SessionManager.encode_session_id(target_sid) +
		" doesn't exist")
		return
	SessionManager.assign_from_str(target_sid, args[0], args[1])

func cmd_bot(args: PackedStringArray, _flags: Array[PackedStringArray], pid: int = 0) -> void:
	if args.is_empty():
		print_output("usage: bot [add [COUNT]]/[delete sid/count SID/[COUNT]", pid)
		return
	const ALIASES_1 = ["add", "create"]
	if args[0] in ALIASES_1: # BOT add ...
		var count: int = 1
		if args.size() >= 2: count = abs(int(args[1])) # BOT add 1 [2] [3] [4] ...
		SessionManager.add_bot(count)
		return
	const ALIASES_2 = ["remove", "delete", "erase"]
	if not args[0] in ALIASES_2: # BOT remove ...
		print_output("invalid first argument. Should be add or delete", pid)
		return
	if args.size() <= 1: # BOT remove {missing}
		print_output("delete bot by sid or count", pid)
		return
	if args[1] == "sid": # BOT remove sid ...
		if args.size() <= 2: # BOT remove sid {missing}
			print_output("can't delete bot with no SID", pid)
			return
		var sid: int = SessionManager.decode_session_id(args[2])
		sid = -abs(sid)
		if not SessionManager.data.has(sid):
			print_output("bot with SID = %s doesn't exist" % args[2], pid)
			return
		SessionManager.remove_bot_sid(sid)
		return
	const ALIASES_3 = ["count", "number", "c", "num", "n"]
	if args[1] in ALIASES_3:
		var count: int = 1
		if args.size() >= 3: count = abs(int(args[2])) # BOT remove count 1 [2] [3] [4] ...
		SessionManager.remove_bot_count(count)
		return
	print_output("delete bot by sid or count", pid)

# temporary quick configuration
func cmd_chat_resize(args: PackedStringArray, _flags: Array[PackedStringArray], _pid: int = 0) -> void:
	if not UIManager.is_ui_configured:
		print_output("no chat menu connected")
		return
	if args.is_empty():
		print_output("provide a font size")
		return
	UIManager.chat_menu_node.set_font_size(int(args[0]))
