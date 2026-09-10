extends Node

const LOG_FILE_NAME := "client_debug.log"
const LOG_FILE_PATH := "user://" + LOG_FILE_NAME

func _ready() -> void:
	DirAccess.remove_absolute(LOG_FILE_PATH)

func log_to_file(message: String) -> void:
	if NetworkManager.is_online and multiplayer.is_server(): return
	var time_stamp := Time.get_datetime_string_from_system()
	var log_entry := "[%s] %s" % [time_stamp, message]
	var file: FileAccess
	if FileAccess.file_exists(LOG_FILE_PATH):
		file = FileAccess.open(LOG_FILE_PATH, FileAccess.READ_WRITE)
		file.seek_end()
	else: file = FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)
	if not file: return
	file.store_line(log_entry)
	file.close()

const SAVE_SCENE: String = "res://ui/client_debug_save/client_debug_save.tscn"
func download_logs() -> void:
	if NetworkManager.is_online and multiplayer.is_server(): return
	if not FileAccess.file_exists(LOG_FILE_PATH):
		ConsoleManager.print_output("No logs to download yet", "shell_output", 0)
		return
	var file_dialog: FileDialog = load(SAVE_SCENE).instantiate()
	file_dialog.current_file = LOG_FILE_NAME
	# Connect signals via lambdas to automatically clean up the dialog node
	file_dialog.file_selected.connect(func(path: String):
		var err := DirAccess.copy_absolute(LOG_FILE_PATH, path)
		if err == OK: ConsoleManager.print_output("Log successfully exported to: " + path, "shell_output", 0)
		else: ConsoleManager.print_output("Failed to export log. Error code: " + str(err), "shell_error", 0)
		file_dialog.queue_free()
	)
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)
	add_child(file_dialog)
	file_dialog.popup_centered()
