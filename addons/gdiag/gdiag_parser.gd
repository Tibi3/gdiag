# class_name GDiagParser

const Lexer: GDScript = preload("res://addons/gdiag/gdiag_lexer.gd")

class Result:
	var request: Dictionary = {}
	var characters: Dictionary = {}
	var nodes: Dictionary = {}

	func _to_string() -> String:
		return JSON.print({ "request": request, "characters": characters, "nodes": nodes }, "\t")

const PRESEDENCE := {
	Lexer.Token.Type.LEFT_PARENTHESIS: -99,
	Lexer.Token.Type.OR: -1,
	Lexer.Token.Type.AND: -1,
	Lexer.Token.Type.LESS_THAN: 0,
	Lexer.Token.Type.LESS_THAN_EQUAL: 0,
	Lexer.Token.Type.GREATER_THAN: 0,
	Lexer.Token.Type.GREATER_THAN_EQUAL: 0,
	Lexer.Token.Type.EQUAL: 0,
	Lexer.Token.Type.NOT_EQUAL: 0,
	Lexer.Token.Type.PLUS: 1,
	Lexer.Token.Type.MINUS: 1,
	Lexer.Token.Type.ASTERISK: 2,
	Lexer.Token.Type.SLASH: 2,
	Lexer.Token.Type.PERCENT_SIGN: 2,

	Lexer.Token.Type.UNARY_PLUS: 3,
	Lexer.Token.Type.UNARY_MINUS: 3,
	Lexer.Token.Type.RIGHT_PARENTHESIS: 99
}

enum Type {
	ID, PARAGRAPH, JUMP, ONE_OF, FUNCTION_CALL, ANSWER,
	BINARY_OP, UNARY_OP,
	INT, FLOAT, BOOL, STRING
	VARIABLE, LITERAL
}


var _tokens: Array
var _errors: Array

var _current_index: int = -1
var _parse_result: Result

func get_errors() -> Array:
	return _errors


func parse(p_tokens: Array) -> GDiagResult: # Result, GDiagError[]
	_tokens = p_tokens
	_current_index = -1
	_parse_result = Result.new()

	if _peek().type == Lexer.Token.Type.REQUEST:
		var res := _parse_request()
		if res.is_error():
			# maybe in the future we want to return multiple errors.
			return GDiagResult.new().err([res.value])
		_parse_result.request = res.value

	if _peek().type == Lexer.Token.Type.CHARACTERS:
		var res := _parse_characters()
		if res.is_error():
			return GDiagResult.new().err([res.value])
		_parse_result.characters = res.value

	while _peek().type != Lexer.Token.Type.EOF:
		var res := _parse_node()
		if res.is_error():
			return GDiagResult.new().err([res.value])
		_parse_result.nodes[res.value.name] = res.value

	return GDiagResult.new().ok(_parse_result)


func _parse_request() -> GDiagResult: # Dictionary, GDiagError
	var request := {}
	_eat()

	while _peek().type == Lexer.Token.Type.ID:
		var name: String = _eat().value

		var res := _match_and_eat(Lexer.Token.Type.COLON)
		if res.is_error():
			return res

		match _peek().type:
			Lexer.Token.Type.INT,\
			Lexer.Token.Type.FLOAT,\
			Lexer.Token.Type.BOOL,\
			Lexer.Token.Type.STRING,\
			Lexer.Token.Type.FUNC:
				request[name] = _eat().type
			_:
				return GDiagResult.new().err(GDiagError.new(
						GDiagError.Code.P_EXPECTED_TYPE,
						_peek().line,
						_peek().column,
						{ "token": _peek() }))

	return GDiagResult.new().ok(request)


func _parse_characters() -> GDiagResult: # Dictionary, GDiagError
	var characters := {}
	_eat()
	while true:
		var res := _match_and_eat(Lexer.Token.Type.ID)
		if res.is_error():
			return res

		# In the future we can assign some kind of metadata to the characters
		characters[res.value.value] = true

		if _peek().type == Lexer.Token.Type.COMMA:
			_eat()
			continue
		break

	return GDiagResult.new().ok(characters)


