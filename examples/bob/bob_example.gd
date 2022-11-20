extends Control

onready var ui_character := $ColorRect/VBoxContainer/Label
onready var ui_text := $ColorRect/VBoxContainer/RichTextLabel

var _gdaig_int := GDiagInterpreter.new(GDiagInterpreter.Options.new())

func _ready() -> void:
	randomize()
	var res = _gdaig_int.start({
		"player_name": "player",
		"player_hp": 55,
		"found_secret_item": true,
		"know_where_is_jack": true,
		"increase_trust": funcref(self, "increase_trust")
	}, preload("res://examples/bob/bob_dialogue.tres"))

	# str(...) is a quick and dirty way to print all errors
	assert(res.is_ok(), "Something wrong with bob_dialogue.tres:\n\t%s" % str(res.error))
	_next()


func _next(p_to: String = "") -> void:
	var p := _gdaig_int.next(p_to)

	assert(p.is_ok(), "Error")

	if p.value == null:
		ui_text.bbcode_text = "END"
		return

	ui_character.text = p.value["character"]
	ui_text.bbcode_text = p.value["text"]
	for answer in p.value["answers"]:
		ui_text.bbcode_text += "\n\t[url=%s]%s[/url]" % [answer["key"], answer["text"]]

	if p.value["answers"].size() == 0:
		ui_text.bbcode_text += "\n\n\n\t[url=]next[/url]"


func increase_trust() -> void:
	print("call increase_trust")


func _on_meta_clicked(meta: String) -> void:
	_next(meta)
