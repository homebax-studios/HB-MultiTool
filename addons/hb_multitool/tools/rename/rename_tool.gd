@tool
extends "res://addons/hb_multitool/tools/tool_base.gd"
## Hromadné přejmenování vybraných nodů.

const RenamePanel = preload("res://addons/hb_multitool/tools/rename/rename_panel.gd")

var panel: Control


func _init() -> void:
	id = "rename"


func enable() -> void:
	panel = RenamePanel.new(plugin)
	plugin.hub_add_tab(panel, "Přejmenování")


func disable() -> void:
	if is_instance_valid(panel):
		plugin.hub_remove_tab(panel)
		panel.queue_free()
	panel = null


func on_setting_changed(_key: String) -> void:
	if is_instance_valid(panel):
		panel.apply_settings()