func _parse_node() -> GDiagResult: # Dictionary, GDiagError
	var res := _match_and_eat(Lexer.Token.Type.LEFT_SQUARE_BRACKET)
	if res.is_error():
		return res

	res = _match_and_eat(Lexer.Token.Type.ID)
	if res.is_error():
		return res

	var node := {
		"name": res.value.value,
		"children": []
	}

	res = _match_and_eat(Lexer.Token.Type.RIGHT_SQUARE_BRACKET)
	if res.is_error():
		return res

	res = _match_and_eat(Lexer.Token.Type.COLON)
	if res.is_error():
		return res

	while true:
		match _peek().type:
			Lexer.Token.Type.JUMP:
				res = _parse_jump()
			Lexer.Token.Type.ID:
				res = _parse_paragraph()
			Lexer.Token.Type.ONE_OF:
				res = _parse_one_of()
			_: break

		if res.is_error():
			return res
		node["children"].push_back(res.value)

	if node["children"].size() == 0:
		return GDiagResult.new().err(GDiagError.new(
				GDiagError.Code.P_NODE_HAS_NO_PARAGRAPH,
				_peek().line,
				_peek().column,
				{ "name": node["name"] }))

	return GDiagResult.new().ok(node)


func _parse_id() -> Dictionary:
	var name: String = _match_and_eat(Lexer.Token.Type.ID).value
	if name == null:
		return {}

	return { "type": Type.ID, "name": name }


func _parse_one_of() -> GDiagResult: # Dictionary, GDiagError
	var one_of := {
		"type": Type.ONE_OF,
		"condition": {},
		"options": []
	}
	var one_of_token := _eat()
	if _peek().type == Lexer.Token.Type.IF:
		var res := _parse_if()
		if res.is_error():
			return res
		one_of["condition"] = res.value

	var res := _match_and_eat(Lexer.Token.Type.COLON)
	if res.is_error():
		return res

	while _peek().type == Lexer.Token.Type.MINUS:
		_eat()
		var weight := 1
		if _peek().type == Lexer.Token.Type.INT_LITERAL:
			weight = _eat().value

		if _peek().type != Lexer.Token.Type.ID:
			return GDiagResult.new().err(GDiagError.new(
				GDiagError.Code.P_UNEXPECTED_TOKEN,
				_peek().line,
				_peek().column,
				{
					"expected": Lexer.Token.get_type_name(Lexer.Token.Type.ID),
					"token": Lexer.Token.get_type_name(_peek().type)
				}))

		res = _parse_paragraph()
		if res.is_error():
			return res

		res.value["weight"] = weight
		one_of["options"].push_back(res.value)

	if one_of["options"].size() == 0:
		return GDiagResult.new().err(GDiagError.new(
				GDiagError.Code.P_EXPECTED_PARAGRAPH_AFTER_ONE_OF,
				one_of_token.line,
				one_of_token.column))

	return GDiagResult.new().ok(one_of)


