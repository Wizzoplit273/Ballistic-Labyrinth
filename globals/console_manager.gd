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
	register_command(
		["start_game", "play", "start"],
		"starts the game",
		true,
		false
	)

## first string in alias list corresponds with a callable's name(ex: "connect" corresponds with cmd_connect)
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

## CHANNELS
## --- system: public system messages
## --- shell_execute: output of a command(success or error message)
## --- shell_input: rewrites input command(only for configured chat menu UI)
## --- admin: staff-only system messages
func print_output(text: String, pid: int = 0, channel: String = "shell_output") -> void:
	if pid < 0: return
	if channel == "admin":
		if not multiplayer.is_server(): return
		ChatManager.send_local_message(text, "admin")
		if pid == 0:
			for admin_id: int in SessionManager.data.keys():
				if admin_id <= 1: continue
				if SessionManager.data[admin_id].get("admin") != true: continue
				ChatManager.send_local_message.rpc_id(admin_id, text, "admin")
			return
		if pid == 1: return
		if SessionManager.data[pid].get("admin") != true: return
		ChatManager.send_local_message.rpc_id(pid, text, "admin")
		return
	if pid == 0 or not NetworkManager.is_online or pid == multiplayer.get_unique_id():
		ChatManager.send_local_message(text, channel)
	else: ChatManager.send_local_message.rpc_id(pid, text, channel)

func split_respecting_quotes(text: String) -> Array[String]:
	var regex := RegEx.new()
	regex.compile('"[^"]*"|\'[^\']*\'|\\S+')
	var result: Array[String] = []
	for item in regex.search_all(text):
		result.append(item.get_string())
	return result

func execute_raw_string(raw_text: String) -> void:
	var text: String = raw_text.strip_edges()
	if UIManager.is_ui_configured: ChatManager.send_local_message(text, "shell_input")
	if text.begins_with("/"): text = text.substr(1)
	var tokens: PackedStringArray = split_respecting_quotes(text)
	var invoked: String = ""
	if not text.is_empty(): invoked = tokens[0]
	if is_confirming_command:
		if invoked == "yes": execute_cmd(confirmed_cmd, confirmed_args, confirmed_flags)
		else: print_output("command aborted")
		is_confirming_command = false
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
		if token.begins_with("\"") and token.ends_with("\""):
			token = token.trim_prefix("\"").trim_suffix("\"")
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
		if "cmd_" + cmd["aliases"][0] != callback.get_method(): continue
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

## if y entry is < 0, then x entry refers to a number of SIDs(no specific SIDs)
## if y entry is = 0, then x entry refers to a target SID
## if y entry is = 1, then it's a silent exception
## if y entry is > 2, then it prints the exception
func get_session_reference_from_flags(flags: Array[PackedStringArray], pid: int = 0) -> Vector2i:
	var result: int = multiplayer.get_unique_id()
	const COUNT_FLAGS = ["=c", "==count", "==num", "==number"]
	const SID_FLAGS = ["=s", "==sid"]
	const NAME_FLAGS = ["=u", "==username", "=n", "==name"]
	for flag: PackedStringArray in flags:
		if not flag[0] in COUNT_FLAGS and not flag[0] in SID_FLAGS and not flag[0] in NAME_FLAGS: continue
		if flag[0] in COUNT_FLAGS:
			if flag.size() <= 1:
				print_output("provide a count integer to ==count", pid)
				return Vector2i(2, 2)
			result = abs(int(flag[1]))
			result = min(result, SessionManager.data.size())
			return Vector2i(result, -1)
		if flag[0] in SID_FLAGS:
			if flag.size() <= 1:
				print_output("provide an sid to ==sid to filter session ids", pid)
				return Vector2i(2, 2)
			result = SessionManager.decode_session_id(flag[1])
			if not result in SessionManager.data.keys():
				print_output("session with ID = " + flag[1] + " doesn't exist", pid)
				return Vector2i(2, 2)
			return Vector2i(result, 0)
		# flag[0] in NAME_FLAGS:
		if flag.size() <= 1:
			print_output("provide a name to ==name to filter session ids", pid)
			return Vector2i(2, 2)
		var match_count: int = 0
		for key: int in SessionManager.data.keys():
			if match_count == 1 and key == 0: continue
			if SessionManager.data[key].get("name") != flag[1]: continue
			result = key
			match_count += 1
			if match_count >= 2: break
		if match_count == 0:
			print_output("session with name = \"%s\" doesn't exist" % flag[1], pid)
			return Vector2i(2, 2)
		if match_count > 1:
			print_output("multiple sessions have the same name, consider filtering by sid", pid)
			return Vector2i(2, 2)
		return Vector2i(result, 0)
	return Vector2i(1, 1)

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
	if pid < 0:
		print_output("cmd_close_server: invalid peer id sender")
		return
	if not multiplayer.is_server():
		print_output("permission denied: only host can close the server", pid)
		return
	if not is_cmd_confirmed(cmd_close_server, args, flags, pid): return
	is_confirming_command = false
	NetworkManager.close_server()

