# class_name GDiagParser

const GDiagLexer: GDScript = preload("res://addons/gdiag/gdiag_lexer.gd")

class Result:
	var request: Dictionary = {}
	var characters: Dictionary = {}
	var nodes: Dictionary = {}

	func _to_string() -> String:
		return JSON.print({ "request": request, "characters": characters, "nodes": nodes }, "\t")

const PRESEDENCE := {
	GDiagLexer.Token.Type.LEFT_PARENTHESIS: -99,
	GDiagLexer.Token.Type.OR: -1,
	GDiagLexer.Token.Type.AND: -1,
	GDiagLexer.Token.Type.LESS_THAN: 0,
	GDiagLexer.Token.Type.LESS_THAN_EQUAL: 0,
	GDiagLexer.Token.Type.GREATER_THAN: 0,
	GDiagLexer.Token.Type.GREATER_THAN_EQUAL: 0,
	GDiagLexer.Token.Type.EQUAL: 0,
	GDiagLexer.Token.Type.NOT_EQUAL: 0,
	GDiagLexer.Token.Type.PLUS: 1,
	GDiagLexer.Token.Type.MINUS: 1,
	GDiagLexer.Token.Type.ASTERISK: 2,
	GDiagLexer.Token.Type.SLASH: 2,
	GDiagLexer.Token.Type.PERCENT_SIGN: 2,

	GDiagLexer.Token.Type.UNARY_PLUS: 3,
	GDiagLexer.Token.Type.UNARY_MINUS: 3,
	GDiagLexer.Token.Type.RIGHT_PARENTHESIS: 99
}

enum Type {
	ID, PARAGRAPH, JUMP, FUNCTION_CALL, ANSWER,
	BINARY_OP, UNARY_OP,
	INT, FLOAT, BOOL, STRING
	VARIABLE, LITERAL
}


var _tokens: Array
var _errors: Array

var _current_index: int = -1

func get_errors() -> Array:
	return _errors


# TODO: BFM
"""
<gdiag_script>				::= <request> <characters> <node>+
<request>					::= "__request__" (<id> ":" <type>)+
"""
func parse(p_tokens: Array) -> Result:
	_tokens = p_tokens
	var result := Result.new()

	if _peek().type == GDiagLexer.Token.Type.REQUEST:
		result.request = _parse_request()
		if result.request.empty():
			return result

	if _peek().type == GDiagLexer.Token.Type.CHARACTERS:
		result.characters = _parse_characters()
		if result.characters.empty():
			return result

	while _peek().type != GDiagLexer.Token.Type.EOF:
		var node := _parse_node()
		if node.empty():
			return result
		result.nodes[node.name] = node

	return result


func _parse_request() -> Dictionary:
	var request := {}
	_eat()

	while _peek().type == GDiagLexer.Token.Type.ID:
		var name: String = _eat().value

		if _match_and_eat(GDiagLexer.Token.Type.COLON) == null:
			return {}

		match _peek().type:
			GDiagLexer.Token.Type.INT,\
			GDiagLexer.Token.Type.FLOAT,\
			GDiagLexer.Token.Type.BOOL,\
			GDiagLexer.Token.Type.STRING,\
			GDiagLexer.Token.Type.FUNC:
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
		var name := _match_and_eat(GDiagLexer.Token.Type.ID)
		if name == null:
			return {}

		# In the future we can assign some kind of metadata to the characters
		characters[name.value] = true

		if _peek().type == GDiagLexer.Token.Type.COMMA:
			_eat()
			continue
		break

	return characters


func _parse_node() -> Dictionary:
	if _match_and_eat(GDiagLexer.Token.Type.LEFT_SQUARE_BRACKET) == null:
		return {}

	var node := {
		"name": _match_and_eat(GDiagLexer.Token.Type.ID).value,
		"children": []
	}
	if node["name"] == null:
		return {}

	if _match_and_eat(GDiagLexer.Token.Type.RIGHT_SQUARE_BRACKET) == null:
		return {}

	if _match_and_eat(GDiagLexer.Token.Type.COLON) == null:
		return {}

	while true:
		if _peek().type == GDiagLexer.Token.Type.JUMP:
			var res := _parse_jump()
			if res.empty():
				return {}
			node["children"].push_back(res)
		elif _peek().type == GDiagLexer.Token.Type.ID:
			var res := _parse_paragraph()
			if res.empty():
				return {}
			node["children"].push_back(res)
		else:
			break

	if node["children"].size() == 0:
		_errors.push_back(GDiagError.new(
				GDiagError.Code.P_NODE_HAS_NO_PARAGRAPH,
				_peek().line,
				_peek().column,
				{ "name": node["name"] }))
		return {}

	return node


