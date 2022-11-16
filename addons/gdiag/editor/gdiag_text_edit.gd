tool
extends TextEdit

signal error # <string[]>

const Global := preload("res://addons/gdiag/editor/gdiag_global.gd")
const Lexer := preload("res://addons/gdiag/gdiag_lexer.gd")
const Parser := preload("res://addons/gdiag/gdiag_parser.gd")
const Rand := preload("res://addons/gdiag/editor/gdiag_random_string.gd")

const PARSE_DELAY_SEC := 1.0
const TRANSLATION_KEY_LENGTH := 8 # without '~'

const KEYWORDS := [ "__request__", "__characters__", "main", "optional", "or", "and", "jump", "close", "true", "false" ]
const TYPES := [ "int", "float", "bool", "String", "func" ]

const AUTO_CLOSE := {
	"\"": "\"",
	"~": "~",
	"[": "]",
	"(": ")"
}

var _lexer := Lexer.new()
var _parser := Parser.new()
var _previous_tree := Parser.Result.new()
var _timer := Timer.new()

var _last_errors := []

var _error_highlighter := ColorRect.new()

func _ready() -> void:
	(get_child(1) as VScrollBar).connect("value_changed", self, "_scrolling")

	# Hack: I don't know how to highlight a line, so I just put a semi transparent ColorRect above it.
	_error_highlighter.color = Color(0.8, 0.305882, 0.305882, 0.415686)
	_error_highlighter.visible = false
	_error_highlighter.rect_size = Vector2(1500, get_line_height() - 2)
	_error_highlighter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_error_highlighter)

	syntax_highlighting = true
	show_line_numbers = true
	highlight_current_line = true
	highlight_all_occurrences = true
	caret_blink = true
	bookmark_gutter = true
	breakpoint_gutter = true
	fold_gutter = true

	add_font_override("font", Global.get_editor_interface().get_base_control().get_font("source", "EditorFonts"))

	_setup_syntax_highlighting()
	_analyse()
	_setup_timer()

	connect("text_changed", self, "_text_changed")


func generate_translation_keys() -> void:
	# TODO: use UndoRedo
	_last_errors = []
	var tokens := _lexer.get_tokens(text)
	var lexer_errors := _lexer.get_errors()

	if lexer_errors.size() > 0:
		printerr("Please resolve errors before generating translation keys.")
		return

	var tree := _parser.parse(tokens)
	var parser_errors := _parser.get_errors()

	if parser_errors.size() > 0:
		printerr("Please resolve errors before generating translation keys.")
		return

	for node in tree.nodes:
		var previous_line := -1
		var same_line_counter := 0
		for child in tree.nodes[node]["children"]:
			if child["type"] == Parser.Type.PARAGRAPH && child["text"]["translation_key"] == "":
				var line_number: int = child["text"]["line"] - 1
				same_line_counter = same_line_counter + 1 if previous_line == line_number else 0
				var offset := 1 + same_line_counter * (TRANSLATION_KEY_LENGTH + 2)

				# TODO: check key collision
				var line_content := get_line(line_number).insert(
						child["text"]["column"] + child["text"]["value"].length() + offset,
						Rand.rand_str(TRANSLATION_KEY_LENGTH, '~', '~'))
				set_line(line_number, line_content)
				previous_line = line_number


func get_errors() -> Array:
	return _last_errors


func _text_changed() -> void:
	_timer.start()


func _timer_timeout() -> void:
	_analyse()


func _analyse() -> void:
	var tokens := _lexer.get_tokens(text)
	var lexer_errors := _lexer.get_errors()

	if lexer_errors.size() > 0:
		_last_errors = lexer_errors
		call_deferred("_highlight_error", _last_errors[0].line)
		emit_signal("error", _last_errors)
		return

	var tree := _parser.parse(tokens)
	var parser_errors := _parser.get_errors()

	if parser_errors.size() > 0:
		_last_errors = parser_errors
		call_deferred("_highlight_error", _last_errors[0].line)
		emit_signal("error", _last_errors)
		return

	emit_signal("error", [])
	_hide_error_highlight()
	_previous_tree = tree
	_setup_syntax_highlighting()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.scancode == KEY_CONTROL && !event.echo:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if event.pressed else Control.CURSOR_IBEAM
			Input.parse_input_event(InputEventMouseMotion.new())
		elif char(event.unicode) in AUTO_CLOSE:
			if is_selection_active():
				if get_selection_from_line() == get_selection_to_line():
					var line := get_line(get_selection_from_line())
					line = line.insert(get_selection_from_column(), char(event.unicode))
					line = line.insert(get_selection_to_column() + 1, AUTO_CLOSE[char(event.unicode)])
					call_deferred("set_line", get_selection_from_line(), line)
			else:
				set_line(cursor_get_line(),
						get_line(cursor_get_line()).insert(cursor_get_column(),
						AUTO_CLOSE[char(event.unicode)]))


func _scrolling(param) -> void:
	if _last_errors.size() > 0:
		call_deferred("_highlight_error", _last_errors[0].line)


func _setup_syntax_highlighting() -> void:
	var settings := Global.get_editor_interface().get_editor_settings()

	clear_colors()
	for node in _previous_tree.nodes:
		add_keyword_color(node, settings.get("text_editor/highlighting/gdscript/function_definition_color"))

	for word in KEYWORDS:
		add_keyword_color(word, settings.get("text_editor/highlighting/keyword_color"))

	for word in TYPES:
		add_keyword_color(word, settings.get("text_editor/highlighting/keyword_color"))

	add_keyword_color("if", settings.get("text_editor/highlighting/control_flow_keyword_color"))

	add_color_region("#", "", settings.get("text_editor/highlighting/comment_color"), true)
	add_color_region("\"", "\"", settings.get("text_editor/highlighting/string_color"))
	add_color_region("[", "]", settings.get("text_editor/highlighting/gdscript/function_definition_color"), true)
	add_color_region("~", "~", settings.get("text_editor/highlighting/comment_color"), true)

	add_color_override("function_color", settings.get("text_editor/highlighting/function_color"))
	add_color_override("symbol_color", settings.get("text_editor/highlighting/symbol_color"))
	add_color_override("font_color", settings.get("text_editor/highlighting/text_color"))
	add_color_override("line_number_color", settings.get("text_editor/highlighting/safe_line_number_color"))
	add_color_override("background_color", settings.get("text_editor/highlighting/background_color"))
	add_color_override("number_color", settings.get("text_editor/highlighting/number_color"))
	add_color_override("current_line_color", settings.get("text_editor/highlighting/current_line_color"))
	# TODO: Add the rest...


func _setup_timer() -> void:
	_timer.connect("timeout", self, "_timer_timeout")
	_timer.one_shot = true
	_timer.wait_time = PARSE_DELAY_SEC
	add_child(_timer)


func _highlight_error(p_line: int) -> void:
	var line_pos := get_pos_at_line_column(p_line - 1, 0)
	_error_highlighter.rect_position.x = 0
	_error_highlighter.rect_position.y = line_pos.y - get_line_height()
	_error_highlighter.visible = line_pos.x != -1


func _hide_error_highlight() -> void:
	_error_highlighter.visible = false
