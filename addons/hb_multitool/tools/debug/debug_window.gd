@tool
extends Window
## Plovoucí debug okno: FPS editoru, statistiky běžící hry, systém, paměť a rendering.
## Poznámka: Godot nezpřístupňuje skutečné % zatížení CPU/GPU. "Zatížení hlavního vlákna"
## je odhad = (doba process + physics) / doba snímku.

signal closed_by_user

const HBSettings = preload("res://addons/hb_multitool/settings/hb_settings.gd")


class FpsGraph extends Control:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var max_samples: int = 120
	var line_color: Color = Color(0.3, 0.9, 0.4)

	func _init() -> void:
		custom_minimum_size = Vector2(0, 80)

	func push(v: float) -> void:
		samples.append(v)
		while samples.size() > max_samples:
			samples.remove_at(0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
		if samples.size() < 2:
			return
		var mx := 1.0
		for s in samples:
			mx = maxf(mx, s)
		mx = maxf(mx * 1.1, 30.0)
		var pts := PackedVector2Array()
		var step := size.x / float(max_samples - 1)
		var offset := (max_samples - samples.size()) * step
		for i in samples.size():
			pts.append(Vector2(offset + i * step, size.y - (samples[i] / mx) * (size.y - 4.0) - 2.0))
		draw_polyline(pts, line_color, 1.6, true)
		draw_string(ThemeDB.fallback_font, Vector2(4, 12), "%d FPS" % int(mx), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.55))


var _timer: Timer
var _graph: FpsGraph
var _vals: Dictionary = {}
var _sections: Dictionary = {}
var _game: Dictionary = {}
var _game_running := false
var _game_tick := 0


func _init() -> void:
	title = "HB Debug"
	size = Vector2i(380, 640)
	min_size = Vector2i(300, 240)
	visible = false
	transient = true
	close_requested.connect(func() -> void: closed_by_user.emit())


func _ready() -> void:
	_build_ui()
	_fill_system()
	_timer = Timer.new()
	_timer.timeout.connect(_update)
	add_child(_timer)
	apply_settings()
	_timer.start()


func _exit_tree() -> void:
	HBSettings.set_value("debug/win_rect", Rect2i(position, size))
	OS.low_processor_usage_mode = not bool(EditorInterface.get_editor_settings().get_setting("interface/editor/update_continuously"))


func show_window() -> void:
	var r: Variant = HBSettings.get_value("debug/win_rect", null)
	if r is Rect2i:
		var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		if usable.intersects(r):
			popup(r)
			return
	popup_centered()


# --------------------------------------------------------------------------
# UI
# --------------------------------------------------------------------------

func _build_ui() -> void:
	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)

	var perf := _section(v, "perf", "Výkon editoru")
	_row(perf, "fps", "FPS")
	_row(perf, "frame_ms", "Doba snímku")
	_row(perf, "load", "Zatížení hl. vlákna ≈")

	_graph = FpsGraph.new()
	v.add_child(_graph)
	_sections["graph"] = _graph

	var game := _section(v, "game", "Běžící hra")
	_row(game, "game_state", "Stav")
	_row(game, "game_fps", "FPS hry")
	_row(game, "game_frame", "Doba snímku")
	_row(game, "game_load", "Zatížení hl. vlákna ≈")
	_row(game, "game_proc", "Process / Physics")
	_row(game, "game_draw", "Draw calls")
	_row(game, "game_prim", "Primitiva")
	_row(game, "game_nodes", "Nody / Objekty")
	_row(game, "game_orphans", "Osiřelé nody")
	_row(game, "game_mem", "Paměť (static)")
	_row(game, "game_vram", "VRAM")

	var sys := _section(v, "system", "Systém")
	for r in [["cpu", "Procesor"], ["cores", "Vlákna"], ["gpu", "GPU"], ["vendor", "Výrobce GPU"],
			["gpu_type", "Typ GPU"], ["api", "Grafické API"], ["renderer", "Renderer"], ["os", "Systém"],
			["godot", "Godot"], ["display", "Display server"], ["refresh", "Obnovovací frekvence"]]:
		_row(sys, r[0], r[1])

	var mem := _section(v, "memory", "Paměť a objekty (editor)")
	for r in [["mem_static", "Paměť (static)"], ["mem_peak", "Paměť (peak)"], ["objects", "Objekty"],
			["resources", "Resources"], ["nodes", "Nody"], ["orphans", "Osiřelé nody"]]:
		_row(mem, r[0], r[1])

	var ren := _section(v, "render", "Rendering (editor)")
	for r in [["draw", "Draw calls"], ["prim", "Primitiva"], ["objs", "Objekty ve snímku"],
			["vram", "VRAM celkem"], ["tex", "Textury"], ["buf", "Buffery"]]:
		_row(ren, r[0], r[1])


func _section(parent: Control, key: String, text: String) -> GridContainer:
	var box := VBoxContainer.new()
	parent.add_child(box)
	var h := Label.new()
	h.text = text
	h.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
	h.add_theme_font_size_override("font_size", 15)
	box.add_child(h)
	box.add_child(HSeparator.new())
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	box.add_child(g)
	_sections[key] = box
	return g


