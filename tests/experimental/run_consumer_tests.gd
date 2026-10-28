extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test: RefCounted = preload("res://tests/experimental/consumer_tests.gd").new()
	var result: Dictionary = test.run_all()
	var output := FileAccess.open("res://tests/experimental/consumer_validation.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t") + "\n")
	for failure: String in test.failures:
		push_error(failure)
	print("CONSUMER_TESTS failures=" + str(test.failures.size()))
	quit(0 if test.failures.is_empty() else 1)
