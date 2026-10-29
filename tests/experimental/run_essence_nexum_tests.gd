extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test: RefCounted = preload("res://tests/experimental/essence_nexum_tests.gd").new()
	var result: Dictionary = test.run_all()
	var output := FileAccess.open("res://tests/experimental/essence_nexum_validation.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t") + "\n")
	for failure: String in test.failures:
		push_error(failure)
	print("ESSENCE_NEXUM_TESTS failures=", test.failures.size())
	quit(0 if test.failures.is_empty() else 1)
