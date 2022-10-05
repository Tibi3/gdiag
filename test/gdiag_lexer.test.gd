extends WAT.Test

const GDiagLexer: GDScript = preload("res://addons/gdiag/gdiag_lexer.gd")

func test_get_token() -> void:
	describe("gets the correct token")
	parameters([
		["src", "expected_type", "expected_value"],
		["12  ", GDiagLexer.Token.Type.INT_LITERAL, 12],
		["  12.5", GDiagLexer.Token.Type.FLOAT_LITERAL, 12.5],
		["\tplayer_name  ", GDiagLexer.Token.Type.ID, "player_name"],
		[" \"Hello, world\"", GDiagLexer.Token.Type.STRING_LITERAL, "Hello, world"],
	])

	var lexer := GDiagLexer.new()
	var tokens := lexer.get_tokens(p["src"])

	asserts.is_Array(tokens, "tokens should be an array")
	asserts.is_equal(tokens.size(), 3, "length of tokens should be 1")
	asserts.is_equal(tokens[0].type, p["expected_type"], "type of token should be %d" % p["expected_type"])
	asserts.is_equal(tokens[0].value, p["expected_value"], "value of token should be %s" % p["expected_value"])


func test_get_error() -> void:
	describe("gets the correct error")
	parameters([
		["src", "expected_error"],
		["Jane: 'Hello player'", GDiagError.Code.L_UNEXPECTED_TEXT],
		["Jane: \"Hello player", GDiagError.Code.L_NO_CLOSING_QUOTATION_MARK],
	])

	var lexer := GDiagLexer.new()
	var __ = lexer.get_tokens(p["src"])
	var errors := lexer.get_errors()

	asserts.is_Array(errors, "errors should be an array")
	asserts.is_equal(errors.size(), 1, "length of errors should be 1")
	asserts.is_equal(errors[0].code, p["expected_error"], "error code should be %d" % p["expected_error"])

