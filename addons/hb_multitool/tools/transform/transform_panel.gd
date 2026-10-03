@tool
extends VBoxContainer

const HBSettings = preload("res://addons/hb_multitool/settings/hb_settings.gd")

var plugin: EditorPlugin

var _snap: SpinBox
var _smin: SpinBox
var _smax: SpinBox
var _axis: OptionButton


func _init(p: EditorPlugin = null) -> void:
	plugin = p
	name = "Transform"
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	add_theme_constant_override("separation", 8)

	var hint := Label.new()
	hint.text = "Akce se provedou na vybraných Node2D / Node3D. Všechny kroky lze vrátit přes Ctrl+Z."
	hint.modulate.a = 0.7
	add_child(hint)

	var r1 := _row()
	_btn(r1, "Reset vše", func() -> void: _modify("Reset transformace", _reset_fn.bind("all")))
	_btn(r1, "Reset pozice", func() -> void: _modify("Reset pozice", _reset_fn.bind("pos")))
	_btn(r1, "Reset rotace", func() -> void: _modify("Reset rotace", _reset_fn.bind("rot")))
	_btn(r1, "Reset měřítka", func() -> void: _modify("Reset měřítka", _reset_fn.bind("scale")))

	var r2 := _row()
	r2.add_child(_label("Mřížka"))
	_snap = _spin(r2, 0.001, 1000.0, 0.01)
	_snap.value_changed.connect(func(v: float) -> void: HBSettings.set_value("transform/snap_size", v))
	_btn(r2, "Přichytit pozici", func() -> void: _modify("Přichytit na mřížku", _snap_fn))

	var r3 := _row()
	r3.add_child(_label("Osa (3D)"))
	_axis = OptionButton.new()
	for a in ["X", "Y", "Z"]:
		_axis.add_item(a)
	_axis.item_selected.connect(func(i: int) -> void: HBSettings.set_value("transform/rand_axis", i))
	r3.add_child(_axis)
	_btn(r3, "Náhodná rotace", func() -> void: _modify("Náhodná rotace", _rand_rot_fn))

	var r4 := _row()
	r4.add_child(_label("Měřítko min"))
	_smin = _spin(r4, 0.01, 100.0, 0.05)
	_smin.value_changed.connect(func(v: float) -> void: HBSettings.set_value("transform/rand_scale_min", v))
	r4.add_child(_label("max"))
	_smax = _spin(r4, 0.01, 100.0, 0.05)
	_smax.value_changed.connect(func(v: float) -> void: HBSettings.set_value("transform/rand_scale_max", v))
	_btn(r4, "Náhodné měřítko", func() -> void: _modify("Náhodné měřítko", _rand_scale_fn))

	var r5 := _row()
	_btn(r5, "Pozice Y = 0 (3D)", func() -> void: _modify("Y na nulu", _ground_fn))

	apply_settings()


func apply_settings() -> void:
	_snap.set_value_no_signal(float(HBSettings.get_value("transform/snap_size")))
	_smin.set_value_no_signal(float(HBSettings.get_value("transform/rand_scale_min")))
	_smax.set_value_no_signal(float(HBSettings.get_value("transform/rand_scale_max")))
	_axis.selected = int(HBSettings.get_value("transform/rand_axis"))


# --------------------------------------------------------------------------
# UI pomocné funkce
# --------------------------------------------------------------------------

func _row() -> HFlowContainer:
	var r := HFlowContainer.new()
	add_child(r)
	return r


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _btn(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)


func _spin(parent: Control, mn: float, mx: float, step: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	parent.add_child(s)
	return s


# --------------------------------------------------------------------------
# Logika
# --------------------------------------------------------------------------

func _selected() -> Array:
	var out: Array = []
	for n in EditorInterface.get_selection().get_selected_nodes():
		if n is Node2D or n is Node3D:
			out.append(n)
	return out


## fn(node) -> Dictionary {vlastnost: nová_hodnota}; vše se zapíše jako jedna undo akce.
func _modify(action: String, fn: Callable) -> void:
	var nodes := _selected()
	if nodes.is_empty():
		push_warning("HB Transform: Vyber alespoň jeden Node2D / Node3D.")
		return
	var ur := plugin.get_undo_redo()
	ur.create_action("HB: " + action)
	for n in nodes:
		var changes: Dictionary = fn.call(n)
		for prop in changes:
			ur.add_do_property(n, prop, changes[prop])
			ur.add_undo_property(n, prop, n.get(prop))
	ur.commit_action()


func _reset_fn(n: Node, which: String) -> Dictionary:
	var d := {}
	var is3 := n is Node3D
	if which == "all" or which == "pos":
		d["position"] = Vector3.ZERO if is3 else Vector2.ZERO
	if which == "all" or which == "rot":
		d["rotation"] = Vector3.ZERO if is3 else 0.0
	if which == "all" or which == "scale":
		d["scale"] = Vector3.ONE if is3 else Vector2.ONE
	return d


func _snap_fn(n: Node) -> Dictionary:
	var g := maxf(_snap.value, 0.0001)
	if n is Node3D:
		return {"position": (n as Node3D).position.snapped(Vector3.ONE * g)}
	return {"position": (n as Node2D).position.snapped(Vector2.ONE * g)}


func _rand_rot_fn(n: Node) -> Dictionary:
	var angle := deg_to_rad(randf() * 360.0)
	if n is Node3D:
		var rot: Vector3 = (n as Node3D).rotation
		rot[_axis.selected] = angle
		return {"rotation": rot}
	return {"rotation": angle}


func _rand_scale_fn(n: Node) -> Dictionary:
	var s := randf_range(minf(_smin.value, _smax.value), maxf(_smin.value, _smax.value))
	if n is Node3D:
		return {"scale": Vector3.ONE * s}
	return {"scale": Vector2.ONE * s}


func _ground_fn(n: Node) -> Dictionary:
	if n is Node3D:
		var p: Vector3 = (n as Node3D).position
		p.y = 0.0
		return {"position": p}
	return {}