func cmd_get(args: PackedStringArray, flags: Array[PackedStringArray], _pid: int = 0) -> void:
	if args.is_empty():
		print_output("usage: get PROPERTY [SID/=s SID/=u NAME]")
		return
	var target_sid: int = 0
	if NetworkManager.is_online: target_sid = multiplayer.get_unique_id()
	if flags.is_empty():
		if args.size() > 1: target_sid = SessionManager.decode_session_id(args[1])
	else:
		var filter: Vector2i = get_session_reference_from_flags(flags)
		if filter[1] >= 2: return
		if filter[1] == 1: target_sid = multiplayer.get_unique_id()
		if filter[1] == 0: target_sid = filter[0]
		if filter[1] < 0:
			print_output("can't get attributes from a bulk number")
			return
	for key: PackedStringArray in ATTRIBUTE_ALIASES.values():
		if not args[0] in key: continue
		var result: String = str(SessionManager.data[target_sid].get(key[0]))
		print_output(key[0] + ": " + result)
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
	var target_sid: int = 0
	var filter: Vector2i = get_session_reference_from_flags(flags, pid)
	if filter[1] >= 2: return
	if filter[1] == 1: target_sid = multiplayer.get_unique_id()
	if filter[1] == 0: target_sid = filter[0]
	if filter[1] < 0:
		print_output("can't get attributes from a bulk number", pid)
		return
	if filter[1] == 1: target_sid = multiplayer.get_unique_id()
	if property == "admin":
		if target_sid <= 0:
			print_output("can't modify admin permissions for bots")
			return
		if target_sid == 1:
			print_output("host can't change its own admin role")
			return
	if target_sid <= 0 and property == "personality":
		print_output("can't change bot personality using the assign command. Consider using bot set instead")
		return
	var old_admin_value: bool = SessionManager.data[target_sid]["admin"]
	SessionManager.assign_from_str(target_sid, args[0], args[1])
	if property != "admin": return
	var current_admin_value: bool = args[1] == "true"
	var has_admin_changed: bool = current_admin_value != old_admin_value
	if not has_admin_changed:
		if current_admin_value == true: print_output("this player is already an admin", pid)
		else: print_output("this player already doesn't have admin", pid)
		return
	if SessionManager.data[target_sid]["admin"] == true:
		if target_sid <= 0: return
		print_output("!!! you have been granted admin permissions", target_sid)
		return
	if target_sid <= 0: return
	print_output("!!! you are no longer an admin", target_sid)

func cmd_bot(args: PackedStringArray, flags: Array[PackedStringArray], pid: int = 0) -> void:
	if args.is_empty():
		print_output(
			"usage: bot [add [COUNT]]/[delete =s/=c/=n SID/COUNT/NAME]/[set =s/=n SID/NAME \"trait\" VALUE]",
			pid)
		return
	const ALIASES_1 := ["add", "create"]
	const ALIASES_2 := ["remove", "delete", "erase"]
	const ALIASES_3 := ["set", "assign", "set_personality", "assign_personality", "set_trait", "assign_trait", "trait"]
	if args[0] in ALIASES_1: # BOT add ...
		var count1: int = 1
		if args.size() >= 2: count1 = abs(int(args[1])) # BOT add 1 [2] [3] [4] ...
		SessionManager.add_bot.rpc(count1)
		return
	elif args[0] in ALIASES_2: # BOT remove ...
		var filter: Vector2i = get_session_reference_from_flags(flags, pid)
		if filter[1] >= 2: return
		if filter[1] == 1:
			print_output("usage: bot delete =s/=c/=n SID/COUNT/NAME", pid)
			return
		if filter[1] == 0:
			var sid: int = filter[0]
			sid = -abs(sid)
			SessionManager.remove_bot_sid(sid)
			return
	elif args[0] in ALIASES_3: # BOT set ...
		if args.size() < 3: # BOT set ?"trait"? ?VALUE?
			print_output("provide a bot trait and modify it to a value")
			return
		var filter: Vector2i = get_session_reference_from_flags(flags, pid)
		var sid: int
		if filter[1] >= 2: return
		if filter[1] == 1:
			print_output("usage: bot set =s/=n SID/NAME \"trait\" VALUE", pid)
			return
		if filter[1] == 0:
			sid = filter[0]
			sid = -abs(sid)
		if filter[1] <= -1:
			print_output("can't refer to bots using a count integer when modifying traits", pid)
			return
		var ATTRIBUTE: String = args[1]
		var VALUE: String = args[2]
		if not SessionManager.data[sid]["personality"].has(ATTRIBUTE):
			var ERROR: String = "nonexistent trait \"" + ATTRIBUTE + "\"\n"
			var HELP: String = "available bot traits:\n"
			var traits: String = ""
			for trait_attribute: String in SessionManager.data[sid]["personality"].keys():
				traits += trait_attribute + "\n"
			print_output(ERROR + HELP + traits, pid)
			return
		SessionManager.set_bot_trait_from_str(sid, ATTRIBUTE, VALUE)
		return
	else: # BOT ...
		print_output("invalid first argument. Should be add, delete or set", pid)
		return

# temporary quick configuration
func cmd_chat_resize(args: PackedStringArray, _flags: Array[PackedStringArray], _pid: int = 0) -> void:
	if not UIManager.is_ui_configured:
		print_output("no chat menu connected")
		return
	if args.is_empty():
		print_output("provide a font size")
		return
	UIManager.chat_menu_node.set_font_size(int(args[0]))

func cmd_start_game(_args: PackedStringArray, _flags: Array[PackedStringArray], pid: int = 0) -> void:
	if pid == 0 or pid == 1: IngameManager.start_game()
	else: IngameManager.start_game.rpc_id(1)
