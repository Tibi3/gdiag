# class_name GDiagParser

const GDiagLexer: GDScript = preload("res://addons/gdiag/gdiag_lexer.gd")

class Result:
	var request: Dictionary = {}
	var characters: Dictionary = {}
	var nodes: Dictionary = {}

	func _to_string() -> String:
		return JSON.print({ "request": request, "characters": characters, "nodes": nodes }, "\t")

enum Type { ID, PARAGRAPH, JUMP, FUNCTION_CALL, ANSWER }

var _tokens: Array
var _errors: Array

var _current_index: int = -1

func get_errors() -> Array:
	return _errors

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

	while _peek().type == GDiagLexer.Token.Type.ID:
		match _peek(2).type:
			GDiagLexer.Token.Type.COLON:
				var res := _parse_paragraph()
				if res.empty():
					return {}
				node["children"].push_back(res)
			GDiagLexer.Token.Type.COMMA:
				var res := _parse_jump()
				if res.empty():
					return {}
				node["children"].push_back(res)
			_:
				_errors.push_back(GDiagError.new(
						GDiagError.Code.P_UNEXPECTED_TOKEN,
						_peek(2).line,
						_peek(2).column,
						{
							"expected": GDiagLexer.Token.get_type_name(GDiagLexer.Token.Type.COLON)
									+ " or " + GDiagLexer.Token.get_type_name(GDiagLexer.Token.Type.COMMA),
							"token": GDiagLexer.Token.get_type_name(_peek().type)
						}
				))
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
	_eat()
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
	_errors.push_back(GDiagError.new(GDiagError.Code.P_NOT_IMPLEMENTED_YET, _peek().line, _peek().column))
	return {}


func _parse_jump() -> Dictionary:
	_errors.push_back(GDiagError.new(GDiagError.Code.P_NOT_IMPLEMENTED_YET, _peek().line, _peek().column))
	return {}


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
