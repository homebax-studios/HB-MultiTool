@tool
extends VBoxContainer
## UI Asset Browseru: vyhledávání, filtry, náhledy, detail a drag & drop do scény.

const HBSettings = preload("res://addons/hb_multitool/settings/hb_settings.gd")

const MODEL_EXT: Array = ["glb", "gltf", "fbx", "obj", "dae", "blend"]
const TEXTURE_EXT: Array = ["png", "jpg", "jpeg", "webp", "svg", "bmp", "tga", "exr", "hdr", "dds", "ktx"]
const SCENE_EXT: Array = ["tscn", "scn"]
const AUDIO_EXT: Array = ["ogg", "wav", "mp3"]
const KIND_NAMES := {"model": "Model", "texture": "Textura / foto", "scene": "Scéna", "audio": "Audio"}
const FILTER_KINDS: Array = ["", "model", "texture", "scene", "audio"]

var plugin: EditorPlugin

var _search: LineEdit
var _filter: OptionButton
var _slider: HSlider
var _count: Label
var _list: ItemList
var _preview: TextureRect
var _info: Label
var _btn_add: Button
var _btn_open: Button

var _files: Array = []
var _kind_by_path: Dictionary = {}
var _index_by_path: Dictionary = {}
var _previews: Dictionary = {}
var _generation: int = 0
var _current_path: String = ""
var _rescan_pending: bool = false
var _last_include_addons: bool = false
var _placeholder: Texture2D


func _init(p: EditorPlugin = null) -> void:
	plugin = p
	name = "Browser"
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	var et := EditorInterface.get_editor_theme()
	_placeholder = et.get_icon("File", "EditorIcons")
	_build_ui(et)
	_last_include_addons = bool(HBSettings.get_value("browser/include_addons"))
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_fs_changed)
	apply_settings(false)
	_rescan()


func _build_ui(et: Theme) -> void:
	var bar := HBoxContainer.new()
	add_child(bar)

	_search = LineEdit.new()
	_search.placeholder_text = "Hledat v projektu…"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t: String) -> void: _populate())
	bar.add_child(_search)

	_filter = OptionButton.new()
	for n in ["Vše", "Modely", "Textury / fotky", "Scény", "Audio"]:
		_filter.add_item(n)
	_filter.item_selected.connect(func(_i: int) -> void: _populate())
	bar.add_child(_filter)

	var lbl := Label.new()
	lbl.text = "Velikost"
	bar.add_child(lbl)

	_slider = HSlider.new()
	_slider.min_value = 48
	_slider.max_value = 256
	_slider.step = 8
	_slider.custom_minimum_size = Vector2(120, 0)
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.value_changed.connect(_on_slider)
	bar.add_child(_slider)

	_count = Label.new()
	_count.modulate.a = 0.7
	bar.add_child(_count)

	var reload := Button.new()
	reload.icon = et.get_icon("Reload", "EditorIcons")
	reload.tooltip_text = "Znovu načíst soubory"
	reload.pressed.connect(_rescan)
	bar.add_child(reload)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	_list = ItemList.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.icon_mode = ItemList.ICON_MODE_TOP
	_list.max_columns = 0
	_list.same_column_width = true
	_list.allow_reselect = true
	_list.item_selected.connect(_on_selected)
	_list.item_activated.connect(_on_activated)
	_list.set_drag_forwarding(_get_drag_data_fw, Callable(), Callable())
	split.add_child(_list)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(280, 0)
	split.add_child(right)

	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.custom_minimum_size = Vector2(0, 140)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_preview)

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_info.text = "Vyber položku pro náhled.\nPřetažením do scény ji vložíš."
	_info.modulate.a = 0.8
	right.add_child(_info)

	var btns := HBoxContainer.new()
	right.add_child(btns)
	_btn_add = Button.new()
	_btn_add.text = "Přidat do scény"
	_btn_add.pressed.connect(func() -> void: _add_to_scene(_current_path))
	btns.add_child(_btn_add)
	_btn_open = Button.new()
	_btn_open.text = "Otevřít / ukázat"
	_btn_open.pressed.connect(func() -> void: _open_current())
	btns.add_child(_btn_open)


