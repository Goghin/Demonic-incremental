class_name NumberFormatter
extends RefCounted


static func format(value: float) -> String:
	if is_nan(value) or is_inf(value):
		return "0"
	
	var absolute_value = abs(value)
	
	if absolute_value < 1000.0:
		return _format_small(value)
	
	if absolute_value < 1000000.0:
		return _format_scaled(
			value,
			1000.0,
			"K"
		)
	
	if absolute_value < 1000000000.0:
		return _format_scaled(
			value,
			1000000.0,
			"M"
		)
	
	return _format_scaled(
		value,
		1000000000.0,
		"B"
	)


static func _format_small(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return "%d" % int(round(value))
	
	var text = "%.4f" % value
	
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
		# Already displaying a whole number.
		# Do NOT strip zeroes, since they may be significant.
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
