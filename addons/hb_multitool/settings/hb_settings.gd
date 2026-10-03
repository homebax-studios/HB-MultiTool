@tool
extends RefCounted
## Schéma a úložiště nastavení HB MultiTool.
## Hodnoty se ukládají do EditorSettings pod klíčem "hb_multitool/<tool>/<volba>".
## Chceš-li přidat novou volbu nebo nástroj, stačí upravit konstantu TOOLS.

const PREFIX := "hb_multitool/"
const VERSION := "1.0.0"

const TOOLS: Array = [
	{
		"id": "browser", "name": "Asset Browser", "default_enabled": true,
		"desc": "Prohlížeč modelů, textur/fotek, scén a audia z projektu s náhledy. Přetažením do scény (viewport / Scene dock) se objekt vloží.",
		"options": [
			{"key": "thumb_size", "label": "Velikost náhledů", "type": "int", "min": 48, "max": 256, "default": 96},
			{"key": "include_addons", "label": "Zahrnout složku addons/", "type": "bool", "default": false},
			{"key": "show_models", "label": "Zobrazit modely", "type": "bool", "default": true},
			{"key": "show_textures", "label": "Zobrazit textury / fotky", "type": "bool", "default": true},
			{"key": "show_scenes", "label": "Zobrazit scény", "type": "bool", "default": true},
			{"key": "show_audio", "label": "Zobrazit audio", "type": "bool", "default": false},
			{"key": "show_details", "label": "Načítat detaily (rozlišení, počet nodů…)", "type": "bool", "default": true},
			{"key": "max_items", "label": "Max. počet položek", "type": "int", "min": 100, "max": 20000, "default": 3000},
			{"key": "dblclick", "label": "Akce dvojkliku", "type": "enum", "items": ["Přidat do scény", "Otevřít / ukázat v souborech"], "default": 0},
		],
	},
	{
		"id": "debug", "name": "Debug okno", "default_enabled": false,
		"desc": "Plovoucí okno s FPS, zatížením, CPU/GPU informacemi, pamětí a statistikami běžící hry (reálné FPS hry přes debugger).",
		"options": [
			{"key": "update_interval", "label": "Interval obnovení (s)", "type": "float", "min": 0.05, "max": 5.0, "step": 0.05, "default": 0.25},
			{"key": "always_on_top", "label": "Vždy nahoře", "type": "bool", "default": true},
			{"key": "keep_awake", "label": "Nepřetržité překreslování editoru (přesné FPS editoru, vyšší zátěž)", "type": "bool", "default": false},
			{"key": "show_graph", "label": "Zobrazit graf FPS", "type": "bool", "default": true},
			{"key": "graph_samples", "label": "Počet vzorků grafu", "type": "int", "min": 30, "max": 600, "default": 120},
			{"key": "graph_color", "label": "Barva grafu", "type": "color", "default": Color(0.3, 0.9, 0.4)},
			{"key": "show_game_stats", "label": "Statistiky běžící hry (přidá autoload HBDebugProbe)", "type": "bool", "default": true},
			{"key": "show_system", "label": "Sekce Systém (CPU, GPU, OS)", "type": "bool", "default": true},
			{"key": "show_memory", "label": "Sekce Paměť a objekty", "type": "bool", "default": true},
			{"key": "show_render", "label": "Sekce Rendering", "type": "bool", "default": true},
		],
	},
	{
		"id": "todo", "name": "TODO Scanner", "default_enabled": true,
		"desc": "Najde komentáře TODO / FIXME / HACK… ve skriptech. Dvojklik otevře soubor na daném řádku.",
		"options": [
			{"key": "keywords", "label": "Klíčová slova (oddělená čárkou)", "type": "string", "default": "TODO,FIXME,HACK,BUG,NOTE"},
			{"key": "extensions", "label": "Přípony souborů", "type": "string", "default": "gd,cs,gdshader"},
			{"key": "include_addons", "label": "Zahrnout složku addons/", "type": "bool", "default": false},
			{"key": "auto_refresh", "label": "Automaticky obnovit při změně souborů", "type": "bool", "default": true},
		],
	},
	{
		"id": "rename", "name": "Hromadné přejmenování nodů", "default_enabled": true,
		"desc": "Přejmenuje vybrané nody: najít/nahradit (i regex), prefix, suffix, číslování a změna stylu písma. Podporuje Ctrl+Z.",
		"options": [
			{"key": "live_preview", "label": "Živý náhled podle výběru", "type": "bool", "default": true},
			{"key": "default_digits", "label": "Výchozí počet číslic číslování", "type": "int", "min": 1, "max": 8, "default": 2},
		],
	},
	{
		"id": "transform", "name": "Transform nástroje", "default_enabled": true,
		"desc": "Reset transformace, přichycení na mřížku, náhodná rotace a měřítko pro vybrané Node2D/Node3D. Podporuje Ctrl+Z.",
		"options": [
			{"key": "snap_size", "label": "Velikost mřížky", "type": "float", "min": 0.001, "max": 1000.0, "step": 0.01, "default": 1.0},
			{"key": "rand_axis", "label": "Osa náhodné rotace (3D)", "type": "enum", "items": ["X", "Y", "Z"], "default": 1},
			{"key": "rand_scale_min", "label": "Náhodné měřítko – min", "type": "float", "min": 0.01, "max": 100.0, "step": 0.05, "default": 0.8},
			{"key": "rand_scale_max", "label": "Náhodné měřítko – max", "type": "float", "min": 0.01, "max": 100.0, "step": 0.05, "default": 1.2},
		],
	},
	{
		"id": "notes", "name": "Poznámky k projektu", "default_enabled": true,
		"desc": "Jednoduchý poznámkový blok uložený per-projekt (ve složce .godot/editor).",
		"options": [
			{"key": "font_size", "label": "Velikost písma", "type": "int", "min": 8, "max": 40, "default": 14},
			{"key": "save_delay", "label": "Prodleva automatického uložení (s)", "type": "float", "min": 0.2, "max": 10.0, "step": 0.1, "default": 1.0},
		],
	},
	{
		"id": "autosave", "name": "Automatické ukládání scén", "default_enabled": false,
		"desc": "V pravidelných intervalech uloží všechny otevřené scény.",
		"options": [
			{"key": "interval_min", "label": "Interval (minuty)", "type": "int", "min": 1, "max": 120, "default": 5},
			{"key": "notify", "label": "Vypsat zprávu do Outputu", "type": "bool", "default": true},
		],
	},
]