func _parse_paragraph() -> GDiagResult: # Dictionary, GDiagError
	var character := _eat()

	if !_parse_result.characters.has(character.value):
		return GDiagResult.new().err(GDiagError.new(
				GDiagError.Code.P_UNKNOW_CHARACTER,
				character.line,
				character.column,
				{ "character": character.value }
		))

	var p := {
		"type": Type.PARAGRAPH,
		"character": character.value,
		"condition": {},
		"actions": [],
		"text": { "value": "", "translation_key": "", "line": -1, "column": -1 },
		"answers": []
	}

	if _peek().type == Lexer.Token.Type.IF:
		var res := _parse_if()
		if res.is_error():
			return res
		p["condition"] = res.value

	_match_and_eat(Lexer.Token.Type.COLON)

	while _peek().type == Lexer.Token.Type.ID:
		var res := _parse_function_call()
		if res.is_error():
			return res

		p["actions"].push_back(res.value)
		if _peek().type == Lexer.Token.Type.COMMA:
			_eat()

	var res := _parse_text()
	if res.is_error():
		return res

	p["text"] = res.value

	# if we are in a one_of block then '- ID' has two different meaning based on what is the value of the ID.
	while _peek().type == Lexer.Token.Type.MINUS\
			&& _peek(2).type == Lexer.Token.Type.ID\
			&& !_parse_result.characters.has(_peek(2).value):
		res = _parse_answer()
		if res.is_error():
			return res
		p["answers"].push_back(res.value)

	return GDiagResult.new().ok(p)


func _parse_if() -> GDiagResult: # Dictionary, GDiagError
	_eat()
	return _parse_expression()


func _parse_jump() -> GDiagResult: # Dictionary, GDiagError
	var jump := { "type": Type.JUMP, "condition": {}, "to": "" }
	_eat() # jump

	if _peek().type == Lexer.Token.Type.IF:
		var res := _parse_if()
		if res.is_error():
			return res

		jump["condition"] = res.value

	var res := _match_and_eat(Lexer.Token.Type.COLON)
	if res.is_error():
		return res

	res = _match_and_eat(Lexer.Token.Type.ID)
	if res.is_error():
		return res

	jump["to"] = res.value

	return GDiagResult.new().ok(jump)


func _parse_text() -> GDiagResult: # Dictionary, GDiagError
	var result := _match_and_eat(Lexer.Token.Type.STRING_LITERAL)

	if result.is_error():
		return result

	var text_token: Lexer.Token = result.value
	var last_token := text_token

	var value: String = text_token.value

	while _peek().type == Lexer.Token.Type.STRING_LITERAL:
		var str_literal := _eat()
		value += str_literal.value
		last_token = str_literal

	var text := {
		"value": value,
		"line": text_token.line,
		"column": text_token.column,
		"end_at_line": last_token.line,
		"end_at_column": last_token.column + last_token.value.length(),
		"translation_key": ""
	}

	if _peek().type == Lexer.Token.Type.TRANSLATION_KEY:
		text["translation_key"] = _eat().value

	return GDiagResult.new().ok(text)


