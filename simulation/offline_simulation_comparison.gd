extends RefCounted


# Pure helpers shared by the benchmark and regression tests. Statistics contain
# both sparse resource dictionaries and numeric aggregates; compare both shapes.
static func get_max_deviation(baseline: Dictionary, comparison: Dictionary) -> float:
	var maximum: float = 0.0
	for section in ["resources", "generators", "statistics"]:
		if not baseline.get(section) is Dictionary or not comparison.get(section) is Dictionary:
			return INF
		maximum = maxf(maximum, _metric_deviation(baseline[section], comparison[section]))
	if not baseline.has("overflow") or not comparison.has("overflow"):
		return INF
	return maxf(maximum, _metric_deviation(baseline["overflow"], comparison["overflow"]))


static func _metric_deviation(baseline: Variant, comparison: Variant) -> float:
	if baseline is Dictionary or comparison is Dictionary:
		# Missing resource statistics mean no recorded flow, not a malformed run.
		if baseline != null and not baseline is Dictionary:
			return INF
		if comparison != null and not comparison is Dictionary:
			return INF
		var a: Dictionary = baseline if baseline is Dictionary else {}
		var b: Dictionary = comparison if comparison is Dictionary else {}
		var maximum: float = 0.0
		for key in _merged_keys(a, b):
			maximum = maxf(maximum, _metric_deviation(a.get(key), b.get(key)))
		return maximum

	if baseline is bool or comparison is bool:
		if baseline != null and not baseline is bool:
			return INF
		if comparison != null and not comparison is bool:
			return INF
		return 0.0 if bool(baseline) == bool(comparison) else 100.0

	if baseline != null and not (baseline is float or baseline is int):
		return INF
	if comparison != null and not (comparison is float or comparison is int):
		return INF
	var a: float = float(baseline) if baseline != null else 0.0
	var b: float = float(comparison) if comparison != null else 0.0
	if not is_finite(a) or not is_finite(b):
		return INF
	# Retain the original benchmark's normalization for values close to zero.
	return absf(b - a) / maxf(absf(a), 1.0) * 100.0


static func format_statistics_comparison(baseline: Dictionary, comparison: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for key in _merged_keys(baseline, comparison):
		var a: Variant = baseline.get(key)
		var b: Variant = comparison.get(key)
		if a is Dictionary or b is Dictionary:
			var a_stats: Dictionary = a if a is Dictionary else {}
			var b_stats: Dictionary = b if b is Dictionary else {}
			lines.append("    %s produced %s -> %s | consumed %s -> %s | lost %s -> %s" % [
				str(key),
				str(a_stats.get("total_produced", 0.0)), str(b_stats.get("total_produced", 0.0)),
				str(a_stats.get("total_consumed", 0.0)), str(b_stats.get("total_consumed", 0.0)),
				str(a_stats.get("total_lost", 0.0)), str(b_stats.get("total_lost", 0.0))
			])
		else:
			lines.append("    %s: %s -> %s" % [str(key), str(a if a != null else 0.0), str(b if b != null else 0.0)])
	return lines


static func _merged_keys(baseline: Dictionary, comparison: Dictionary) -> Array:
	var keys: Array = baseline.keys()
	for key in comparison:
		if not baseline.has(key):
			keys.append(key)
	return keys
