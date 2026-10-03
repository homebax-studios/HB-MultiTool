@tool
extends VBoxContainer

const HBSettings = preload("res://addons/hb_multitool/settings/hb_settings.gd")

const TYPE_COLORS := {
	"TODO": Color(1.0, 0.85, 0.3),
	"FIXME": Color(1.0, 0.45, 0.4),
	"BUG": Color(1.0, 0.35, 0.35),
	"HACK": Color(1.0, 0.65, 0.25),
	"NOTE": Color(0.5, 0.8, 1.0),
}

var _tree: Tree
var _search: LineEdit
var _count: Label
var _items: Array = []
var _rescan_pending := false


func _init() -> void:
	name = "TODO"
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	var bar := HBoxContainer.new()
	add_child(bar)

	var reload := Button.new()
	reload.icon = EditorInterface.get_editor_theme().get_icon("Reload", "EditorIcons")
	reload.tooltip_text = "Znovu prohledat projekt"
	reload.pressed.connect(rescan)
	bar.add_child(reload)

	_search = LineEdit.new()
	_search.placeholder_text = "Filtrovat…"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t: String) -> void: _refresh_tree())
	bar.add_child(_search)

	_count = Label.new()
	_count.modulate.a = 0.7
	bar.add_child(_count)

	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.columns = 3
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.set_column_title(0, "Typ")
	_tree.set_column_title(1, "Text")
	_tree.set_column_title(2, "Soubor:řádek")
	_tree.set_column_expand(0, false)
	_tree.set_column_custom_minimum_width(0, 80)
	_tree.set_column_expand(2, false)
	_tree.set_column_custom_minimum_width(2, 280)
	_tree.item_activated.connect(_on_activated)
	add_child(_tree)

	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_fs_changed)
	rescan()


func _on_fs_changed() -> void:
	if not bool(HBSettings.get_value("todo/auto_refresh")) or _rescan_pending:
		return
	_rescan_pending = true
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		_rescan_pending = false
		rescan())


func rescan() -> void:
	_items.clear()

	var exts: Array = []
	for e in String(HBSettings.get_value("todo/extensions")).split(",", false):
		exts.append(e.strip_edges().to_lower().trim_prefix("."))

	var kws: Array = []
	for k in String(HBSettings.get_value("todo/keywords")).split(",", false):
		var kw := k.strip_edges()
		if kw != "":
			kws.append(kw)
	if kws.is_empty() or exts.is_empty():
		_refresh_tree()
		return

	var regex := RegEx.new()
	if regex.compile("(?:#|//|/\\*)\\s*(" + "|".join(kws) + ")\\b\\s*:?\\s*(.*)") != OK:
		_refresh_tree()
		return

	_scan_dir("res://", exts, regex, bool(HBSettings.get_value("todo/include_addons")))
	_refresh_tree()


func _scan_dir(dir: String, exts: Array, regex: RegEx, inc_addons: bool) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() in exts:
			_scan_file(dir.path_join(f), regex)
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with("."):
			continue
		if not inc_addons and dir == "res://" and d == "addons":
			continue
		var sub := dir.path_join(d)
		if FileAccess.file_exists(sub.path_join(".gdignore")):
			continue
		_scan_dir(sub, exts, regex, inc_addons)


func _scan_file(path: String, regex: RegEx) -> void:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		var m := regex.search(lines[i])
		if m:
			_items.append({
				"type": m.get_string(1),
				"text": m.get_string(2).strip_edges(),
				"path": path,
				"line": i + 1,
			})


func _refresh_tree() -> void:
	_tree.clear()
	var root := _tree.create_item()
	var q := _search.text.strip_edges().to_lower()
	var shown := 0
	for it in _items:
		var text: String = it["text"]
		var path: String = it["path"]
		if q != "" and not (text.to_lower().contains(q) or path.to_lower().contains(q) or String(it["type"]).to_lower().contains(q)):
			continue
		var ti := _tree.create_item(root)
		ti.set_text(0, it["type"])
		ti.set_custom_color(0, TYPE_COLORS.get(it["type"], Color.WHITE))
		ti.set_text(1, text)
		ti.set_text(2, "%s:%d" % [path.trim_prefix("res://"), it["line"]])
		ti.set_metadata(0, {"path": path, "line": it["line"]})
		shown += 1
	_count.text = "%d položek" % shown


func _on_activated() -> void:
	var it := _tree.get_selected()
	if it == null:
		return
	var meta: Dictionary = it.get_metadata(0)
	var path: String = meta["path"]
	var line: int = meta["line"]
	var ext := path.get_extension().to_lower()
	if ext == "gd" or ext == "cs":
		var res := load(path)
		if res is Script:
			EditorInterface.set_main_screen_editor("Script")
			EditorInterface.edit_script(res)
			# goto_line je číslováno od 0
			EditorInterface.get_script_editor().goto_line.call_deferred(line - 1)
	elif ext == "gdshader":
		EditorInterface.edit_resource(load(path))
	else:
		EditorInterface.select_file(path)
