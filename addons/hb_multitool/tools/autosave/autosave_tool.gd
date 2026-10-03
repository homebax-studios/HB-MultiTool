@tool
extends "res://addons/hb_multitool/tools/tool_base.gd"
## Automatické ukládání všech otevřených scén v pravidelném intervalu.

const HBSettings = preload("res://addons/hb_multitool/settings/hb_settings.gd")

var _timer: Timer


func _init() -> void:
	id = "autosave"


func enable() -> void:
	_timer = Timer.new()
	_timer.timeout.connect(_on_timeout)
	EditorInterface.get_base_control().add_child(_timer)
	_apply()


func disable() -> void:
	if is_instance_valid(_timer):
		_timer.stop()
		_timer.queue_free()
	_timer = null


func on_setting_changed(_key: String) -> void:
	_apply()


func _apply() -> void:
	if not is_instance_valid(_timer):
		return
	_timer.wait_time = maxf(1, int(HBSettings.get_value("autosave/interval_min"))) * 60.0
	_timer.start()


func _on_timeout() -> void:
	EditorInterface.save_all_scenes()
	if bool(HBSettings.get_value("autosave/notify")):
		print_rich("[color=gray][HB MultiTool] Scény automaticky uloženy (%s)[/color]" % Time.get_time_string_from_system())