func _parse_id() -> Dictionary:
	var name: String = _match_and_eat(GDiagLexer.Token.Type.ID).value
	if name == null:
		return {}

	return { "type": Type.ID, "name": name }


func _parse_paragraph() -> Dictionary:
	var p := {
		"type": Type.PARAGRAPH,
		"character": _eat().value,
		"condition": {},
		"actions": [],
		"text": "",
		"answers": []
	}
	_match_and_eat(GDiagLexer.Token.Type.COLON)
	if _peek().type == GDiagLexer.Token.Type.IF:
		var condition = _parse_if()
		if condition.empty():
			return {}
		p["condition"] = condition
		if _peek().type == GDiagLexer.Token.Type.COMMA:
			_eat()

	while _peek().type == GDiagLexer.Token.Type.ID:
		var action := _parse_function_call()
		if action.empty():
			return {}

		p["actions"].push_back(action)
		if _peek().type == GDiagLexer.Token.Type.COMMA:
			_eat()

	p["text"] = _match_and_eat(GDiagLexer.Token.Type.STRING_LITERAL).value

	if p["text"] == null:
		return {}

	while _peek().type == GDiagLexer.Token.Type.MINUS:
		var answer := _parse_answer()
		if answer.empty():
			return {}
		p["answers"].push_back(answer)

	return p


func _parse_if() -> Dictionary:
	_eat()
	return _parse_expression()


func _parse_jump() -> Dictionary:
	_errors.push_back(GDiagError.new(GDiagError.Code.P_NOT_IMPLEMENTED_YET, _peek().line, _peek().column))
	return {}


# It's a hacky implementation of the Shunting yard algorithm
func _parse_expression() -> Dictionary:
	var operator_stack := []
	var output_queue := []

	while true:
		match _peek().type:
			GDiagLexer.Token.Type.INT_LITERAL,\
			GDiagLexer.Token.Type.FLOAT_LITERAL,\
			GDiagLexer.Token.Type.BOOL_LITERAL,\
			GDiagLexer.Token.Type.STRING_LITERAL:
				output_queue.push_back(_parse_literal())
			GDiagLexer.Token.Type.ID:
				if _peek(2).type == GDiagLexer.Token.Type.LEFT_PARENTHESIS:
					output_queue.push_back(_parse_function_call())
				else:
					output_queue.push_back(_parse_variable())
			GDiagLexer.Token.Type.LEFT_PARENTHESIS:
				operator_stack.push_back(_eat())
			GDiagLexer.Token.Type.RIGHT_PARENTHESIS:
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
					var op: GDiagLexer.Token = operator_stack.pop_back()
					if op.type == GDiagLexer.Token.Type.LEFT_PARENTHESIS:
						break
					output_queue.push_back(op)
			GDiagLexer.Token.Type.PLUS,\
			GDiagLexer.Token.Type.MINUS,\
			GDiagLexer.Token.Type.ASTERISK,\
			GDiagLexer.Token.Type.SLASH,\
			GDiagLexer.Token.Type.PERCENT_SIGN,\
			GDiagLexer.Token.Type.GREATER_THAN,\
			GDiagLexer.Token.Type.GREATER_THAN_EQUAL,\
			GDiagLexer.Token.Type.LESS_THAN,\
			GDiagLexer.Token.Type.LESS_THAN_EQUAL,\
			GDiagLexer.Token.Type.EQUAL,\
			GDiagLexer.Token.Type.NOT_EQUAL,\
			GDiagLexer.Token.Type.AND,\
			GDiagLexer.Token.Type.OR:
				if operator_stack.size() == 0:
					var token := _eat()
					if  _current_index == 0:
						token.type = GDiagLexer.Token.Type.UNARY_MINUS
					operator_stack.push_back(token)
				elif _current_index == -1 || _is_op(_peek(0).type):
					var token := _eat()
					token.type = GDiagLexer.Token.Type.UNARY_MINUS
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
		else: match output_queue[0].type:
			GDiagLexer.Token.Type.UNARY_MINUS:
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

	if operator_stack.size() != 1:
		# I don't know if this branch is reachable or not.
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
		GDiagLexer.Token.Type.INT_LITERAL:
			res["type"] = Type.LITERAL
			res["type_type"] = Type.INT
			res["value"] = _eat().value
		GDiagLexer.Token.Type.FLOAT_LITERAL:
			res["type"] = Type.LITERAL
			res["type_type"] = Type.FLOAT
			res["value"] = _eat().value
		GDiagLexer.Token.Type.BOOL_LITERAL:
			res["type"] = Type.LITERAL
			res["type_type"] = Type.BOOL
			res["value"] = _eat().value
		GDiagLexer.Token.Type.STRING_LITERAL:
			res["type"] = Type.LITERAL
			res["type_type"] = Type.STRING
			res["value"] = _eat().value

	return res


