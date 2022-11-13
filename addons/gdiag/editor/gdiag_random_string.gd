const ALPHABET := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

static func rand_str(p_length: int, p_prefix: String = "", p_suffix: String = "") -> String:
	var res := p_prefix
	for i in range(p_length):
		res += ALPHABET[randi() % ALPHABET.length()]
	return res + p_suffix
