class_name GDiagInterpreter

const Lexer := preload("res://addons/gdiag/gdiag_lexer.gd")
const Parser := preload("res://addons/gdiag/gdiag_parser.gd")

class Options:
	var show_partial_answer := false

class GDiagNode:
	var name: String
	var index: int

	func _init(p_name: String, p_index: int) -> void:
		name = p_name
		index = p_index

var _options: Options
var _context: Dictionary
var _gdiag: GDiag
var _tree: Parser.Result
var _node_stack: Array
var _placeholder_regex := RegEx.new()

# p_options: Interpreter configuration
func _init(p_options: Options) -> void:
	_options = p_options
	var res := _placeholder_regex.compile("{{\\s*([a-zA-Z0-9_]*?)\\s*}}")
	assert(res == OK, "Cannot compile _placeholder_regex")


# p_context: Should contain everything that was requested via __request__.
func start(p_context: Dictionary, p_gdiag: GDiag) -> GDiagResult:
	_gdiag = p_gdiag
	_context = p_context

	var lexer := Lexer.new()
	var parser := Parser.new()

	var tokens := lexer.get_tokens(_gdiag.source)
	var lexer_errors := lexer.get_errors()

	if lexer_errors.size() > 0:
		return GDiagResult.new().err(lexer_errors)

	_tree = parser.parse(tokens)
	var parser_errors = parser.get_errors()

	if parser_errors.size() > 0:
		return GDiagResult.new().err(parser_errors)

	var missing_from_context := _check_context(_context, _tree)
	if missing_from_context.size() > 0:
		return GDiagResult.new().err(missing_from_context)

	_node_stack = [GDiagNode.new("MAIN", -1)]

	return GDiagResult.new().ok(true)


func next(p_answer: String = "") -> GDiagResult:
	if _node_stack.size() == 0:
		return GDiagResult.new().ok()

	if p_answer == "":
		var current_node: Dictionary = _tree.nodes[_stack_get().name]
		if current_node["children"].size() <= _stack_get().index + 1:
			_node_stack.pop_back()
			return next()

		_stack_get().index += 1

		match current_node["children"][_stack_get().index]["type"]:
			Parser.Type.PARAGRAPH:
				var p := _visit_paragraph()
				if typeof(p.value) == TYPE_BOOL:
					return next()
				return p
			Parser.Type.JUMP:
				return _visit_jump()

		return GDiagResult.new().ok(true)
	elif _tree.nodes.has(p_answer):
		# If we saw the full answer, we can skip the first paragraph
		_node_stack.push_back(GDiagNode.new(p_answer, -1 if _options.show_partial_answer else 0))
		return next()
	else:
		return GDiagResult.new().err(GDiagError.new(
				GDiagError.Code.I_NODE_NOT_FOUND,
				-1, -1, # TODO
				{ "name": p_answer}))


func _visit_jump() -> GDiagResult:
	var jump: Dictionary = _tree.nodes[_stack_get().name]["children"][_stack_get().index]
	if !jump["condition"].empty():
		var result := _visit_expression(jump["condition"])
		if !result.is_ok():
			return result

		if !result.value:
			return next()

	if _tree.nodes.has(jump["to"]):
		_node_stack.push_back(GDiagNode.new(jump["to"], -1))
		return next()

	return GDiagResult.new().err(GDiagError.new(
			GDiagError.Code.I_NODE_NOT_FOUND,
			-1, -1, # TODO
			{ "name": jump["to"]}))


func _visit_paragraph() -> GDiagResult:
	var paragraph: Dictionary = _tree.nodes[_stack_get().name]["children"][_stack_get().index]

	for action in paragraph["actions"]:
		_visit_action(action)

	if !paragraph["condition"].empty():
		var result := _visit_expression(paragraph["condition"])
		if !result.is_ok():
			return result

		if !result.value:
			return GDiagResult.new().ok(false)

	return GDiagResult.new().ok({
		"character": paragraph["character"],
		"text": _visit_text(paragraph["text"]).value,
		"answers": _visit_answers()
	})


func _visit_answers() -> Array:
	var answers: Array = _tree.nodes[_stack_get().name]["children"][_stack_get().index]["answers"]
	var res := []

	for i in range(answers.size()):
		var condition: Dictionary = answers[i]["condition"]
		if !condition.empty():
			var result := _visit_expression(condition)

			if !result.is_ok():
				# TODO: handle error
				pass

			if !result.value:
				continue

		var answer = { "key": answers[i]["node"] }
		if _options.show_partial_answer:
			answer["text"] = _visit_text(_tree.nodes[answers[i]["node"]]["text"]).value
		else:
			# TODO: check node's children
			answer["text"] = _visit_text(_tree.nodes[answers[i]["node"]]["children"][0]["text"]).value
		res.push_back(answer)

	return res


