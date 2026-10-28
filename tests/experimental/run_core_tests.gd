extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tests = preload("res://tests/experimental/core_tests.gd").new()
	var result: Dictionary = tests.run_all()
	for failure: String in tests.failures:
		push_error(failure)
	print("CORE_TESTS " + JSON.stringify(result))
	quit(0 if tests.failures.is_empty() else 1)
