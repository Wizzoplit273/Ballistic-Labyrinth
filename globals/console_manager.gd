extends Node

var registry: Array[Dictionary] = []

enum SHELL_CONTEXT {ANY, OFFLINE, CLIENT, ADMIN, HOST}

func _enter_tree() -> void:
	register_command(
		["help"],
		cmd_help,
		"shows available commands",
		SHELL_CONTEXT.ANY
	)

func register_command(
	aliases: PackedStringArray,
	callback: Callable,
	description: String,
	shell_context: SHELL_CONTEXT) -> void:
	registry.append({
		"aliases": aliases,
		"callback": callback,
		"description": description,
		"shell_context": shell_context
	})

func process_raw_string(raw_text: String, pid: int) -> String:
	if pid < 0: return ""
	if NetworkManager.is_online and pid == 0: return ""
	#if NetworkManager.is_online and not multiplayer.is_server() and pid != 1: return ""
	var text: String = raw_text.strip_edges()
	if text.begins_with("/"): text = text.substr(1)
	text = text.to_lower()
	var tokens: PackedStringArray = text.split(" ", false)
	var invoked: String = tokens[0]
	tokens.remove_at(0)
	var active_cmd: Dictionary = {}
	for cmd: Dictionary in registry:
		if invoked in cmd["aliases"]:
			active_cmd = cmd
			break
	if active_cmd.is_empty(): return "command not found: %s" % invoked
	var flags: Array[Dictionary] = []
	var args: PackedStringArray = []
	for token: String in tokens:
		if token.begins_with("-"): flags.append(token)
		else: 					   args.append(token)
	return active_cmd["callback"].call(args, flags, pid)

func cmd_help(args: PackedStringArray, flags: Dictionary, pid: int) -> String:
	if args.is_empty() and flags.is_empty():
		return ""
	return ""
