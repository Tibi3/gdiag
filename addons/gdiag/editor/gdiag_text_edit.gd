tool
extends TextEdit

const Global := preload("res://addons/gdiag/editor/gdiag_global.gd")

const KEYWORDS := [
	"__request__", "__characters__", "main", "optional"
]

const TYPES := [
	"int", "float", "bool", "String", "func"
]

func _ready() -> void:
	var settings := Global.get_editor_interface().get_editor_settings()

	for word in KEYWORDS:
		add_keyword_color(word, settings.get("text_editor/highlighting/keyword_color"))

	for word in TYPES:
		add_keyword_color(word, settings.get("text_editor/highlighting/keyword_color"))

	add_keyword_color("if", settings.get("text_editor/highlighting/control_flow_keyword_color"))

	add_color_region("#", "", settings.get("text_editor/highlighting/comment_color"), true)
	add_color_region("\"", "\"", settings.get("text_editor/highlighting/string_color"))
	add_color_region("[", "]", settings.get("text_editor/highlighting/gdscript/function_definition_color"), true)

	add_font_override("font", Global.get_editor_interface().get_base_control().get_font("source", "EditorFonts"))

	add_color_override("function_color", settings.get("text_editor/highlighting/function_color"))
	add_color_override("symbol_color", settings.get("text_editor/highlighting/symbol_color"))
	add_color_override("font_color", settings.get("text_editor/highlighting/text_color"))
	add_color_override("line_number_color", settings.get("text_editor/highlighting/safe_line_number_color"))
	add_color_override("background_color", settings.get("text_editor/highlighting/background_color"))
	add_color_override("number_color", settings.get("text_editor/highlighting/number_color"))
	add_color_override("current_line_color", settings.get("text_editor/highlighting/current_line_color"))
	# TODO: Add the rest...
