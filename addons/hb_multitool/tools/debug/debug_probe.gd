extends Node
## Autoload "HBDebugProbe" – běží uvnitř hry a posílá statistiky do editoru.
## Mimo debug session (např. v exportu) se sám vypne a nic nestojí.

const INTERVAL := 0.5

var _t := 0.0


func _ready() -> void:
	if not EngineDebugger.is_active():
		set_process(false)


func _process(delta: float) -> void:
	_t += delta
	if _t < INTERVAL:
		return
	_t = 0.0
	EngineDebugger.send_message("hb_debug:stats", [_collect()])


func _collect() -> Dictionary:
	var fps := Engine.get_frames_per_second()
	return {
		"fps": fps,
		"frame_ms": 1000.0 / maxf(fps, 1.0),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"mem_static": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"vram": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
	}
