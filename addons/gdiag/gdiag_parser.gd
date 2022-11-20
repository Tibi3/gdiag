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


func parse(p_tokens: Array) -> Result:
	_tokens = p_tokens
	_errors = []
	_current_index = -1
	_parse_result = Result.new()

	if _peek().type == Lexer.Token.Type.REQUEST:
		_parse_result.request = _parse_request()
		if _parse_result.request.empty():
			return _parse_result

	if _peek().type == Lexer.Token.Type.CHARACTERS:
		_parse_result.characters = _parse_characters()
		if _parse_result.characters.empty():
			return _parse_result

	while _peek().type != Lexer.Token.Type.EOF:
		var node := _parse_node()
		if node.empty():
			return _parse_result
		_parse_result.nodes[node.name] = node

	return _parse_result


func _parse_request() -> Dictionary:
	var request := {}
	_eat()

	while _peek().type == Lexer.Token.Type.ID:
		var name: String = _eat().value

		if _match_and_eat(Lexer.Token.Type.COLON) == null:
			return {}

		match _peek().type:
			Lexer.Token.Type.INT,\
			Lexer.Token.Type.FLOAT,\
			Lexer.Token.Type.BOOL,\
			Lexer.Token.Type.STRING,\
			Lexer.Token.Type.FUNC:
				request[name] = _eat().type
			_:
				_errors.push_back(GDiagError.new(
						GDiagError.Code.P_EXPECTED_TYPE,
						_peek().line,
						_peek().column,
						{ "token": _peek() }))
				break

	return request


func _parse_characters() -> Dictionary:
	var characters := {}
	_eat()
	while true:
		var name := _match_and_eat(Lexer.Token.Type.ID)
		if name == null:
			return {}

		# In the future we can assign some kind of metadata to the characters
		characters[name.value] = true

		if _peek().type == Lexer.Token.Type.COMMA:
			_eat()
			continue
		break

	return characters


func _parse_node() -> Dictionary:
	if _match_and_eat(Lexer.Token.Type.LEFT_SQUARE_BRACKET) == null:
		return {}

	var node := {
		"name": _match_and_eat(Lexer.Token.Type.ID).value,
		"children": []
	}
	if node["name"] == null:
		return {}

	if _match_and_eat(Lexer.Token.Type.RIGHT_SQUARE_BRACKET) == null:
		return {}

	if _match_and_eat(Lexer.Token.Type.COLON) == null:
		return {}

	while true:
		var res: Dictionary

		match _peek().type:
			Lexer.Token.Type.JUMP:
				res = _parse_jump()
			Lexer.Token.Type.ID:
				res = _parse_paragraph()
			Lexer.Token.Type.ONE_OF:
				res = _parse_one_of()
			_: break

		if res.empty():
			return {}
		node["children"].push_back(res)

	if node["children"].size() == 0:
		_errors.push_back(GDiagError.new(
				GDiagError.Code.P_NODE_HAS_NO_PARAGRAPH,
				_peek().line,
				_peek().column,
				{ "name": node["name"] }))
		return {}

	return node


func _parse_id() -> Dictionary:
	var name: String = _match_and_eat(Lexer.Token.Type.ID).value
	if name == null:
		return {}

	return { "type": Type.ID, "name": name }


func _parse_one_of() -> Dictionary:
	var one_of := {
		"type": Type.ONE_OF,
		"condition": {},
		"options": []
	}
	_eat()
	if _peek().type == Lexer.Token.Type.IF:
		var condition = _parse_if()
		if condition.empty():
			return {}
		one_of["condition"] = condition
	_match_and_eat(Lexer.Token.Type.COLON)

	while _peek().type == Lexer.Token.Type.MINUS:
		_eat()
		var weight := 1
		if _peek().type == Lexer.Token.Type.INT_LITERAL:
			weight = _eat().value

		if _peek().type != Lexer.Token.Type.ID:
			_errors.push_back(GDiagError.new(
				GDiagError.Code.P_UNEXPECTED_TOKEN,
				_peek().line,
				_peek().column,
				{
					"expected": Lexer.Token.get_type_name(Lexer.Token.Type.ID),
					"token": Lexer.Token.get_type_name(_peek().type)
				}))
			return {}

		var p := _parse_paragraph()
		if p.empty():
			return {}

		p["weight"] = weight
		one_of["options"].push_back(p)

	if one_of["options"].size() == 0:
		# TODO: error
		pass

	return one_of


