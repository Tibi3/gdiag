class_name GDiagInterpreter

const Lexer := preload("res://addons/gdiag/gdiag_lexer.gd")
const Parser := preload("res://addons/gdiag/gdiag_parser.gd")

class Options:
	var show_partial_answer := false
	var enable_localization := false

class GDiagNode:
	var name: String
	var index: int

	func _init(p_name: String, p_index: int) -> void:
		name = p_name
		index = p_index

class GDiagParagraph:
	var character: String
	var text: String
	var answers: Array

	func _init(p_character: String, p_text: String, p_answers: Array) -> void:
		character = p_character
		text = p_text
		answers = p_answers


var _options: Options
var _context: Object
var _gdiag: GDiag
var _tree: Parser.Result
var _node_stack: Array
var _placeholder_regex := RegEx.new()

# p_options: Interpreter configuration
func _init(p_options: Options = Options.new()) -> void:
	_options = p_options
	var res := _placeholder_regex.compile("{{\\s*([a-zA-Z0-9_]*?)\\s*}}")
	assert(res == OK, "Cannot compile _placeholder_regex")


func start(p_context: Object, p_gdiag: GDiag) -> GDiagResult:
	_gdiag = p_gdiag
	_context = p_context

	print(_context.get("say_hello"))

	var lexer := Lexer.new()
	var parser := Parser.new()

	var lexer_result := lexer.get_tokens(_gdiag.source)

	if lexer_result.is_error():
		return GDiagResult.new().err(lexer_result.value)

	var parser_result := parser.parse(lexer_result.value)

	if parser_result.is_error():
		return parser_result

	_tree = parser_result.value

	_node_stack = [GDiagNode.new("MAIN", -1)]

	return GDiagResult.new().ok()


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
				var p := _visit_paragraph(current_node["children"][_stack_get().index])
				# if paragraph condition evaluates to false we can skip it
				if typeof(p.value) == TYPE_BOOL && p.value == false:
					return next()
				return p
			Parser.Type.JUMP:
				return _visit_jump(current_node["children"][_stack_get().index])
			Parser.Type.ONE_OF:
				return _visit_one_of(current_node["children"][_stack_get().index])

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


func _visit_jump(p_jump: Dictionary) -> GDiagResult:
	if !p_jump["condition"].empty():
		var result := _visit_expression(p_jump["condition"])
		if result.is_error():
			return result

		if !result.value:
			return next()

	if _tree.nodes.has(p_jump["to"]):
		_node_stack.push_back(GDiagNode.new(p_jump["to"], -1))
		return next()

	return GDiagResult.new().err(GDiagError.new(
			GDiagError.Code.I_NODE_NOT_FOUND,
			-1, -1, # TODO
			{ "name": p_jump["to"]}))


func _visit_one_of(p_one_of: Dictionary) -> GDiagResult:
	if !p_one_of["condition"].empty():
		var res := _visit_expression(p_one_of["condition"])
		if res.is_error():
			return res
		if !res.value:
			return next()

	var weight_sum := 0
	for opt in p_one_of["options"]:
		weight_sum += opt["weight"]

	var number := randi() % weight_sum
	var index := 0
	for opt in p_one_of["options"]:
		if number < opt["weight"]:
			break
		number -= opt["weight"]
		index += 1

	return _visit_paragraph(p_one_of["options"][index])


func _visit_paragraph(p_paragraph: Dictionary) -> GDiagResult:
	for action in p_paragraph["actions"]:
		_visit_identifier(action)

	if !p_paragraph["condition"].empty():
		var result := _visit_expression(p_paragraph["condition"])
		if result.is_error():
			return result

		if !result.value:
			return GDiagResult.new().ok(false)

	return GDiagResult.new().ok(GDiagParagraph.new(
			p_paragraph["character"],
			_visit_text(p_paragraph["text"]).value,
			_visit_answers(p_paragraph["answers"])))


func _visit_answers(p_answers: Array) -> Array:
	var res := []

	for i in range(p_answers.size()):
		var condition: Dictionary = p_answers[i]["condition"]
		if !condition.empty():
			var result := _visit_expression(condition)

			if result.is_error():
				# TODO: handle error
				pass

			if !result.value:
				continue

		var answer = { "key": p_answers[i]["node"] }
		if _options.show_partial_answer:
			answer["text"] = _visit_text(_tree.nodes[p_answers[i]["node"]]["text"]).value
		else:
			# TODO: check node's children
			# TODO: what should happen if this is a 'one_of' node?
			answer["text"] = _visit_text(_tree.nodes[p_answers[i]["node"]]["children"][0]["text"]).value
		res.push_back(answer)

	return res


func _visit_expression(p_exp: Dictionary) -> GDiagResult:
	# TODO: handle error
	match p_exp["type"]:
		Parser.Type.BINARY_OP:
			return _visit_binary_op(p_exp)
		Parser.Type.UNARY_OP:
			return _visit_unary_op(p_exp)
		Parser.Type.IDENTIFIER:
			return _visit_identifier(p_exp)
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


func _visit_identifier(p_id: Dictionary, p_context = _context) -> GDiagResult:
	# TODO: add error handling
	var res = p_context.callv(p_id.get("name"), p_id.get("args")) if p_id["call"] else p_context[p_id.get("name")]

	if p_id["next"].empty():
		return GDiagResult.new().ok(res)

	return _visit_identifier(p_id["next"], res)


func _visit_text(p_text: Dictionary) -> GDiagResult:
	var text: String = tr(p_text["key"]) if _options.enable_localization else p_text["value"]

	for x in _placeholder_regex.search_all(text):
		text = text.replace(x.strings[0], _context.get(x.strings[1]))

	return GDiagResult.new().ok(text)


# Only for type hints
func _stack_get() -> GDiagNode:
	return _node_stack[-1]


func _check_context(p_context: Dictionary, p_parser_result: Parser.Result) -> Array:
	# TODO: check things
	return []