func _visit_action(action: Dictionary) -> GDiagResult:
	var func_ref: FuncRef = _context[action["name"]]
	return GDiagResult.new().ok(func_ref.call_funcv(action["params"]))


func _visit_expression(p_exp: Dictionary) -> GDiagResult:
	# TODO: handle error
	match p_exp["type"]:
		Parser.Type.BINARY_OP:
			return _visit_binary_op(p_exp)
		Parser.Type.UNARY_OP:
			return _visit_unary_op(p_exp)
		Parser.Type.FUNCTION_CALL:
			return _visit_action(p_exp)
		Parser.Type.VARIABLE:
			return _visit_variable(p_exp)
		_: # should be literal
			return GDiagResult.new().ok(p_exp["value"])


func _visit_binary_op(p_op) -> GDiagResult:
	var left := _visit_expression(p_op["left"])
	var right := _visit_expression(p_op["right"])
	match p_op["operator"].type:
		Lexer.Token.Type.AND:
			return GDiagResult.new().ok(left.value && right.value)
		Lexer.Token.Type.OR:
			return GDiagResult.new().ok(left.value || right.value)
		Lexer.Token.Type.PLUS:
			return GDiagResult.new().ok(left.value + right.value)
		Lexer.Token.Type.MINUS:
			return GDiagResult.new().ok(left.value - right.value)
		Lexer.Token.Type.ASTERISK:
			return GDiagResult.new().ok(left.value * right.value)
		Lexer.Token.Type.SLASH:
			return GDiagResult.new().ok(left.value / right.value)
		Lexer.Token.Type.PERCENT_SIGN:
			return GDiagResult.new().ok(left.value % right.value)
		Lexer.Token.Type.GREATER_THAN:
			return GDiagResult.new().ok(left.value > right.value)
		Lexer.Token.Type.GREATER_THAN_EQUAL:
			return GDiagResult.new().ok(left.value >= right.value)
		Lexer.Token.Type.LESS_THAN:
			return GDiagResult.new().ok(left.value < right.value)
		Lexer.Token.Type.LESS_THAN_EQUAL:
			return GDiagResult.new().ok(left.value <= right.value)
		Lexer.Token.Type.EQUAL:
			return GDiagResult.new().ok(left.value == right.value)
		Lexer.Token.Type.NOT_EQUAL:
			return GDiagResult.new().ok(left.value != right.value)

	return GDiagResult.new().error(0)


func _visit_unary_op(p_op) -> GDiagResult:
	var operand := _visit_expression(p_op["operand"])
	match p_op["operator"].type:
		Lexer.Token.Type.UNARY_PLUS:
			return operand
		Lexer.Token.Type.UNARY_MINUS:
			return GDiagResult.new().ok(-operand.value)
#		Lexer.Token.Type.NOT:
#			return GDiagResult.new().ok(!operand.value)
	return GDiagResult.new().ok(0)


func _visit_variable(p_var) -> GDiagResult:
	return GDiagResult.new().ok(_context[p_var["name"]])


func _visit_text(p_text: String) -> GDiagResult:
	for x in _placeholder_regex.search_all(p_text):
		p_text = p_text.replace(x.strings[0], _context[x.strings[1]])

	return GDiagResult.new().ok(p_text)


# Only for type hints
func _stack_get() -> GDiagNode:
	return _node_stack[-1]


func _check_context(p_context: Dictionary, p_parser_result: Parser.Result) -> Array:
	var errors := []
	var context_type: int
	var requested_type: int

	for request_key in p_parser_result.request.keys():
		if !p_context.has(request_key):
			errors.push_back(GDiagError.new(
					GDiagError.Code.I_MISSING_FROM_CONTEXT,
					-1, -1, # TODO
					{ "name": request_key }))
			continue

		context_type = typeof(p_context[request_key])
		requested_type = p_parser_result.request[request_key]

		if (context_type == TYPE_INT && requested_type != Lexer.Token.Type.INT)\
				|| (context_type == TYPE_REAL && requested_type != Lexer.Token.Type.FLOAT)\
				|| (context_type == TYPE_STRING && requested_type != Lexer.Token.Type.STRING)\
				|| (context_type == TYPE_BOOL && requested_type != Lexer.Token.Type.BOOL)\
				|| (p_context[request_key] is FuncRef && requested_type != Lexer.Token.Type.FUNC):
			errors.push_back(GDiagError.new(
					GDiagError.Code.I_SHOULD_BE_OF_TYPE,
					-1, -1, # TODO
					{
						"name": request_key,
						"type": Lexer.Token.get_type_name(requested_type),
						"got": p_context[request_key] }))

	return errors

