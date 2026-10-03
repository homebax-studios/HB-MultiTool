@tool
extends "res://addons/hb_multitool/tools/tool_base.gd"
## Debug okno – FPS, zatížení, CPU/GPU informace a statistiky běžící hry.

const HBSettings = preload("res://addons/hb_multitool/settings/hb_settings.gd")
const DebugWindow = preload("res://addons/hb_multitool/tools/debug/debug_window.gd")
const DebugBridge = preload("res://addons/hb_multitool/tools/debug/debug_bridge.gd")

const PROBE_NAME := "HBDebugProbe"
const PROBE_PATH := "res://addons/hb_multitool/tools/debug/debug_probe.gd"

var window: Window
var bridge: EditorDebuggerPlugin


func _init() -> void:
	id = "debug"


func enable() -> void:
	window = DebugWindow.new()
	window.closed_by_user.connect(_on_window_closed)
	EditorInterface.get_base_control().add_child(window)

	bridge = DebugBridge.new()
	bridge.stats_received.connect(window.on_game_stats)
	bridge.session_changed.connect(window.on_game_state)
	plugin.add_debugger_plugin(bridge)

	window.show_window()
	_sync_probe()


func disable() -> void:
	if bridge:
		plugin.remove_debugger_plugin(bridge)
		bridge = null
	if is_instance_valid(window):
		window.queue_free()
	window = null
	_remove_probe()


## Při zavření editoru autoload neodstraňujeme (jinak by se zbytečně přepisoval project.godot).
func shutdown() -> void:
	if bridge:
		plugin.remove_debugger_plugin(bridge)
		bridge = null
	if is_instance_valid(window):
		window.queue_free()
	window = null


func on_setting_changed(key: String) -> void:
	if is_instance_valid(window):
		window.apply_settings()
	if key == "debug/show_game_stats":
		_sync_probe()


func _on_window_closed() -> void:
	# Uživatel zavřel okno křížkem -> nástroj se vypne i v nastavení.
	HBSettings.set_value("debug/enabled", false)
	plugin.refresh_tool.call_deferred("debug")


func _sync_probe() -> void:
	var want := bool(HBSettings.get_value("debug/show_game_stats"))
	var has := ProjectSettings.has_setting("autoload/" + PROBE_NAME)
	if want and not has:
		plugin.add_autoload_singleton(PROBE_NAME, PROBE_PATH)
	elif not want and has:
		plugin.remove_autoload_singleton(PROBE_NAME)


func _remove_probe() -> void:
	if ProjectSettings.has_setting("autoload/" + PROBE_NAME):
		plugin.remove_autoload_singleton(PROBE_NAME)
