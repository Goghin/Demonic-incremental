
class_name NumberFormatter
extends RefCounted


static func format(value: float) -> String:
	if is_nan(value) or is_inf(value):
		return "0"

	var absolute_value: float = abs(value)

	if absolute_value < 1000.0:
		return _format_small(value)

	var suffixes: Array[String] = [
		"K",
		"M",
		"B",
		"T",
		"Qa",
		"Qi",
		"Sx",
		"Sp",
		"Oc",
		"No",
		"Dc"
	]

	var scaled_value: float = value
	var suffix_index: int = -1

	while abs(scaled_value) >= 1000.0:
		scaled_value /= 1000.0
		suffix_index += 1

		if suffix_index >= suffixes.size():
			var exponent: int = int(floor(log(abs(value)) / log(10.0)))
			var mantissa: float = value / pow(10.0, exponent)
			return "%.2fe%d" % [mantissa, exponent]

	return _format_scaled(
		scaled_value,
		1.0,
		suffixes[suffix_index]
	)


static func _format_small(value: float) -> String:
	var absolute_value = abs(value)

	if absolute_value >= 100.0:
		return "%.0f" % value

	var text: String

	if absolute_value < 1.0:
		text = "%.4f" % value

	elif absolute_value < 10.0:
		text = "%.2f" % value

	else:
		text = "%.1f" % value

	text = text.rstrip("0")
	text = text.rstrip(".")

	return text



static func _format_scaled(
	value: float,
	divisor: float,
	suffix: String
	) -> String:

	var scaled = value / divisor

	var text: String

	if abs(scaled) >= 100.0:
		text = "%.0f" % scaled

	elif abs(scaled) >= 10.0:
		text = "%.1f" % scaled
		text = text.rstrip("0")
		text = text.rstrip(".")

	else:
		text = "%.2f" % scaled
		text = text.rstrip("0")
		text = text.rstrip(".")

	return "%s %s" % [
		text,
		suffix
	]
