extends Control

const DIALOGUE := preload("res://examples/bob/dialogues/bob.dialogue.tres")

const BOB_TEXTURE := preload("res://examples/bob/assets/bob.png")
const PLAYER_TEXTURE := preload("res://examples/bob/assets/player.png")

const GameState := preload("res://examples/bob/game_state.gd")

# The image of the person who is currently speaking (Bob or the Player)
onready var ui_portrait: TextureRect = $DialogBox/Portrait
# The name of the person who is currently speaking (Bob or the Player)
onready var ui_name: Label = $DialogBox/Name
onready var ui_text: RichTextLabel = $DialogBox/VBoxContainer/Text
# contains the next button or possible answers
onready var ui_answers: VBoxContainer = $DialogBox/VBoxContainer/Answers
onready var tween: Tween = $DialogBox/Tween

var _gdaig_int := GDiagInterpreter.new()

func _ready() -> void:
	# Our dialogue starts with Bob saying 'Hello...' or 'Hey...'.
	# GDiagInterpreter uses the built in randi() function to choose randomly.
	# So we have to call randomize() to get a different random number each time we press play.
	randomize()

	# We pass the global game state and the dialogue to the interpreter.
	# The global game state should contain everything the dialogue requested under __request__.
	# Every public function of GDiagInterpreter returns a GDiagResult
	# It has a value property that contains a value or an error
	# is_error() tells us if the value is an error
	var status := _gdaig_int.start(get_global_game_state(), DIALOGUE)
	# str(...) is a quick and dirty way to print all errors
	assert(!status.is_error(), "Something wrong with bob.dialogue.tres:\n\t%s" % str(status.value))

	# show the first line
	next()


# this function called when we press the next button or choose an answer
# key is the identifier of our answer
# in our case it can be: GOOD, BAD, HE_WAS_SPECIAL, YES_THEY_DO, HAMSTER_YEARS
# you can see it in the bob.dialogue.tres file
func next(key := "") -> void:
	# remove previous answers from ui_answers
	for child in ui_answers.get_children():
		(child as Node).queue_free()

	# get the next paragraph
	# for example this is a paragraph in bob.dialogue.tres:
	#	Player: "I'am fine. How are you?"
	var result := _gdaig_int.next(key)
	assert(!result.is_error(), str(result.value))

	# Contains:
	#	who is speaking
	#	what is they saying
	#	possible answers
	var paragraph: GDiagInterpreter.GDiagParagraph = result.value

	# null means the dialogue ended.
	if paragraph == null:
		ui_text.bbcode_text = "END"
		return

	# update ui
	ui_text.bbcode_text = paragraph.text
	ui_name.text = paragraph.character

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

	# after the text animation finished
	# if there are any answers
	# we show them as a button
	# otherwise we show the next button
	if paragraph.answers.size() > 0:
		for answer in paragraph.answers:
			ui_answers.add_child(_create_button(answer.text, answer.key))
	else:
		ui_answers.add_child(_create_button("next"))


func get_global_game_state() -> GameState:
	var res := GameState.new()
	res.player_name = "Player"
	return res


# this is the function we call in our dialogue
# In the future we should use an enum or something instead of String.
func change_portrait(of: String) -> void:
	ui_portrait.texture = PLAYER_TEXTURE if of == "Player" else BOB_TEXTURE


# creates a button with the given text
# calls next() with the given key when pressed
func _create_button(p_text: String, p_key := "") -> Button:
	var button := Button.new()
	button.flat = true
	button.align = Button.ALIGN_LEFT
	button.text = p_text
	# warning-ignore:return_value_discarded
	button.connect("pressed", self, "next", [p_key])
	return button
