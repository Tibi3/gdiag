tool
extends TextEdit

const Global := preload("res://addons/gdiag/editor/gdiag_global.gd")

func _ready() -> void:
	print(Global.get_editor_interface().get_editor_settings()\
			.get_setting("text_editor/highlighting/symbol_color"))

