class_name GDiagResult

var value = null
var error = null

func is_ok() -> bool:
	return error == null


func ok(p_value = null) -> GDiagResult:
	assert(error == null, "error is already set")
	value = p_value
	return self


func err(p_error) -> GDiagResult:
	assert(value == null, "value is already set")
	error = p_error
	return self
