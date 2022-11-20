class_name GDiagError

enum Code {
	L_UNEXPECTED_TEXT
	L_NO_CLOSING_QUOTATION_MARK
	P_UNEXPECTED_TOKEN
	P_EXPECTED_TYPE
	P_ANSWER_HAS_TO_END_OPTIONAL_OR_MAIN
	P_UNEXPECTED_RP
	P_EXPECTED_OPERAND_AFTER_UNARY_OP
	P_UNEXPECTED_TOKEN_IN_EXPRESSION
	P_NODE_HAS_NO_PARAGRAPH
	P_NOT_IMPLEMENTED_YET
	P_UNKNOW_CHARACTER
	I_MISSING_FROM_CONTEXT
	I_SHOULD_BE_OF_TYPE
	I_NODE_NOT_FOUND
}

const ERRORS := {
	Code.L_UNEXPECTED_TEXT: "Unexpected text: {text}...",
	Code.L_NO_CLOSING_QUOTATION_MARK: "Quotation mark has no closing pair.",
	Code.P_UNEXPECTED_TOKEN: "Expected {expected}, but got token: {token}.",
	Code.P_EXPECTED_TYPE: "Expected one of bool, int, float, String, func, but got {token}.",
	Code.P_ANSWER_HAS_TO_END_OPTIONAL_OR_MAIN: "Answer has to end with 'optional' or 'main'.",
	Code.P_UNEXPECTED_RP: "Unexpected ')' in expression.",
	Code.P_EXPECTED_OPERAND_AFTER_UNARY_OP: "Expected literal or variable after unary operator(+, -).",
	Code.P_UNEXPECTED_TOKEN_IN_EXPRESSION: "Unexpected token {token} in expression.",
	Code.P_NODE_HAS_NO_PARAGRAPH: "Node {name} has no paragraph.",
	Code.P_NOT_IMPLEMENTED_YET: "Not implemented yet.",
	Code.P_UNKNOW_CHARACTER: "Unknown character '{character}'. Did you forget to add them after __characters__?",
	Code.I_MISSING_FROM_CONTEXT: "{name} missing from context.",
	Code.I_SHOULD_BE_OF_TYPE: "{name} should be of type {type} but got '{got}'.",
	Code.I_NODE_NOT_FOUND: "{name} not found."
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
