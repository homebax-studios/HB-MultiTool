@tool
extends VBoxContainer

const HBSettings = preload("res://addons/hb_multitool/settings/hb_settings.gd")

var plugin: EditorPlugin

var _find: LineEdit
var _repl: LineEdit
var _prefix: LineEdit
var _suffix: LineEdit
var _regex: CheckBox
var _case: OptionButton
var _num: CheckBox
var _start: SpinBox
var _digits: SpinBox
var _list: ItemList
var _connected := false


func _init(p: EditorPlugin = null) -> void:
	plugin = p
	name = "Přejmenování"
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	add_child(grid)

	_find = _add_line(grid, "Najít")
	_repl = _add_line(grid, "Nahradit")
	_prefix = _add_line(grid, "Prefix")
	_suffix = _add_line(grid, "Suffix")

	grid.add_child(_label("Styl písma"))
	_case = OptionButton.new()
	for n in ["Beze změny", "malá písmena", "VELKÁ PÍSMENA", "PascalCase", "snake_case"]:
		_case.add_item(n)
	_case.item_selected.connect(func(_i: int) -> void: _update_preview())
	grid.add_child(_case)

	_regex = CheckBox.new()
	_regex.text = "Regex"
	_regex.toggled.connect(func(_b: bool) -> void: _update_preview())
	grid.add_child(_regex)
	grid.add_child(Control.new())

	_num = CheckBox.new()
	_num.text = "Číslovat"
	_num.toggled.connect(func(_b: bool) -> void: _update_preview())
	grid.add_child(_num)

	var nrow := HBoxContainer.new()
	grid.add_child(nrow)
	nrow.add_child(_label("od"))
	_start = SpinBox.new()
	_start.max_value = 99999
	_start.value = 1
	_start.value_changed.connect(func(_v: float) -> void: _update_preview())
	nrow.add_child(_start)
	nrow.add_child(_label("číslic"))
	_digits = SpinBox.new()
	_digits.min_value = 1
	_digits.max_value = 8
	_digits.value_changed.connect(func(_v: float) -> void: _update_preview())
	nrow.add_child(_digits)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(0, 80)
	add_child(_list)

	var btns := HBoxContainer.new()
	add_child(btns)
	var load_btn := Button.new()
	load_btn.text = "Načíst výběr"
	load_btn.pressed.connect(_update_preview)
	btns.add_child(load_btn)
	var apply := Button.new()
	apply.text = "Použít přejmenování"
	apply.pressed.connect(_apply)
	btns.add_child(apply)

	apply_settings()
	_update_preview()


func _exit_tree() -> void:
	_disconnect_selection()


func apply_settings() -> void:
	_digits.set_value_no_signal(int(HBSettings.get_value("rename/default_digits")))
	var live := bool(HBSettings.get_value("rename/live_preview"))
	var sel := EditorInterface.get_selection()
	if live and not _connected:
		sel.selection_changed.connect(_update_preview)
		_connected = true
	elif not live:
		_disconnect_selection()
	_update_preview()


func _disconnect_selection() -> void:
	if _connected:
		var sel := EditorInterface.get_selection()
		if sel.selection_changed.is_connected(_update_preview):
			sel.selection_changed.disconnect(_update_preview)
		_connected = false


func _add_line(grid: GridContainer, text: String) -> LineEdit:
	grid.add_child(_label(text))
	var le := LineEdit.new()
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(_t: String) -> void: _update_preview())
	grid.add_child(le)
	return le


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _selected() -> Array[Node]:
	return EditorInterface.get_selection().get_selected_nodes()


func _new_name(old: String, idx: int) -> String:
	var n := old
	var f := _find.text
	if f != "":
		if _regex.button_pressed:
			var r := RegEx.new()
			if r.compile(f) == OK:
				n = r.sub(n, _repl.text, true)
		else:
			n = n.replace(f, _repl.text)
	n = _prefix.text + n + _suffix.text
	match _case.selected:
		1: n = n.to_lower()
		2: n = n.to_upper()
		3: n = n.to_pascal_case()
		4: n = n.to_snake_case()
	if _num.button_pressed:
		n += "_" + str(int(_start.value) + idx).pad_zeros(int(_digits.value))
	return n.validate_node_name()


func _update_preview() -> void:
	if _list == null:
		return
	_list.clear()
	var nodes := _selected()
	for i in nodes.size():
		var old := String(nodes[i].name)
		_list.add_item("%s   →   %s" % [old, _new_name(old, i)])
	if nodes.is_empty():
		_list.add_item("Ve Scene docku nejsou vybrané žádné nody.")
		_list.set_item_disabled(0, true)


func _apply() -> void:
	var nodes := _selected()
	if nodes.is_empty():
		return
	var ur := plugin.get_undo_redo()
	ur.create_action("HB: Hromadné přejmenování")
	for i in nodes.size():
		var old := String(nodes[i].name)
		var new_name := _new_name(old, i)
		if new_name == "" or new_name == old:
			continue
		ur.add_do_property(nodes[i], "name", new_name)
		ur.add_undo_property(nodes[i], "name", old)
	ur.commit_action()
	_update_preview()
