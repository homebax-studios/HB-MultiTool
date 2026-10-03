@tool
extends "res://addons/hb_multitool/tools/tool_base.gd"
## TODO Scanner – hledá TODO/FIXME/HACK… komentáře ve skriptech.

const TodoPanel = preload("res://addons/hb_multitool/tools/todo/todo_panel.gd")

var panel: Control


func _init() -> void:
	id = "todo"


func enable() -> void:
	panel = TodoPanel.new()
	plugin.hub_add_tab(panel, "TODO")


func disable() -> void:
	if is_instance_valid(panel):
		plugin.hub_remove_tab(panel)
		panel.queue_free()
	panel = null


func on_setting_changed(_key: String) -> void:
	if is_instance_valid(panel):
		panel.rescan()
