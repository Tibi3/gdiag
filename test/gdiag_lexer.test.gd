extends WAT.Test

const GDiagLexer: GDScript = preload("res://addons/gdiag/gdiag_lexer.gd")

func test_get_tokens() -> void:
	describe("gets tokens")
	var lexer := GDiagLexer.new()
	var source =\
"""
[MAIN]:
	Jane: "Hello {{ player_name }}!"
"""
	var res := lexer.get_tokens(source)
	var errors := lexer.get_errors()
	
	print(to_json(res))
	print(errors)
	
	asserts.is_equal(errors.size(), 0)
