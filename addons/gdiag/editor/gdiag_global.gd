const _DATA := []

static func init(p_editor_interface: EditorInterface) -> void:
	_DATA.clear()
	_DATA.push_back(p_editor_interface)


static func get_editor_interface() -> EditorInterface:
	return _DATA[0]