func _parse_unary(op: GDiagLexer.Token, operand: Dictionary) -> Dictionary:
	# TODO: Check type
	return {
		"type": Type.UNARY_OP,
		"operator": op,
		"operand": operand
	}


func _parse_binary(left: Dictionary, op: GDiagLexer.Token, right: Dictionary) -> Dictionary:
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

	_match_and_eat(GDiagLexer.Token.Type.LEFT_PARENTHESIS)
	# TODO: parse parameters
	_match_and_eat(GDiagLexer.Token.Type.RIGHT_PARENTHESIS)

	return function


func _parse_answer() -> Dictionary:
	_eat()
	var answer := {
		"type": Type.ANSWER,
		"node": _match_and_eat(GDiagLexer.Token.Type.ID).value,
		"condition": {},
		"optional": false
	}

	if answer["node"] == null:
		return {}

	if _match_and_eat(GDiagLexer.Token.Type.COMMA) == null:
		return {}

	if _peek().type == GDiagLexer.Token.Type.IF:
		var condition := _parse_if()
		if condition.empty():
			return {}
		answer["condition"] = condition
		if _match_and_eat(GDiagLexer.Token.Type.COMMA) == null:
			return {}

	if _peek().type == GDiagLexer.Token.Type.OPTIONAL:
		_eat()
		answer["optional"] = true
	elif _peek().type == GDiagLexer.Token.Type.MAIN:
		_eat()
		answer["optional"] = false
	else:
		_errors.push_back(GDiagError.new(
				GDiagError.Code.P_ANSWER_HAS_TO_END_OPTIONAL_OR_MAIN,
				_peek().line,
				_peek().column))
		return {}

	return answer


func _peek(p_n: int = 1) -> GDiagLexer.Token:
	return _tokens[_current_index + p_n]


func _eat() -> GDiagLexer.Token:
	_current_index += 1
	return _tokens[_current_index]


func _match_and_eat(p_type: int) -> GDiagLexer.Token:
	if _peek().type != p_type:
		_errors.push_back(GDiagError.new(
				GDiagError.Code.P_UNEXPECTED_TOKEN,
				_peek().line,
				_peek().column,
				{
					"expected": GDiagLexer.Token.get_type_name(p_type),
					"token": GDiagLexer.Token.get_type_name(_peek().type)
				}))
		return null
	_current_index += 1
	return _tokens[_current_index]


func _is_op(type: int) -> bool:
	match type:
		GDiagLexer.Token.Type.PLUS,\
		GDiagLexer.Token.Type.MINUS,\
		GDiagLexer.Token.Type.ASTERISK,\
		GDiagLexer.Token.Type.SLASH,\
		GDiagLexer.Token.Type.PERCENT_SIGN,\
		GDiagLexer.Token.Type.LESS_THAN,\
		GDiagLexer.Token.Type.LESS_THAN_EQUAL,\
		GDiagLexer.Token.Type.GREATER_THAN,\
		GDiagLexer.Token.Type.GREATER_THAN_EQUAL,\
		GDiagLexer.Token.Type.EQUAL,\
		GDiagLexer.Token.Type.NOT_EQUAL,\
		GDiagLexer.Token.Type.AND,\
		GDiagLexer.Token.Type.OR:
			return true
		_:
			return false
