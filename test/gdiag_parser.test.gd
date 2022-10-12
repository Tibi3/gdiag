extends WAT.Test

const GDiagLexer := preload("res://addons/gdiag/gdiag_lexer.gd")
const GDiagParser := preload("res://addons/gdiag/gdiag_parser.gd")

func _test_parser() -> void:
	describe("parser")

	var lexer := GDiagLexer.new()
	var tokens := lexer.get_tokens(
"""
__request__
	player_name: String
	winter: bool

__characters__
	Player, Jane

[MAIN]:
	Jane: if player_name == "Szia", "Hello!"
		- HI, main
		- HELLO, main
		- HEY, optional
[HI]:
	Player: "Hi!"

[HELLO]:
	Player: "Hello!"

[HEY]:
	Player: "Hey!"

""")
	var parser := GDiagParser.new()
	var result := parser.parse(tokens)
	print(result)
	print(parser.get_errors())
	asserts.is_true(true)


func test_expression() -> void:
	describe("expression")

	var lexer := GDiagLexer.new()
	var tokens := lexer.get_tokens("(player_name == \"Jani\" && get_player_hp() == -15) || -5 == 5")
	var parser := GDiagParser.new()
	parser._tokens = tokens
	var result := parser._parse_expression()

	print(to_json(result))
	print(parser.get_errors())
	asserts.is_true(true)