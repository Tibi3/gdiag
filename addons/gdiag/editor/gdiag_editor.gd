tool
extends Control

const GDiagTextEdit := preload("res://addons/gdiag/editor/gdiag_text_edit.gd")
const Global := preload("res://addons/gdiag/editor/gdiag_global.gd")

onready var ui_dialogue_list: ItemList = $VBoxContainer/HSplitContainer/VBoxContainer/ItemList
onready var ui_dialogue_container: TabContainer = $VBoxContainer/HSplitContainer/VBoxContainer2/TabContainer

func _ready() -> void:
	Global.e_bus().connect("opened", self, "_dialogue_opened")
	Global.e_bus().connect("closed", self, "_dialogue_closed")
	Global.e_bus().connect("should_save", self, "_save_dialogues")
	ui_dialogue_list.connect("gui_input", self, "_on_ui_dialogue_list_gui_input")


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


func _on_ui_dialogue_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton && event.pressed && event.button_index == BUTTON_MIDDLE:
		var index := ui_dialogue_list.get_item_at_position(event.position, true)
		if index != -1:
			Global.e_bus().emit_signal("closed", ui_dialogue_list.get_item_metadata(index))


func _dialogue_editor_text_changed(p_index: int) -> void:
	if !ui_dialogue_list.get_item_text(p_index).ends_with("(*)"):
		ui_dialogue_list.set_item_text(p_index, ui_dialogue_list.get_item_text(p_index) + "(*)")


func _on_github_button_pressed() -> void:
	OS.shell_open("https://github.com/Tibi3/gdiag")


func _on_docs_button_pressed() -> void:
	# TODO: set docs url
	OS.shell_open("https://github.com/Tibi3/gdiag")
