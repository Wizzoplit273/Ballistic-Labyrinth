class_name WebLineEdit
extends LineEdit

@export var enable_web_paste_prompt: bool = true

func _ready() -> void:
	if not enable_web_paste_prompt: return
	if not OS.has_feature("web"): return
	var menu: PopupMenu = get_menu()
	if menu.id_pressed.is_connected(_on_context_menu_item_pressed):
		menu.id_pressed.disconnect(_on_context_menu_item_pressed)
	menu.id_pressed.connect(_on_context_menu_item_pressed)

func _gui_input(event: InputEvent) -> void:
	if enable_web_paste_prompt and OS.has_feature("web"):
		if event is InputEventKey and event.pressed and not event.echo:
			var is_shortcut: bool = (event.ctrl_pressed or event.meta_pressed) and event.keycode == KEY_V
			if is_shortcut:
				accept_event()
				_trigger_web_paste_prompt()
				return
	#super._gui_input(event)

const LINEEDIT_PASTE_ID: int = 2 ## alias
func _on_context_menu_item_pressed(id: int) -> void:
	if id == LINEEDIT_PASTE_ID and enable_web_paste_prompt and OS.has_feature("web"):
		_trigger_web_paste_prompt()
	else:
		get_menu().activate_item(get_menu().get_item_index(id))

func _trigger_web_paste_prompt() -> void:
	var js_prompt_result: Variant = JavaScriptBridge.eval('prompt("Paste your text here:");')
	if js_prompt_result == null: return
	var pasted_text: String = str(js_prompt_result)
	if pasted_text.is_empty(): return
	_insert_pasted_text(pasted_text)

func _insert_pasted_text(pasted_text: String) -> void:
	if has_selection(): deselect()
	var caret_pos: int = get_caret_column()
	text = text.insert(caret_pos, pasted_text)
	set_caret_column(caret_pos + pasted_text.length())
	text_changed.emit(text)