# It's a hacky implementation of the Shunting yard algorithm
func _parse_expression() -> GDiagResult: # Dictionary, GDiagError
	var operator_stack := []
	var output_queue := []

	while true:
		match _peek().type:
			Lexer.Token.Type.INT_LITERAL,\
			Lexer.Token.Type.FLOAT_LITERAL,\
			Lexer.Token.Type.BOOL_LITERAL,\
			Lexer.Token.Type.STRING_LITERAL:
				output_queue.push_back(_parse_literal())
			Lexer.Token.Type.ID:
				var res := _parse_function_call() if _peek(2).type == Lexer.Token.Type.LEFT_PARENTHESIS else _parse_variable()
				if res.is_error():
					return res

				output_queue.push_back(res.value)
			Lexer.Token.Type.LEFT_PARENTHESIS:
				operator_stack.push_back(_eat())
			Lexer.Token.Type.RIGHT_PARENTHESIS:
				_eat()
				if operator_stack.size() <= 1:
					return GDiagResult.new().error(GDiagError.new(
							GDiagError.Code.P_UNEXPECTED_RP,
							_peek().line,
							_peek().column))
				while true:
					if operator_stack.size() == 0:
						return GDiagResult.new().error(GDiagError.new(
								GDiagError.Code.P_UNEXPECTED_RP,
								_peek().line,
								_peek().column))
					var op: Lexer.Token = operator_stack.pop_back()
					if op.type == Lexer.Token.Type.LEFT_PARENTHESIS:
						break
					output_queue.push_back(op)
			Lexer.Token.Type.PLUS,\
			Lexer.Token.Type.MINUS,\
			Lexer.Token.Type.ASTERISK,\
			Lexer.Token.Type.SLASH,\
			Lexer.Token.Type.PERCENT_SIGN,\
			Lexer.Token.Type.GREATER_THAN,\
			Lexer.Token.Type.GREATER_THAN_EQUAL,\
			Lexer.Token.Type.LESS_THAN,\
			Lexer.Token.Type.LESS_THAN_EQUAL,\
			Lexer.Token.Type.EQUAL,\
			Lexer.Token.Type.NOT_EQUAL,\
			Lexer.Token.Type.AND,\
			Lexer.Token.Type.OR:
				if operator_stack.size() == 0:
					var token := _eat()
					if  _current_index == 0:
						token.type = Lexer.Token.Type.UNARY_MINUS
					operator_stack.push_back(token)
				elif _current_index == -1 || _is_op(_peek(0).type):
					var token := _eat()
					token.type = Lexer.Token.Type.UNARY_MINUS
					operator_stack.push_back(token)
				elif PRESEDENCE[operator_stack[-1].type] >= PRESEDENCE[_peek().type]:
					output_queue.push_back(operator_stack.pop_back())
					operator_stack.push_back(_eat())
				else:
					operator_stack.push_back(_eat())
			_:
				break

	while operator_stack.size() > 0:
		output_queue.push_back(operator_stack.pop_back())

	while output_queue.size() > 0:
		# if it's a dictionary it has to be a literal, variable or function call.
		if typeof(output_queue[0]) == TYPE_DICTIONARY:
			operator_stack.push_back(output_queue.pop_front())
		# there is no elmatch :(
		else: match output_queue[0].type:
			Lexer.Token.Type.UNARY_MINUS:
				if operator_stack.size() == 0:
					return GDiagResult.new().error(GDiagError.new(
							GDiagError.Code.P_EXPECTED_OPERAND_AFTER_UNARY_OP,
							_peek().line,
							_peek().column))
				operator_stack.push_back(_parse_unary(output_queue.pop_front(), operator_stack.pop_back()))
			_:
				if operator_stack.size() < 2:
					return GDiagResult.new().error(GDiagError.new(
							GDiagError.Code.P_UNEXPECTED_TOKEN_IN_EXPRESSION,
							_peek().line,
							_peek().column,
							{"token": output_queue[0]}))
				var right = operator_stack.pop_back()
				var left = operator_stack.pop_back()
				operator_stack.push_back(_parse_binary(left, output_queue.pop_front(), right))

	if operator_stack.size() > 1:
		return GDiagResult.new().error(GDiagError.new(
				GDiagError.Code.P_UNEXPECTED_TOKEN_IN_EXPRESSION,
				_peek().line,
				_peek().column,
				{"token": operator_stack[0]}))

	return operator_stack.pop_back()


func _parse_literal() -> Dictionary:
	var res := {}
	match _peek().type:
		Lexer.Token.Type.INT_LITERAL:
			res["type"] = Type.LITERAL
			res["type_type"] = Type.INT
			res["value"] = _eat().value
		Lexer.Token.Type.FLOAT_LITERAL:
			res["type"] = Type.LITERAL
			res["type_type"] = Type.FLOAT
			res["value"] = _eat().value
		Lexer.Token.Type.BOOL_LITERAL:
			res["type"] = Type.LITERAL
			res["type_type"] = Type.BOOL
			res["value"] = _eat().value
		Lexer.Token.Type.STRING_LITERAL:
			res["type"] = Type.LITERAL
			res["type_type"] = Type.STRING
			res["value"] = _eat().value

	return res


func _parse_unary(op: Lexer.Token, operand: Dictionary) -> Dictionary:
	# TODO: Check type
	return {
		"type": Type.UNARY_OP,
		"operator": op,
		"operand": operand
	}


