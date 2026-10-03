@tool
extends "res://addons/hb_multitool/tools/tool_base.gd"
## Transform nástroje pro vybrané Node2D / Node3D.

const TransformPanel = preload("res://addons/hb_multitool/tools/transform/transform_panel.gd")

var panel: Control


func _init() -> void:
	id = "transform"


func enable() -> void:
	panel = TransformPanel.new(plugin)
	plugin.hub_add_tab(panel, "Transform")


func disable() -> void:
	if is_instance_valid(panel):
		plugin.hub_remove_tab(panel)
		panel.queue_free()
	panel = null


func on_setting_changed(_key: String) -> void:
	if is_instance_valid(panel):
		panel.apply_settings()