func _parse_paragraph() -> Dictionary:
	var character := _eat()

	if !_parse_result.characters.has(character.value):
		_errors.push_back(GDiagError.new(
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
		var condition = _parse_if()
		if condition.empty():
			return {}
		p["condition"] = condition

	_match_and_eat(Lexer.Token.Type.COLON)

	while _peek().type == Lexer.Token.Type.ID:
		var action := _parse_function_call()
		if action.empty():
			return {}

		p["actions"].push_back(action)
		if _peek().type == Lexer.Token.Type.COMMA:
			_eat()

	p["text"] = _parse_text()

	if p["text"].empty():
		return {}

	# if we are in a one_of block then '- ID' has two different meaning based on what is the value of the ID.
	while _peek().type == Lexer.Token.Type.MINUS\
			&& _peek(2).type == Lexer.Token.Type.ID\
			&& !_parse_result.characters.has(_peek(2).value):
		var answer := _parse_answer()
		if answer.empty():
			return {}
		p["answers"].push_back(answer)

	return p


func _parse_if() -> Dictionary:
	_eat()
	return _parse_expression()


func _parse_jump() -> Dictionary:
	var jump := { "type": Type.JUMP, "condition": {}, "to": "" }
	_eat() # jump

	if _peek().type == Lexer.Token.Type.IF:
		var condition := _parse_if()
		if condition.empty():
			return {}
		jump["condition"] = condition

	_match_and_eat(Lexer.Token.Type.COLON)

	var to := _match_and_eat(Lexer.Token.Type.ID)
	if to == null:
		return {}

	jump["to"] = to.value

	return jump


func _parse_text() -> Dictionary:
	var text_token := _match_and_eat(Lexer.Token.Type.STRING_LITERAL)
	var last_token := text_token

	if text_token == null:
		return {}

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

	return text


# It's a hacky implementation of the Shunting yard algorithm
func _parse_expression() -> Dictionary:
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
				if _peek(2).type == Lexer.Token.Type.LEFT_PARENTHESIS:
					output_queue.push_back(_parse_function_call())
				else:
					output_queue.push_back(_parse_variable())
			Lexer.Token.Type.LEFT_PARENTHESIS:
				operator_stack.push_back(_eat())
			Lexer.Token.Type.RIGHT_PARENTHESIS:
				_eat()
				if operator_stack.size() <= 1:
					_errors.push_back(GDiagError.new(
							GDiagError.Code.P_UNEXPECTED_RP,
							_peek().line,
							_peek().column))
					return {}
				while true:
					if operator_stack.size() == 0:
						_errors.push_back(GDiagError.new(
								GDiagError.Code.P_UNEXPECTED_RP,
								_peek().line,
								_peek().column))
						return {}
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
					_errors.push_back(GDiagError.new(
								GDiagError.Code.P_EXPECTED_OPERAND_AFTER_UNARY_OP,
								_peek().line,
								_peek().column))
					return {}
				operator_stack.push_back(_parse_unary(output_queue.pop_front(), operator_stack.pop_back()))
			_:
				if operator_stack.size() < 2:
					_errors.push_back(GDiagError.new(
							GDiagError.Code.P_UNEXPECTED_TOKEN_IN_EXPRESSION,
							_peek().line,
							_peek().column,
							{"token": output_queue[0]}))
					return {}
				var right = operator_stack.pop_back()
				var left = operator_stack.pop_back()
				operator_stack.push_back(_parse_binary(left, output_queue.pop_front(), right))

	if operator_stack.size() > 1:
		_errors.push_back(GDiagError.new(
				GDiagError.Code.P_UNEXPECTED_TOKEN_IN_EXPRESSION,
				_peek().line,
				_peek().column,
				{"token": operator_stack[0]}))
		return {}

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


func _parse_variable() -> Dictionary:
	return {
		"type": Type.VARIABLE,
		"name": _eat().value
	}


func _parse_function_call() -> Dictionary:
	var function := {
		"type": Type.FUNCTION_CALL,
		"params": [],
		"name": _eat().value
	}

	_match_and_eat(Lexer.Token.Type.LEFT_PARENTHESIS)
	# TODO: parse parameters
	_match_and_eat(Lexer.Token.Type.RIGHT_PARENTHESIS)

	return function


func _parse_answer() -> Dictionary:
	_eat()
	var answer := {
		"type": Type.ANSWER,
		"node": _match_and_eat(Lexer.Token.Type.ID).value,
		"condition": {},
		"optional": false
	}

	if answer["node"] == null:
		return {}

	if _peek().type == Lexer.Token.Type.IF:
		var condition := _parse_if()
		if condition.empty():
			return {}
		answer["condition"] = condition

	if _match_and_eat(Lexer.Token.Type.COMMA) == null:
		return {}

	if _peek().type == Lexer.Token.Type.OPTIONAL:
		_eat()
		answer["optional"] = true
	elif _peek().type == Lexer.Token.Type.MAIN:
		_eat()
		answer["optional"] = false
	else:
		_errors.push_back(GDiagError.new(
				GDiagError.Code.P_ANSWER_HAS_TO_END_OPTIONAL_OR_MAIN,
				_peek().line,
				_peek().column))
		return {}

	return answer


func _peek(p_n: int = 1) -> Lexer.Token:
	return _tokens[_current_index + p_n]


func _eat() -> Lexer.Token:
	_current_index += 1
	return _tokens[_current_index]


func _match_and_eat(p_type: int) -> Lexer.Token:
	if _peek().type != p_type:
		_errors.push_back(GDiagError.new(
				GDiagError.Code.P_UNEXPECTED_TOKEN,
				_peek().line,
				_peek().column,
				{
					"expected": Lexer.Token.get_type_name(p_type),
					"token": Lexer.Token.get_type_name(_peek().type)
				}))
		return null
	_current_index += 1
	return _tokens[_current_index]


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