func _parse_binary(left: Dictionary, op: Lexer.Token, right: Dictionary) -> Dictionary:
	# TODO: Check types
	return {
		"type": Type.BINARY_OP,
		"operator": op,
		"left": left,
		"right": right,
	}


func _parse_variable() -> GDiagResult: # Lexer.Token, GdiagError
	# TODO: check if variable exists
	return GDiagResult.new().ok({
		"type": Type.VARIABLE,
		"name": _eat().value
	})


func _parse_function_call() -> GDiagResult: # Lexer.Token, GdiagError
	# TODO: check if function exists
	var function := {
		"type": Type.FUNCTION_CALL,
		"args": [],
		"name": _eat().value
	}

	var res := _match_and_eat(Lexer.Token.Type.LEFT_PARENTHESIS)
	if res.is_error():
		return res
# TODO: _parse_expression() consumes the last ')'.
#	if _peek().type != Lexer.Token.Type.RIGHT_PARENTHESIS:
#		while true:
#			var expr := _parse_expression()
#			function["args"].push_back(expr)
#			if _peek().type != Lexer.Token.Type.COMMA:
#				break
#			_eat()
	res = _match_and_eat(Lexer.Token.Type.RIGHT_PARENTHESIS)
	if res.is_error():
		return res

	return GDiagResult.new().ok(function)


func _parse_answer() -> GDiagResult: # Lexer.Token, GdiagError
	_eat()
	var res := _match_and_eat(Lexer.Token.Type.ID)
	if res.is_error():
		return res

	var answer := {
		"type": Type.ANSWER,
		"node": res.value.value,
		"condition": {},
		"optional": false
	}

	if _peek().type == Lexer.Token.Type.IF:
		res = _parse_if()
		if res.is_error():
			return res
		answer["condition"] = res.value

	res = _match_and_eat(Lexer.Token.Type.COMMA)
	if res.is_error():
		return res

	if _peek().type == Lexer.Token.Type.OPTIONAL:
		_eat()
		answer["optional"] = true
	elif _peek().type == Lexer.Token.Type.MAIN:
		_eat()
		answer["optional"] = false
	else:
		return GDiagResult.new().error(GDiagError.new(
				GDiagError.Code.P_ANSWER_HAS_TO_END_OPTIONAL_OR_MAIN,
				_peek().line,
				_peek().column))

	return GDiagResult.new().ok(answer)


func _peek(p_n: int = 1) -> Lexer.Token:
	return _tokens[_current_index + p_n]


func _eat() -> Lexer.Token:
	_current_index += 1
	return _tokens[_current_index]


func _match_and_eat(p_type: int) -> GDiagResult: # Lexer.Token, GdiagError
	if _peek().type != p_type:
		return GDiagResult.new().err(GDiagError.new(
				GDiagError.Code.P_UNEXPECTED_TOKEN,
				_peek().line,
				_peek().column,
				{
					"expected": Lexer.Token.get_type_name(p_type),
					"token": Lexer.Token.get_type_name(_peek().type)
				}))
	_current_index += 1
	return GDiagResult.new().ok(_tokens[_current_index])


func _is_op(type: int) -> bool:
	match type:
		Lexer.Token.Type.PLUS,\
		Lexer.Token.Type.MINUS,\
		Lexer.Token.Type.ASTERISK,\
		Lexer.Token.Type.SLASH,\
		Lexer.Token.Type.PERCENT_SIGN,\
		Lexer.Token.Type.LESS_THAN,\
		Lexer.Token.Type.LESS_THAN_EQUAL,\
		Lexer.Token.Type.GREATER_THAN,\
		Lexer.Token.Type.GREATER_THAN_EQUAL,\
		Lexer.Token.Type.EQUAL,\
		Lexer.Token.Type.NOT_EQUAL,\
		Lexer.Token.Type.AND,\
		Lexer.Token.Type.OR:
			return true
		_:
			return false