func _row(g: GridContainer, key: String, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.modulate.a = 0.75
	g.add_child(l)
	var val := Label.new()
	val.text = "—"
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.custom_minimum_size = Vector2(150, 0)
	g.add_child(val)
	_vals[key] = val


func _put(key: String, text: String, color: Color = Color(0, 0, 0, 0)) -> void:
	var l: Label = _vals.get(key)
	if l == null:
		return
	l.text = text
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	else:
		l.remove_theme_color_override("font_color")


# --------------------------------------------------------------------------
# Nastavení
# --------------------------------------------------------------------------

func apply_settings() -> void:
	if _timer:
		_timer.wait_time = clampf(float(HBSettings.get_value("debug/update_interval")), 0.05, 5.0)
	always_on_top = bool(HBSettings.get_value("debug/always_on_top"))

	var keep := bool(HBSettings.get_value("debug/keep_awake"))
	var continuous := bool(EditorInterface.get_editor_settings().get_setting("interface/editor/update_continuously"))
	OS.low_processor_usage_mode = not (keep or continuous)

	_graph.max_samples = int(HBSettings.get_value("debug/graph_samples"))
	_graph.line_color = HBSettings.get_value("debug/graph_color")
	_sections["graph"].visible = bool(HBSettings.get_value("debug/show_graph"))
	_sections["game"].visible = bool(HBSettings.get_value("debug/show_game_stats"))
	_sections["system"].visible = bool(HBSettings.get_value("debug/show_system"))
	_sections["memory"].visible = bool(HBSettings.get_value("debug/show_memory"))
	_sections["render"].visible = bool(HBSettings.get_value("debug/show_render"))


# --------------------------------------------------------------------------
# Data
# --------------------------------------------------------------------------

func _fill_system() -> void:
	_put("cpu", OS.get_processor_name())
	_put("cores", str(OS.get_processor_count()))
	_put("gpu", RenderingServer.get_video_adapter_name())
	_put("vendor", RenderingServer.get_video_adapter_vendor())
	var types := ["Jiné", "Integrovaná", "Dedikovaná", "Virtuální", "CPU"]
	_put("gpu_type", types[clampi(int(RenderingServer.get_video_adapter_type()), 0, types.size() - 1)])
	_put("api", RenderingServer.get_video_adapter_api_version())
	_put("renderer", str(RenderingServer.get_current_rendering_method()))
	_put("os", "%s %s" % [OS.get_name(), OS.get_version()])
	_put("godot", str(Engine.get_version_info().get("string", "?")))
	_put("display", DisplayServer.get_name())
	var hz := DisplayServer.screen_get_refresh_rate()
	_put("refresh", ("%.0f Hz" % hz) if hz > 0.0 else "neznámá")


func _fps_color(fps: float) -> Color:
	if fps >= 55.0:
		return Color(0.4, 0.95, 0.5)
	if fps >= 30.0:
		return Color(1.0, 0.85, 0.3)
	return Color(1.0, 0.4, 0.4)


func _update() -> void:
	if not visible:
		return
	var fps := float(Engine.get_frames_per_second())
	var frame_ms := 1000.0 / maxf(fps, 1.0)
	var proc_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var load_pct := clampf((proc_ms + phys_ms) / frame_ms * 100.0, 0.0, 999.0)

	_put("fps", "%d" % int(fps), _fps_color(fps))
	_put("frame_ms", "%.2f ms" % frame_ms)
	_put("load", "%.0f %%" % load_pct)
	_graph.push(fps)

	_put("mem_static", String.humanize_size(int(Performance.get_monitor(Performance.MEMORY_STATIC))))
	_put("mem_peak", String.humanize_size(OS.get_static_memory_peak_usage()))
	_put("objects", str(int(Performance.get_monitor(Performance.OBJECT_COUNT))))
	_put("resources", str(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))))
	_put("nodes", str(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))))
	_put("orphans", str(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))))

	_put("draw", str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))))
	_put("prim", str(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))))
	_put("objs", str(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))))
	_put("vram", String.humanize_size(int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))))
	_put("tex", String.humanize_size(int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))))
	_put("buf", String.humanize_size(int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED))))

	if _game_running and Time.get_ticks_msec() - _game_tick > 3000:
		_put("game_state", "Čekám na data…", Color(1.0, 0.85, 0.3))


func on_game_state(active: bool) -> void:
	_game_running = active
	_game_tick = Time.get_ticks_msec()
	if active:
		_put("game_state", "Běží", Color(0.4, 0.95, 0.5))
	else:
		for k in _vals:
			if String(k).begins_with("game_"):
				_put(k, "—")
		_put("game_state", "Neběží")


func on_game_stats(d: Dictionary) -> void:
	_game = d
	_game_running = true
	_game_tick = Time.get_ticks_msec()
	var fps := float(d.get("fps", 0))
	var frame_ms := float(d.get("frame_ms", 0.0))
	var proc := float(d.get("process_ms", 0.0))
	var phys := float(d.get("physics_ms", 0.0))
	_put("game_state", "Běží", Color(0.4, 0.95, 0.5))
	_put("game_fps", "%d" % int(fps), _fps_color(fps))
	_put("game_frame", "%.2f ms" % frame_ms)
	_put("game_load", "%.0f %%" % clampf((proc + phys) / maxf(frame_ms, 0.001) * 100.0, 0.0, 999.0))
	_put("game_proc", "%.2f / %.2f ms" % [proc, phys])
	_put("game_draw", str(d.get("draw_calls", 0)))
	_put("game_prim", str(d.get("primitives", 0)))
	_put("game_nodes", "%d / %d" % [int(d.get("nodes", 0)), int(d.get("objects", 0))])
	_put("game_orphans", str(d.get("orphans", 0)))
	_put("game_mem", String.humanize_size(int(d.get("mem_static", 0))))
	_put("game_vram", String.humanize_size(int(d.get("vram", 0))))
