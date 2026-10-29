extends SceneTree

const Tests = preload("res://tests/experimental/relic_equipment_tests.gd")
const Adaptive = preload("res://tests/experimental/core_investigation_runner.gd")
const Metrics = preload("res://tests/experimental/adaptive_metrics.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rows: Array[Dictionary] = []
	for scenario: Array in [["early", 36000], ["mid", 10000]]:
		var native: Dictionary = Tests.context(scenario[0])
		var reference: Dictionary = Tests.context(scenario[0])
		var runner: RefCounted = Adaptive.new(reference["simulation"])
		runner.overrides = {"short_exact_seconds": 0.0}
		runner.run(float(scenario[1]) * TimeManager.OFFLINE_MAX_GAME_STEP)
		for tick: int in range(scenario[1]):
			native["simulation"].update(TimeManager.OFFLINE_MAX_GAME_STEP, true)
		var oracle: RefCounted = Tests.Oracle.new()
		var differences: Array[Dictionary] = []
		_diff(bytes_to_var(oracle.fingerprint(native["simulation"], native["journal"])), bytes_to_var(oracle.fingerprint(reference["simulation"], reference["journal"])), "graph", differences)
		failures.append_array(oracle.failures)
		if runner.counters.get("strict_failure", "") != "":
			failures.append(runner.counters["strict_failure"])
		rows.append({"label": scenario[0], "ticks": scenario[1], "first_graph_differences": differences, "numeric_deviation": Metrics.compare(Metrics.numeric(native["simulation"].state), Metrics.numeric(reference["simulation"].state), 1e-8, 1e-4), "discrete_parity": Metrics.discrete(native["simulation"].state) == Metrics.discrete(reference["simulation"].state), "rng_parity": native["simulation"].state.gameplay_rng.state == reference["simulation"].state.gameplay_rng.state, "event_parity": var_to_bytes(native["journal"].events) == var_to_bytes(reference["journal"].events), "counters": runner.counters.duplicate(true)})
	var output := FileAccess.open("res://tests/experimental/relic_equipment_reference_audit.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"rows": rows, "failures": failures}, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("RELIC_REFERENCE_AUDIT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)


func _diff(left: Variant, right: Variant, path: String, differences: Array[Dictionary]) -> void:
	if differences.size() >= 12 or var_to_bytes(left) == var_to_bytes(right):
		return
	if typeof(left) != typeof(right):
		differences.append({"path": path, "native_type": typeof(left), "reference_type": typeof(right)})
	elif left is Dictionary:
		if var_to_bytes(left.keys()) != var_to_bytes(right.keys()):
			differences.append({"path": path + "/dictionary_key_order", "native": left.keys(), "reference": right.keys()})
		for key: Variant in left:
			if right.has(key):
				_diff(left[key], right[key], path + "/" + str(key), differences)
	elif left is Array:
		if left.size() != right.size():
			differences.append({"path": path + "/array_size", "native": left.size(), "reference": right.size()})
		for index: int in range(mini(left.size(), right.size())):
			_diff(left[index], right[index], path + "/" + str(index), differences)
	else:
		differences.append({"path": path, "native": left, "reference": right})
