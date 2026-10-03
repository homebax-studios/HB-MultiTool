@tool
extends RefCounted
## Základní třída všech nástrojů HB MultiTool.

var plugin: EditorPlugin
var id: String = ""
var active: bool = false


func setup(p: EditorPlugin) -> void:
	plugin = p


## Zapnutí nástroje (vytvoř UI, připoj signály…).
func enable() -> void:
	pass


## Vypnutí nástroje (odstraň UI, uvolni zdroje).
func disable() -> void:
	pass


## Volá se při zavírání editoru / pluginu.
func shutdown() -> void:
	disable()


## Změna libovolné volby tohoto nástroje (klíč je např. "browser/thumb_size").
func on_setting_changed(_key: String) -> void:
	pass
