# class_name GDiagLexer

class Token:
	enum Type {
		RIGHT_SQUARE_BRACKET, LEFT_SQUARE_BRACKET, RIGHT_PARENTHESIS, LEFT_PARENTHESIS,
		COLON, COMMA, PLUS, MINUS, SLASH, ASTERISK,
		EQUAL, NOT_EQUAL, LESS_THAN, LESS_THAN_EQUAL, GREATER_THAN, GREATER_THAN_EQUAL,
		REQUEST, CHARACTERS,
		IF, CLOSE,
		ONCE, OPTIONAL,
		ID,
		INT_LITERAL, FLOAT_LITERAL, BOOL_LITERAL, STRING_LITERAL,
		EOF
	}

	var type: int	# Token.Type
	var value 		# String, int, float, bool, null
	var line: int
	var column: int

	func _init(p_type: int, p_value, p_line: int, p_column: int) -> void:
		type = p_type
		value = p_value
		line = p_line
		column = p_column

	func _to_string() -> String:
		return "{ type: %s, value: '%s' }" % [ Type.keys()[type], value ]

var TOKEN_PATTERNS := []

var _comment_regex: RegEx
var _whitespace_regex: RegEx
var _errors := []
var _current_line: int = 1
var _current_column: int = 1

func _init() -> void:
	_add_pattern_to(Token.Type.RIGHT_SQUARE_BRACKET, "^]")
	_add_pattern_to(Token.Type.LEFT_SQUARE_BRACKET, "^\\[")
	_add_pattern_to(Token.Type.RIGHT_PARENTHESIS, "^\\)")
	_add_pattern_to(Token.Type.LEFT_PARENTHESIS, "^\\(")
	_add_pattern_to(Token.Type.COLON, "^:")
	_add_pattern_to(Token.Type.COMMA, "^,")
	_add_pattern_to(Token.Type.PLUS, "^\\+")
	_add_pattern_to(Token.Type.MINUS, "^\\-")
	_add_pattern_to(Token.Type.SLASH, "^/")
	_add_pattern_to(Token.Type.ASTERISK, "^\\*")
	_add_pattern_to(Token.Type.EQUAL, "^==")
	_add_pattern_to(Token.Type.NOT_EQUAL, "^!=")
	_add_pattern_to(Token.Type.LESS_THAN_EQUAL, "^<=")
	_add_pattern_to(Token.Type.GREATER_THAN_EQUAL, "^>=")
	_add_pattern_to(Token.Type.LESS_THAN, "^<")
	_add_pattern_to(Token.Type.GREATER_THAN, "^>")
	_add_pattern_to(Token.Type.REQUEST, "^__request__")
	_add_pattern_to(Token.Type.CHARACTERS, "^__characters__")
	_add_pattern_to(Token.Type.IF, "^if")
	_add_pattern_to(Token.Type.CLOSE, "^close")
	_add_pattern_to(Token.Type.ONCE, "^once")
	_add_pattern_to(Token.Type.OPTIONAL, "^optional")
	_add_pattern_to(Token.Type.FLOAT_LITERAL, "^\\d+\\.\\d+")
	_add_pattern_to(Token.Type.INT_LITERAL, "^\\d+")
	_add_pattern_to(Token.Type.BOOL_LITERAL, "^true|false")
	_add_pattern_to(Token.Type.STRING_LITERAL, "^\"((?:\\\\|\\\\\"|[^\"])*)\"")
	_add_pattern_to(Token.Type.ID, "^[a-zA-Z_]+[a-zA-Z_0-9]*")
	
	_comment_regex = _create_regex("^#.*")
	_whitespace_regex = _create_regex("^[^\\S\\r\\n]+")

	assert(TOKEN_PATTERNS.size() == Token.Type.keys().size() - 1, "Should be one pattern for every token type except EOF")

# reset errors, return an array of tokens
func get_tokens(p_from: String) -> Array:
	_errors = []

	var tokens := []
	var loop_detector := 0
	var original_length: int

	while p_from.length() > 0:
		loop_detector += 1
		assert(loop_detector < 99, "infinite loop")
		
		original_length = p_from.length()
		
		p_from = _whitespace_regex.sub(p_from, "")
		_current_column += original_length - p_from.length()
		
		if p_from[0] == '\n':
			p_from.erase(0, 1)
			_current_line += 1
			_current_column = 1
			continue
			
		if p_from[0] == '#':
			p_from = _comment_regex.sub(p_from, "")
			continue
			
		var found_token := false
		for pattern in TOKEN_PATTERNS:
			var res := (pattern["pattern"] as RegEx).search(p_from)
			if res != null:
				var val := p_from.substr(0, res.get_end())
				# TODO: parse value
				tokens.push_back(Token.new(pattern["type"], val, _current_line, _current_column))
				_current_column += val.length()
				p_from = p_from.substr(res.get_end())
				found_token = true
				break
		
		if found_token:
			continue
		
		if p_from[0] == "\"":
			_errors.push_back({
				"code": "L002",
				"msg": "Quotation mark at line %d:%d has no closing quotation mark." % [_current_line, _current_column],
				"line": _current_line,
				"column": _current_column
			})
		else:
			_errors.push_back({
				"code": "L001",
				"msg": "Unexpected token '%s' at line %d:%d." % [p_from[0], _current_line, _current_column],
				"line": _current_line,
				"column": _current_column
			})
		break
		
	return tokens


func get_errors() -> Array:
	return _errors


func _add_pattern_to(p_token_type: int, p_regex: String) -> void:
	TOKEN_PATTERNS.push_back({
		"type": p_token_type,
		"pattern": _create_regex(p_regex)
	})


func _create_regex(p_regex: String) -> RegEx:
	var regex := RegEx.new()
	var res := regex.compile(p_regex)
	assert(res == OK, "Could not complie '%s' regular expression." % p_regex)
	return regex
