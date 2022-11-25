extends Control

const DIALOGUE := preload("res://examples/bob/dialogues/bob.dialogue.tres")

const BOB := preload("res://examples/bob/assets/bob.png")
const PLAYER := preload("res://examples/bob/assets/player.png")

onready var ui_portrait: TextureRect = $DialogBox/Portrait
onready var ui_name: Label = $DialogBox/Name
onready var ui_text: RichTextLabel = $DialogBox/VBoxContainer/Text
onready var ui_answers: VBoxContainer = $DialogBox/VBoxContainer/Answers
onready var tween: Tween = $DialogBox/Tween

var _gdaig_int := GDiagInterpreter.new(GDiagInterpreter.Options.new())

func _ready() -> void:
	randomize()

	var status := _gdaig_int.start(get_global_game_state(), DIALOGUE)
	# str(...) is a quick and dirty way to print all errors
	assert(status.is_ok(), "Something wrong with bob.dialogue.tres:\n\t%s" % str(status.error))

	next()


func next(key := "") -> void:
	for child in ui_answers.get_children():
		(child as Node).queue_free()

	var result := _gdaig_int.next(key)
	assert(result.is_ok(), str(result.error))

	var node: GDiagInterpreter.GDiagParagraph = result.value

	if node == null:
		ui_text.bbcode_text = "END"
		return

	ui_text.visible_characters = 0
	ui_text.bbcode_text = node.text
	ui_name.text = node.character

	# warning-ignore:return_value_discarded
	tween.interpolate_property(
			ui_text,
			"percent_visible",
			0.0,
			1.0,
			ui_text.text.length() / 20.0,
			Tween.TRANS_LINEAR)

	# warning-ignore:return_value_discarded
	tween.start()
	yield(tween, "tween_completed")

	if node.answers.size() > 0:
		for answer in node.answers:
			ui_answers.add_child(_create_button(answer.text, answer.key))
	else:
		ui_answers.add_child(_create_button("next"))


func get_global_game_state() -> Dictionary:
	return {
		"player_name": "player",
		"change_portrait": funcref(self, "change_portrait")
	}


func change_portrait() -> void:
	ui_portrait.texture = PLAYER if ui_portrait.texture == BOB else BOB


func _create_button(p_text: String, p_key := "") -> Button:
	var button := Button.new()
	button.flat = true
	button.align = Button.ALIGN_LEFT
	button.text = p_text
	# warning-ignore:return_value_discarded
	button.connect("pressed", self, "next", [p_key])
	return button
