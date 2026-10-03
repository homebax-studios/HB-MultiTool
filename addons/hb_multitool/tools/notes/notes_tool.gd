@tool
extends "res://addons/hb_multitool/tools/tool_base.gd"
## Poznámky k projektu.

const NotesPanel = preload("res://addons/hb_multitool/tools/notes/notes_panel.gd")

var panel: Control


func _init() -> void:
	id = "notes"


func enable() -> void:
	panel = NotesPanel.new()
	plugin.hub_add_tab(panel, "Poznámky")


func disable() -> void:
	if is_instance_valid(panel):
		plugin.hub_remove_tab(panel)
		panel.queue_free()
	panel = null


func on_setting_changed(_key: String) -> void:
	if is_instance_valid(panel):
		panel.apply_settings()
