extends Control

onready var ui_character := $ColorRect/VBoxContainer/Label
onready var ui_text := $ColorRect/VBoxContainer/RichTextLabel

var _gdaig_int := GDiagInterpreter.new(GDiagInterpreter.Options.new())

func _ready() -> void:
	var res = _gdaig_int.start({
		"player_name": "player"
	}, preload("res://examples/bob/bob_dialogue.tres"))
	assert(res.is_ok(), "Something wrong with bob_dialogue.tres")
	_next()


func _next(p_to: String = "") -> void:
	var p := _gdaig_int.next(p_to)

	assert(p.is_ok(), "Error")

	if typeof(p.value) == TYPE_BOOL:
		ui_text.bbcode_text = "END"
		return

	ui_character.text = p.value["character"]
	ui_text.bbcode_text = p.value["text"]
	for answer in p.value["answers"]:
		ui_text.bbcode_text += "\n\t[url=%s]%s[/url]" % [answer["key"], answer["text"]]

	if p.value["answers"].size() == 0:
		ui_text.bbcode_text += "\n\n\n\t[url=]next[/url]"


func _on_meta_clicked(meta: String) -> void:
	_next(meta)
