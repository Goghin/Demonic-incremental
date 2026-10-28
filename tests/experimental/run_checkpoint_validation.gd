extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var results: Dictionary = {}
	var failures: Array[String] = []
	var initial_conditions: Dictionary = {}
	for kind: String in ["reference", "compact"]:
		var tests: RefCounted = preload("res://tests/experimental/transaction_tests.gd").new()
		tests.initial_conditions = initial_conditions
		tests.checkpoint_implementation = preload("res://tests/experimental/transaction_checkpoint.gd") if kind == "reference" else preload("res://tests/experimental/compact_checkpoint.gd")
		results[kind] = tests.run_all()
		failures.append_array(tests.failures)
	if results["reference"]["fingerprints"] != results["compact"]["fingerprints"]:
		failures.append("Original/compact endpoint fingerprints differ")
	results["original_compact_endpoint_parity"] = results["reference"]["fingerprints"] == results["compact"]["fingerprints"]
	var contracts: RefCounted = preload("res://tests/experimental/checkpoint_contract_tests.gd").new()
	contracts.run_all()
	failures.append_array(contracts.failures)
	results["contract_failures"] = contracts.failures
	var output := FileAccess.open("res://tests/experimental/checkpoint_differential_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "\t") + "\n")
	output.close()
	for failure: String in failures:
		push_error(failure)
	print("CHECKPOINT_DIFFERENTIAL failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)
