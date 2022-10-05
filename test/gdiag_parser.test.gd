extends WAT.Test

const GDiagLexer := preload("res://addons/gdiag/gdiag_lexer.gd")
const GDiagParser := preload("res://addons/gdiag/gdiag_parser.gd")

func test_parser() -> void:
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
