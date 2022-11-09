tool
extends EditorPlugin

const GDIAG_EDITOR_SCENE := preload("res://addons/gdiag/editor/gdiag_editor.tscn")
const Global := preload("res://addons/gdiag/editor/gdiag_global.gd")

var gdiag_editor_instance: Control

func _enter_tree() -> void:
	Global.init(get_editor_interface())
	gdiag_editor_instance = GDIAG_EDITOR_SCENE.instance()
	get_editor_interface().get_editor_viewport().add_child(gdiag_editor_instance)
	make_visible(false)


func _exit_tree() -> void:
	if is_instance_valid(gdiag_editor_instance):
		gdiag_editor_instance.queue_free()


func has_main_screen() -> bool:
	return true


func make_visible(visible: bool) -> void:
	if is_instance_valid(gdiag_editor_instance):
		gdiag_editor_instance.visible = visible


func handles(object: Object) -> bool:
	return object is GDiag


func edit(object: Object) -> void:
	Global.e_bus().emit_signal("opened", object)


func apply_changes() -> void:
	Global.e_bus().emit_signal("should_save")


func get_plugin_name() -> String:
	return "GDiag"


func get_plugin_icon() -> Texture:
	# TODO: add icon
	return get_editor_interface().get_base_control().get_icon("Node", "EditorIcons")
