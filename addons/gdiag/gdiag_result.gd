class_name GDiagResult

var value = null
var _is_error := true

func is_error() -> bool:
	return _is_error


func ok(p_value = null) -> GDiagResult:
	_is_error = false
	value = p_value
	return self


func err(p_error) -> GDiagResult:
	_is_error = true
	value = p_error
	return self
