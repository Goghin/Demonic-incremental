extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test: RefCounted = preload("res://tests/experimental/relic_crafting_tests.gd").new()
	var result: Dictionary = test.run_all()
	var focused: bool = OS.get_environment("CRAFT_TEST_LABEL") != ""
	var file := FileAccess.open("res://tests/experimental/relic_crafting_probe.json" if focused else "res://tests/experimental/relic_crafting_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	for failure: String in test.failures:
		push_error(failure)
	print("RELIC_CRAFTING_TESTS failures=", test.failures.size())
	quit(0 if test.failures.is_empty() else 1)