static var _defaults: Dictionary = {}


static func _build_defaults() -> void:
	if not _defaults.is_empty():
		return
	for t in TOOLS:
		_defaults[t["id"] + "/enabled"] = t["default_enabled"]
		for o in t["options"]:
			_defaults[t["id"] + "/" + o["key"]] = o["default"]


static func get_value(key: String, fallback: Variant = null) -> Variant:
	_build_defaults()
	var es := EditorInterface.get_editor_settings()
	var full := PREFIX + key
	if es.has_setting(full):
		return es.get_setting(full)
	return _defaults.get(key, fallback)


static func set_value(key: String, value: Variant) -> void:
	EditorInterface.get_editor_settings().set_setting(PREFIX + key, value)


static func is_enabled(tool_id: String) -> bool:
	return bool(get_value(tool_id + "/enabled", false))


static func all_keys(tool_id: String) -> PackedStringArray:
	_build_defaults()
	var out := PackedStringArray()
	for k in _defaults:
		if String(k).begins_with(tool_id + "/"):
			out.append(k)
	return out


static func reset_tool(tool_id: String) -> void:
	_build_defaults()
	for k in all_keys(tool_id):
		set_value(k, _defaults[k])


static func reset_all() -> void:
	for t in TOOLS:
		reset_tool(t["id"])


static func ensure_defaults() -> void:
	_build_defaults()
	var es := EditorInterface.get_editor_settings()
	for k in _defaults:
		var full: String = PREFIX + k
		if not es.has_setting(full):
			es.set_setting(full, _defaults[k])
		es.set_initial_value(full, _defaults[k], false)
