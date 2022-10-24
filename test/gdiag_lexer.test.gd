extends WAT.Test

const GDiagLexer: GDScript = preload("res://addons/gdiag/gdiag_lexer.gd")

func test_single_token() -> void:
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
	asserts.is_equal(tokens.size(), 3, "length of tokens should be 3")
	asserts.is_equal(tokens[0].type, p["expected_type"], "type of token should be %d" % p["expected_type"])
	asserts.is_equal(tokens[0].value, p["expected_value"], "value of token should be %s" % p["expected_value"])


func test_get_tokens() -> void:
	describe("gets the correct tokens")
	var src = """
__request__
	player_name: String
	player_hp: float
	time: int
	found_secret: bool
	heal: func

__characters__
	Jane, Player

[MAIN]:
	Jane: if found_secret, "You found the secret!"
	Jane: heal(), "healing..."
		- A1, main
		- A2, if found_secret, optional
	Player: "something"
	jump: if player_hp != 12.48, HERE

[A1]:
	Player: "A1"

[A2]:
	Player: "A2"

[HERE]:
	Player: "Jumped here"
"""
	var lexer := GDiagLexer.new()
	var tokens := lexer.get_tokens(src)
	var errors := lexer.get_errors()

	asserts.is_equal(errors.size(), 0)
	var index := 0
	for expected in [
		[GDiagLexer.Token.Type.REQUEST, null],
		[GDiagLexer.Token.Type.ID, "player_name"],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.STRING, null],
		[GDiagLexer.Token.Type.ID, "player_hp"],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.FLOAT, null],
		[GDiagLexer.Token.Type.ID, "time"],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.INT, null],
		[GDiagLexer.Token.Type.ID, "found_secret"],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.BOOL, null],
		[GDiagLexer.Token.Type.ID, "heal"],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.FUNC, null],
		[GDiagLexer.Token.Type.CHARACTERS, null],
		[GDiagLexer.Token.Type.ID, "Jane"],
		[GDiagLexer.Token.Type.COMMA, null],
		[GDiagLexer.Token.Type.ID, "Player"],
		[GDiagLexer.Token.Type.LEFT_SQUARE_BRACKET, null],
		[GDiagLexer.Token.Type.ID, "MAIN"],
		[GDiagLexer.Token.Type.RIGHT_SQUARE_BRACKET, null],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.ID, "Jane"],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.IF, null],
		[GDiagLexer.Token.Type.ID, "found_secret"],
		[GDiagLexer.Token.Type.COMMA, null],
		[GDiagLexer.Token.Type.STRING_LITERAL, "You found the secret!"],
		[GDiagLexer.Token.Type.ID, "Jane"],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.ID, "heal"],
		[GDiagLexer.Token.Type.LEFT_PARENTHESIS, null],
		[GDiagLexer.Token.Type.RIGHT_PARENTHESIS, null],
		[GDiagLexer.Token.Type.COMMA, null],
		[GDiagLexer.Token.Type.STRING_LITERAL, "healing..."],
		[GDiagLexer.Token.Type.MINUS, null],
		[GDiagLexer.Token.Type.ID, "A1"],
		[GDiagLexer.Token.Type.COMMA, null],
		[GDiagLexer.Token.Type.MAIN, null],
		[GDiagLexer.Token.Type.MINUS, null],
		[GDiagLexer.Token.Type.ID, "A2"],
		[GDiagLexer.Token.Type.COMMA, null],
		[GDiagLexer.Token.Type.IF, null],
		[GDiagLexer.Token.Type.ID, "found_secret"],
		[GDiagLexer.Token.Type.COMMA, null],
		[GDiagLexer.Token.Type.OPTIONAL, null],
		[GDiagLexer.Token.Type.ID, "Player"],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.STRING_LITERAL, "something"],
		[GDiagLexer.Token.Type.JUMP, null],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.IF, null],
		[GDiagLexer.Token.Type.ID, "player_hp"],
		[GDiagLexer.Token.Type.NOT_EQUAL, null],
		[GDiagLexer.Token.Type.FLOAT_LITERAL, 12.48],
		[GDiagLexer.Token.Type.COMMA, null],
		[GDiagLexer.Token.Type.ID, "HERE"],
		[GDiagLexer.Token.Type.LEFT_SQUARE_BRACKET, null],
		[GDiagLexer.Token.Type.ID, "A1"],
		[GDiagLexer.Token.Type.RIGHT_SQUARE_BRACKET, null],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.ID, "Player"],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.STRING_LITERAL, "A1"],
		[GDiagLexer.Token.Type.LEFT_SQUARE_BRACKET, null],
		[GDiagLexer.Token.Type.ID, "A2"],
		[GDiagLexer.Token.Type.RIGHT_SQUARE_BRACKET, null],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.ID, "Player"],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.STRING_LITERAL, "A2"],
		[GDiagLexer.Token.Type.LEFT_SQUARE_BRACKET, null],
		[GDiagLexer.Token.Type.ID, "HERE"],
		[GDiagLexer.Token.Type.RIGHT_SQUARE_BRACKET, null],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.ID, "Player"],
		[GDiagLexer.Token.Type.COLON, null],
		[GDiagLexer.Token.Type.STRING_LITERAL, "Jumped here"],
	]:
		_check_token(tokens[index], expected[0], expected[1], index)
		index += 1


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


func _check_token(p_token: GDiagLexer.Token, p_type: int, p_value = null, p_index = 0) -> void:
	asserts.is_equal(p_token.type, p_type, "type missmatch at index %d  %s" % [p_index, p_token])
	asserts.is_equal(p_token.value, p_value, "value missmatch at index %d token: %s" % [p_index, p_token])

