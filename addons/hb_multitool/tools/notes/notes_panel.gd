@tool
extends VBoxContainer

const HBSettings = preload("res://addons/hb_multitool/settings/hb_settings.gd")

var _edit: TextEdit
var _status: Label
var _timer: Timer
var _path: String = ""
var _dirty := false


func _init() -> void:
	name = "Poznámky"
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_path = EditorInterface.get_editor_paths().get_project_settings_dir().path_join("hb_multitool_notes.txt")

	_edit = TextEdit.new()
	_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_edit.placeholder_text = "Poznámky k projektu… (ukládají se automaticky)"
	_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_edit.text_changed.connect(_on_changed)
	add_child(_edit)

	_status = Label.new()
	_status.modulate.a = 0.6
	add_child(_status)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_save)
	add_child(_timer)

	if FileAccess.file_exists(_path):
		_edit.text = FileAccess.get_file_as_string(_path)
	apply_settings()


func _exit_tree() -> void:
	if _dirty:
		_save()


func apply_settings() -> void:
	_edit.add_theme_font_size_override("font_size", int(HBSettings.get_value("notes/font_size")))
	_timer.wait_time = maxf(0.1, float(HBSettings.get_value("notes/save_delay")))


func _on_changed() -> void:
	_dirty = true
	_status.text = "Neuloženo…"
	_timer.start()


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f:
		f.store_string(_edit.text)
		f.close()
		_dirty = false
		if is_inside_tree():
			_status.text = "Uloženo"
