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

# p_options: Interpreter configuration
func _init(p_options: Options) -> void:
	_options = p_options


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
		return GDiagResult.new().ok(true)

	if p_answer == "":
		var current_node: Dictionary = _tree.nodes[_stack_get().name]
		if current_node["children"].size() <= _stack_get().index + 1:
			_node_stack.pop_back()
			return next()

		_stack_get().index += 1

		match current_node["children"][_stack_get().index]["type"]:
			Parser.Type.PARAGRAPH:
				return _visit_paragraph()
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
				-1, -1, #TODO
				{ "name": p_answer}))


func _visit_jump() -> GDiagResult:
	var jump: Dictionary = _tree.nodes[_stack_get().name]["children"][_stack_get().index]
	#TODO: check condition
	if _tree.nodes.has(jump["to"]):
		_node_stack.push_back(GDiagNode.new(jump["to"], -1))
		return next()

	return GDiagResult.new().err(GDiagError.new(
			GDiagError.Code.I_NODE_NOT_FOUND,
			-1, -1, #TODO
			{ "name": jump["to"]}))


func _visit_paragraph() -> GDiagResult:
	var paragraph: Dictionary = _tree.nodes[_stack_get().name]["children"][_stack_get().index]
	#TODO: condition
	return GDiagResult.new().ok({
		"character": paragraph["character"],
		#TODO: handle placeholders
		"text": paragraph["text"],
		"answers": _visit_answers()
	})


func _visit_answers() -> Array:
	var answers: Array = _tree.nodes[_stack_get().name]["children"][_stack_get().index]["answers"]
	var res := []
	res.resize(answers.size())

	for i in range(answers.size()):
		res[i] = { "key": answers[i]["node"] }
		if _options.show_partial_answer:
			#TODO: handle placeholders
			res[i]["text"] = _tree.nodes[answers[i]["node"]]["text"]
		else:
			# TODO: check node's children, handle placeholders
			res[i]["text"] = _tree.nodes[answers[i]["node"]]["children"][0]["text"]

	return res


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
					-1, -1, #TODO
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
					-1, -1, #TODO
					{
						"name": request_key,
						"type": Lexer.Token.get_type_name(requested_type),
						"got": p_context[request_key] }))

	return errors

