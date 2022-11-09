const _DATA := []

class EventBus:
	signal opened 			# <GDiag>
	signal closed 			# <GDiag>
	signal should_save

static func init(p_editor_interface: EditorInterface) -> void:
	_DATA.clear()
	_DATA.push_back(p_editor_interface)
	_DATA.push_back(EventBus.new())


static func get_editor_interface() -> EditorInterface:
	return _DATA[0]


static func e_bus() -> EventBus:
	return _DATA[1]