# --------------------------------------------------------------------------
# Nastavení
# --------------------------------------------------------------------------

func apply_settings(repopulate: bool = true) -> void:
	var s := int(HBSettings.get_value("browser/thumb_size"))
	_slider.set_value_no_signal(s)
	_apply_thumb(s)
	var inc := bool(HBSettings.get_value("browser/include_addons"))
	if inc != _last_include_addons:
		_last_include_addons = inc
		_rescan()
	elif repopulate:
		_populate()


func _on_slider(v: float) -> void:
	HBSettings.set_value("browser/thumb_size", int(v))
	_apply_thumb(int(v))


func _apply_thumb(s: int) -> void:
	_list.fixed_icon_size = Vector2i(s, s)
	_list.fixed_column_width = s + 24


# --------------------------------------------------------------------------
# Skenování a zobrazení
# --------------------------------------------------------------------------

func _on_fs_changed() -> void:
	if _rescan_pending:
		return
	_rescan_pending = true
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		_rescan_pending = false
		_rescan())


func _rescan() -> void:
	_files.clear()
	_kind_by_path.clear()
	_previews.clear()
	_scan_dir("res://", bool(HBSettings.get_value("browser/include_addons")))
	_files.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	_populate()


func _scan_dir(dir: String, inc_addons: bool) -> void:
	for f in DirAccess.get_files_at(dir):
		var kind := _kind_for(f.get_extension().to_lower())
		if kind == "":
			continue
		var p := dir.path_join(f)
		_files.append({"path": p, "name": f, "kind": kind})
		_kind_by_path[p] = kind
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with("."):
			continue
		if not inc_addons and dir == "res://" and d == "addons":
			continue
		var sub := dir.path_join(d)
		if FileAccess.file_exists(sub.path_join(".gdignore")):
			continue
		_scan_dir(sub, inc_addons)


func _kind_for(ext: String) -> String:
	if ext in MODEL_EXT:
		return "model"
	if ext in TEXTURE_EXT:
		return "texture"
	if ext in SCENE_EXT:
		return "scene"
	if ext in AUDIO_EXT:
		return "audio"
	return ""


func _populate() -> void:
	_generation += 1
	_list.clear()
	_index_by_path.clear()

	var allow := {
		"model": bool(HBSettings.get_value("browser/show_models")),
		"texture": bool(HBSettings.get_value("browser/show_textures")),
		"scene": bool(HBSettings.get_value("browser/show_scenes")),
		"audio": bool(HBSettings.get_value("browser/show_audio")),
	}
	var only: String = FILTER_KINDS[_filter.selected]
	var q := _search.text.strip_edges().to_lower()
	var max_items := int(HBSettings.get_value("browser/max_items"))
	var shown := 0

	for e in _files:
		var kind: String = e["kind"]
		var path: String = e["path"]
		if not allow[kind]:
			continue
		if only != "" and kind != only:
			continue
		if q != "" and not path.to_lower().contains(q):
			continue
		if shown >= max_items:
			break
		var idx := _list.add_item(e["name"], _placeholder)
		_list.set_item_metadata(idx, path)
		_list.set_item_tooltip(idx, path)
		_index_by_path[path] = idx
		if _previews.has(path):
			_list.set_item_icon(idx, _previews[path])
		else:
			EditorInterface.get_resource_previewer().queue_resource_preview(path, self, "_on_preview_ready", _generation)
		shown += 1

	_count.text = "%d / %d" % [shown, _files.size()]


## Callback z EditorResourcePreview (název metody je zadán řetězcem výše).
func _on_preview_ready(path: String, preview: Texture2D, _thumb: Texture2D, userdata: Variant) -> void:
	if preview == null:
		return
	_previews[path] = preview
	if int(userdata) != _generation:
		return
	var idx: int = _index_by_path.get(path, -1)
	if idx >= 0 and idx < _list.item_count:
		_list.set_item_icon(idx, preview)
	if path == _current_path and _preview.texture == null:
		_preview.texture = preview


