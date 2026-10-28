extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tests: RefCounted = preload("res://tests/experimental/exact_flow_tests.gd").new()
	var result: Dictionary = tests.run_all()
	var output := FileAccess.open("res://tests/experimental/exact_flow_validation.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t") + "\n")
	output.close()
	for failure: String in tests.failures:
		push_error(failure)
	print("EXACT_FLOW_TESTS failures=" + str(tests.failures.size()))
	quit(0 if tests.failures.is_empty() else 1)
