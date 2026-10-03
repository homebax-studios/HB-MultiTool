@tool
extends "res://addons/hb_multitool/tools/tool_base.gd"
## Asset Browser – prohlížeč modelů, textur, scén a audia s náhledy a drag & drop.

const BrowserPanel = preload("res://addons/hb_multitool/tools/browser/browser_panel.gd")

var panel: Control


func _init() -> void:
	id = "browser"


func enable() -> void:
	panel = BrowserPanel.new(plugin)
	plugin.hub_add_tab(panel, "Browser")


func disable() -> void:
	if is_instance_valid(panel):
		plugin.hub_remove_tab(panel)
		panel.queue_free()
	panel = null


func on_setting_changed(_key: String) -> void:
	if is_instance_valid(panel):
		panel.apply_settings(true)
