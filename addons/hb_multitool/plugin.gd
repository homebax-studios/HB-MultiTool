@tool
extends EditorPlugin
## HB MultiTool – Homebax Studios
## Hlavní skript pluginu: spravuje nástroje, sdílený spodní panel a okno nastavení.

const HBSettings = preload("res://addons/hb_multitool/settings/hb_settings.gd")
const SettingsDialog = preload("res://addons/hb_multitool/settings/settings_dialog.gd")

const BrowserTool = preload("res://addons/hb_multitool/tools/browser/browser_tool.gd")
const DebugTool = preload("res://addons/hb_multitool/tools/debug/debug_tool.gd")
const TodoTool = preload("res://addons/hb_multitool/tools/todo/todo_tool.gd")
const RenameTool = preload("res://addons/hb_multitool/tools/rename/rename_tool.gd")
const TransformTool = preload("res://addons/hb_multitool/tools/transform/transform_tool.gd")
const NotesTool = preload("res://addons/hb_multitool/tools/notes/notes_tool.gd")
const AutosaveTool = preload("res://addons/hb_multitool/tools/autosave/autosave_tool.gd")

const MENU_NAME := "HB MultiTool – Nastavení…"
const PROBE_NAME := "HBDebugProbe"

var tools: Dictionary = {}          # id -> nástroj
var hub: TabContainer               # sdílený spodní panel (záložky nástrojů)
var _hub_in_panel := false
var _dialog: AcceptDialog


func _enter_tree() -> void:
	HBSettings.ensure_defaults()

	hub = TabContainer.new()
	hub.name = "HB MultiTool"
	hub.custom_minimum_size = Vector2(0, 280)

	tools = {
		"browser": BrowserTool.new(),
		"debug": DebugTool.new(),
		"todo": TodoTool.new(),
		"rename": RenameTool.new(),
		"transform": TransformTool.new(),
		"notes": NotesTool.new(),
		"autosave": AutosaveTool.new(),
	}
	for id in tools:
		tools[id].setup(self)

	_dialog = SettingsDialog.new()
	EditorInterface.get_base_control().add_child(_dialog)
	_dialog.setting_changed.connect(_on_setting_changed)

	add_tool_menu_item(MENU_NAME, _open_settings)

	for id in tools:
		refresh_tool(id)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_NAME)
	for id in tools:
		var t = tools[id]
		if t.active:
			t.shutdown()
			t.active = false
	if _hub_in_panel:
		remove_control_from_bottom_panel(hub)
		_hub_in_panel = false
	if is_instance_valid(hub):
		hub.queue_free()
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	tools.clear()


## Volá se při odinstalaci/vypnutí pluginu v Project Settings.
func _disable_plugin() -> void:
	if ProjectSettings.has_setting("autoload/" + PROBE_NAME):
		remove_autoload_singleton(PROBE_NAME)


func _open_settings() -> void:
	_dialog.open()


# --------------------------------------------------------------------------
# Veřejné API pro nástroje
# --------------------------------------------------------------------------

## Zapne/vypne nástroj podle aktuálního nastavení.
func refresh_tool(id: String) -> void:
	if not tools.has(id):
		return
	var t = tools[id]
	var want := HBSettings.is_enabled(id)
	if want and not t.active:
		t.enable()
		t.active = true
	elif not want and t.active:
		t.disable()
		t.active = false


func hub_add_tab(c: Control, title: String) -> void:
	c.name = title
	hub.add_child(c)
	_update_hub()


func hub_remove_tab(c: Control) -> void:
	if is_instance_valid(c) and c.get_parent() == hub:
		hub.remove_child(c)
	_update_hub()


func _update_hub() -> void:
	var has_tabs := hub.get_child_count() > 0
	if has_tabs and not _hub_in_panel:
		add_control_to_bottom_panel(hub, "HB MultiTool")
		_hub_in_panel = true
	elif not has_tabs and _hub_in_panel:
		remove_control_from_bottom_panel(hub)
		_hub_in_panel = false


# --------------------------------------------------------------------------

func _on_setting_changed(key: String) -> void:
	var id := key.get_slice("/", 0)
	if not tools.has(id):
		return
	if key.ends_with("/enabled"):
		refresh_tool(id)
	elif tools[id].active:
		tools[id].on_setting_changed(key)
