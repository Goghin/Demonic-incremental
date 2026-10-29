extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var tests: RefCounted = preload("res://tests/experimental/observer_tests.gd").new()
	var result: Dictionary = tests.run_all()
	await tests.deferred_case(self)
	await tests.adapter_callback_case()
	var file := FileAccess.open("res://tests/experimental/observer_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	for failure: String in tests.failures:
		push_error(failure)
	print("Observer differential cases: ", tests.cases.size(), "; failures: ", tests.failures.size())
	quit(0 if tests.failures.is_empty() else 1)
