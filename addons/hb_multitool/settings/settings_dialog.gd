@tool
extends AcceptDialog
## Okno nastavení HB MultiTool (Project > Tools > HB MultiTool – Nastavení…).
## UI se generuje automaticky ze schématu v hb_settings.gd.

signal setting_changed(key: String)

const HBSettings = preload("res://addons/hb_multitool/settings/hb_settings.gd")

var _root: VBoxContainer


func _init() -> void:
	title = "HB MultiTool – Nastavení"
	ok_button_text = "Zavřít"
	min_size = Vector2i(640, 680)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 600)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 10)
	scroll.add_child(_root)


func open() -> void:
	_rebuild()
	popup_centered()


func _rebuild() -> void:
	for c in _root.get_children():
		_root.remove_child(c)
		c.queue_free()

	var title_lbl := Label.new()
	title_lbl.text = "HB MultiTool  v%s" % HBSettings.VERSION
	title_lbl.add_theme_font_size_override("font_size", 22)
	_root.add_child(title_lbl)

	var sub := Label.new()
	sub.text = "Vytvořil Homebax Studios • zapni / vypni a nastav jednotlivé nástroje"
	sub.modulate.a = 0.7
	_root.add_child(sub)

	for t in HBSettings.TOOLS:
		_add_tool_section(t)

	var reset_all := Button.new()
	reset_all.text = "Obnovit vše na výchozí"
	reset_all.pressed.connect(func() -> void:
		HBSettings.reset_all()
		for tt in HBSettings.TOOLS:
			_emit_tool(tt["id"])
		_rebuild())
	_root.add_child(reset_all)


func _add_tool_section(t: Dictionary) -> void:
	var tool_id: String = t["id"]
	var panel := PanelContainer.new()
	_root.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	margin.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)

	var cb := CheckBox.new()
	cb.text = t["name"]
	cb.button_pressed = HBSettings.is_enabled(tool_id)
	cb.add_theme_font_size_override("font_size", 17)
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(cb)

	var reset := Button.new()
	reset.text = "Výchozí"
	reset.flat = true
	reset.pressed.connect(func() -> void:
		HBSettings.reset_tool(tool_id)
		_emit_tool(tool_id)
		_rebuild())
	head.add_child(reset)

	var desc := Label.new()
	desc.text = t["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.modulate.a = 0.7
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(desc)

	var options: Array = t["options"]
	if options.is_empty():
		return

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	grid.modulate.a = 1.0 if cb.button_pressed else 0.45
	v.add_child(grid)

	for o in options:
		var lbl := Label.new()
		lbl.text = o["label"]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(lbl)
		grid.add_child(_make_widget(tool_id, o))

	cb.toggled.connect(func(on: bool) -> void:
		HBSettings.set_value(tool_id + "/enabled", on)
		grid.modulate.a = 1.0 if on else 0.45
		setting_changed.emit(tool_id + "/enabled"))


func _make_widget(tool_id: String, o: Dictionary) -> Control:
	var key: String = tool_id + "/" + o["key"]
	var val: Variant = HBSettings.get_value(key)
	match o["type"]:
		"bool":
			var c := CheckBox.new()
			c.button_pressed = bool(val)
			c.toggled.connect(func(v: bool) -> void: _write(key, v))
			return c
		"int":
			var s := SpinBox.new()
			s.min_value = o["min"]
			s.max_value = o["max"]
			s.step = 1
			s.value = int(val)
			s.value_changed.connect(func(v: float) -> void: _write(key, int(v)))
			return s
		"float":
			var s := SpinBox.new()
			s.min_value = o["min"]
			s.max_value = o["max"]
			s.step = o.get("step", 0.1)
			s.value = float(val)
			s.value_changed.connect(func(v: float) -> void: _write(key, v))
			return s
		"enum":
			var ob := OptionButton.new()
			var items: Array = o["items"]
			for i in items.size():
				ob.add_item(items[i], i)
			ob.selected = int(val)
			ob.item_selected.connect(func(i: int) -> void: _write(key, i))
			return ob
		"color":
			var cp := ColorPickerButton.new()
			cp.custom_minimum_size = Vector2(80, 26)
			cp.color = val
			cp.color_changed.connect(func(c: Color) -> void: _write(key, c))
			return cp
		_:
			var le := LineEdit.new()
			le.text = str(val)
			le.custom_minimum_size = Vector2(220, 0)
			le.text_changed.connect(func(tx: String) -> void: _write(key, tx))
			return le


func _write(key: String, value: Variant) -> void:
	HBSettings.set_value(key, value)
	setting_changed.emit(key)


func _emit_tool(tool_id: String) -> void:
	for k in HBSettings.all_keys(tool_id):
		setting_changed.emit(k)
