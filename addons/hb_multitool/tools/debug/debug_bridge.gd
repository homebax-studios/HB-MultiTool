@tool
extends EditorDebuggerPlugin
## Přijímá statistiky z běžící hry (posílá je autoload debug_probe.gd).

signal stats_received(data: Dictionary)
signal session_changed(active: bool)


func _has_capture(prefix: String) -> bool:
	return prefix == "hb_debug"


func _capture(message: String, data: Array, _session_id: int) -> bool:
	if message == "hb_debug:stats":
		if data.size() > 0 and data[0] is Dictionary:
			stats_received.emit(data[0])
		return true
	return false


func _setup_session(session_id: int) -> void:
	var session := get_session(session_id)
	session.started.connect(func() -> void: session_changed.emit(true))
	session.stopped.connect(func() -> void: session_changed.emit(false))
