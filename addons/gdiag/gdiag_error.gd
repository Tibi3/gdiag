class_name GDiagError

enum Code {
	L_UNEXPECTED_TOKEN
	L_NO_CLOSING_QUOTATION_MARK
}

const ERRORS := {
	Code.L_UNEXPECTED_TOKEN: "Unexpected token: {token}...",
	Code.L_NO_CLOSING_QUOTATION_MARK: "Quotation mark has no closing pair. Put a \" after your text."
}

var code: int
var line: int
var column: int
var meta: Dictionary

func _init(p_code: int, p_line: int, p_column: int, p_meta := {}) -> void:
	code = p_code
	line = p_line
	column = p_column
	meta = p_meta


func get_msg() -> String:
	return (ERRORS[code] as String).format(meta)


func _to_string() -> String:
	return "error(%d,%d): %s" % [line, column, get_msg()]
