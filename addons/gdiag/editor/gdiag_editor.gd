tool
extends Control

const GDIAG_TEMPLATE =\
"""#Author:
#Triggers:

__request__
	player_name: String

__characters__
	Player

[MAIN]:
	Player: "Hello, world"
"""

const GDiagTextEdit := preload("res://addons/gdiag/editor/gdiag_text_edit.gd")
const Global := preload("res://addons/gdiag/editor/gdiag_global.gd")

onready var ui_dialogue_list: ItemList = $VBoxContainer/HSplitContainer/VBoxContainer/ItemList
onready var ui_dialogue_container: TabContainer = $VBoxContainer/HSplitContainer/VBoxContainer2/TabContainer
onready var ui_file_menu: MenuButton = $VBoxContainer/HBoxContainer/MenuButton
onready var ui_translation_menu: MenuButton = $VBoxContainer/HBoxContainer/MenuButton2

onready var ui_errors_label: Label = $VBoxContainer/HSplitContainer/VBoxContainer2/HBoxContainer/Label

onready var ui_new_file_dialog: FileDialog = $NewDialogueDialog
onready var ui_open_file_dialog: FileDialog = $OpenDialogueDialog

var _file_menu_items := [{
	"text": "New Dialogue...",
	"action": funcref(self, "_open_new_dialogue_dialog")
}, {
	"text": "Open Dialogue...",
	"action": funcref(self, "_open_open_dialogue_dialog")
}]

var _translation_menu_items := [{
	"text": "Generate keys",
	"action": funcref(self, "_generate_keys")
}]


func _ready() -> void:
	Global.e_bus().connect("opened", self, "_dialogue_opened")
	Global.e_bus().connect("closed", self, "_dialogue_closed")
	Global.e_bus().connect("should_save", self, "_save_dialogues")
	ui_dialogue_list.connect("gui_input", self, "_on_ui_dialogue_list_gui_input")
	ui_file_menu.get_popup().connect("index_pressed", self, "_file_menu_index_pressed")
	ui_translation_menu.get_popup().connect("index_pressed", self, "_translation_menu_index_pressed")

	ui_file_menu.get_popup().clear()
	ui_translation_menu.get_popup().clear()

	for item in _file_menu_items:
		ui_file_menu.get_popup().add_item(item["text"])

	for item in _translation_menu_items:
		ui_translation_menu.get_popup().add_item(item["text"])


func _dialogue_opened(p_dialogue: GDiag) -> void:
	for i in ui_dialogue_list.get_item_count():
		if ui_dialogue_list.get_item_metadata(i) == p_dialogue:
			ui_dialogue_list.select(i)
			ui_dialogue_list.emit_signal("item_selected", i)
			return

	ui_dialogue_list.add_item(p_dialogue.resource_path.get_file())
	ui_dialogue_list.set_item_metadata(ui_dialogue_list.get_item_count() - 1, p_dialogue)
	ui_dialogue_list.select(ui_dialogue_list.get_item_count() - 1)
	ui_dialogue_list.emit_signal("item_selected", ui_dialogue_list.get_item_count() - 1)


func _dialogue_closed(p_dialogue: GDiag) -> void:
	for i in ui_dialogue_list.get_item_count():
		if ui_dialogue_list.get_item_metadata(i) == p_dialogue:
			ui_dialogue_list.remove_item(i)
			ui_dialogue_container.get_child(i).queue_free()
			break


func _save_dialogues() -> void:
	for i in ui_dialogue_list.get_item_count():
		var gdiag: GDiag = ui_dialogue_list.get_item_metadata(i)
		gdiag.source = ui_dialogue_container.get_child(i).text
		var text := ui_dialogue_list.get_item_text(i)
		if text.ends_with("(*)"):
			ui_dialogue_list.set_item_text(i, text.substr(0, text.length() - 3))


func _on_ui_dialogue_list_item_selected(p_index: int) -> void:
	if ui_dialogue_container.get_child_count() <= p_index:
		var editor := GDiagTextEdit.new()
		editor.text = (ui_dialogue_list.get_item_metadata(p_index) as GDiag).source
		editor.connect("text_changed", self, "_dialogue_editor_text_changed", [p_index])
		ui_dialogue_container.add_child(editor)

	ui_dialogue_container.current_tab = p_index
	ui_dialogue_container.get_child(p_index).call_deferred("grab_focus")
	ui_errors_label.text = ui_dialogue_container.get_child(p_index).get_errors()[0]


func _on_ui_dialogue_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton && event.pressed && event.button_index == BUTTON_MIDDLE:
		var index := ui_dialogue_list.get_item_at_position(event.position, true)
		if index != -1:
			Global.e_bus().emit_signal("closed", ui_dialogue_list.get_item_metadata(index))


func _dialogue_editor_text_changed(p_index: int) -> void:
	if !ui_dialogue_list.get_item_text(p_index).ends_with("(*)"):
		ui_dialogue_list.set_item_text(p_index, ui_dialogue_list.get_item_text(p_index) + "(*)")


func _open_new_dialogue_dialog() -> void:
	ui_new_file_dialog.popup_centered()


func _open_open_dialogue_dialog() -> void:
	ui_open_file_dialog.popup_centered()


func _file_menu_index_pressed(p_index: int) -> void:
	_file_menu_items[p_index]["action"].call_func()


func _generate_keys() -> void:
	if ui_dialogue_container.get_child_count() == 0:
		printerr("Cannot generate transition keys, because no dialogue is open.")
		return

	ui_dialogue_container.get_child(ui_dialogue_container.current_tab).generate_translation_keys()


func _translation_menu_index_pressed(p_index: int) -> void:
	_translation_menu_items[p_index]["action"].call_func()


func _on_github_button_pressed() -> void:
	OS.shell_open("https://github.com/Tibi3/gdiag")


func _on_docs_button_pressed() -> void:
	# TODO: set docs url
	OS.shell_open("https://github.com/Tibi3/gdiag")


func _on_new_dialogue_dialog_file_selected(path: String) -> void:
	# TODO: check if file already exists
	var gdiag := GDiag.new()
	gdiag.source = GDIAG_TEMPLATE

	ResourceSaver.save(path, gdiag)
	gdiag.take_over_path(path)

	Global.e_bus().emit_signal("opened", gdiag)


func _on_open_dialogue_dialog_file_selected(path: String) -> void:
	var res := load(path)

	if res is GDiag:
		Global.e_bus().emit_signal("opened", res)
		return

	printerr("Cannot open '%s'. It's not a GDiag Resource." % path)