# --------------------------------------------------------------------------
# Výběr, detail
# --------------------------------------------------------------------------

func _on_selected(idx: int) -> void:
	_show_details(String(_list.get_item_metadata(idx)))


func _show_details(path: String) -> void:
	_current_path = path
	var kind: String = _kind_by_path.get(path, "")
	var lines := PackedStringArray([path])

	var fsize := 0
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa:
		fsize = fa.get_length()
		fa.close()
	lines.append("%s • %s" % [KIND_NAMES.get(kind, kind), String.humanize_size(fsize)])

	_preview.texture = _previews.get(path, null)

	if bool(HBSettings.get_value("browser/show_details")) and fsize < 64 * 1024 * 1024:
		match kind:
			"texture":
				var tex := load(path) as Texture2D
				if tex:
					lines.append("Rozlišení: %d × %d px" % [tex.get_width(), tex.get_height()])
					_preview.texture = tex
			"scene", "model":
				var ps := load(path) as PackedScene
				if ps:
					lines.append("Počet nodů: %d" % ps.get_state().get_node_count())
			"audio":
				var st := load(path) as AudioStream
				if st:
					lines.append("Délka: %.2f s" % st.get_length())
	_info.text = "\n".join(lines)


func _on_activated(idx: int) -> void:
	var path := String(_list.get_item_metadata(idx))
	_current_path = path
	if int(HBSettings.get_value("browser/dblclick")) == 0:
		_add_to_scene(path)
	else:
		_open_current()


func _open_current() -> void:
	if _current_path == "":
		return
	if _kind_by_path.get(_current_path, "") == "scene":
		EditorInterface.open_scene_from_path(_current_path)
	else:
		EditorInterface.select_file(_current_path)


# --------------------------------------------------------------------------
# Drag & drop – formát "files" stejný jako u FileSystem docku,
# takže ho přijme 3D/2D viewport i Scene dock.
# --------------------------------------------------------------------------

func _get_drag_data_fw(at_position: Vector2, from: Control) -> Variant:
	var idx := _list.get_item_at_position(at_position, true)
	if idx < 0:
		return null
	_list.select(idx)
	var path := String(_list.get_item_metadata(idx))
	_show_details(path)

	var prev := TextureRect.new()
	prev.texture = _list.get_item_icon(idx)
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.custom_minimum_size = Vector2(64, 64)
	from.set_drag_preview(prev)

	return {"type": "files", "files": PackedStringArray([path]), "from": from}


# --------------------------------------------------------------------------
# Vložení do scény (tlačítko / dvojklik)
# --------------------------------------------------------------------------

func _add_to_scene(path: String) -> void:
	if path == "":
		return
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_warning("HB Browser: Není otevřená žádná scéna.")
		return

	var sel := EditorInterface.get_selection().get_selected_nodes()
	var parent: Node = sel[0] if sel.size() > 0 else root
	var node := _make_node(path, parent)
	if node == null:
		push_warning("HB Browser: Soubor nelze vložit do scény: " + path)
		return

	var ur := plugin.get_undo_redo()
	ur.create_action("HB Browser: Přidat " + path.get_file())
	ur.add_do_method(parent, "add_child", node, true)
	ur.add_do_method(node, "set_owner", root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()

	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(node)


func _make_node(path: String, parent: Node) -> Node:
	var res := load(path)
	var is_3d := parent is Node3D
	var base_name := path.get_file().get_basename()

	if res is PackedScene:
		return (res as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if res is Texture2D:
		var spr: Node
		if is_3d:
			var s3 := Sprite3D.new()
			s3.texture = res
			spr = s3
		else:
			var s2 := Sprite2D.new()
			s2.texture = res
			spr = s2
		spr.name = base_name
		return spr
	if res is AudioStream:
		var ap: Node
		if is_3d:
			var a3 := AudioStreamPlayer3D.new()
			a3.stream = res
			ap = a3
		else:
			var a := AudioStreamPlayer.new()
			a.stream = res
			ap = a
		ap.name = base_name
		return ap
	if res is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = res
		mi.name = base_name
		return mi
	return null
