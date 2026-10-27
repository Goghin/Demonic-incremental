extends SceneTree

const Fixtures = preload("res://tests/experimental/autobuyer_fixtures.gd")

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options: Dictionary = {"scenario": "late_wait", "duration": "60", "repeats": "1", "profile": "false", "short_exact": "600", "dense": "false", "replay_waiting": "false", "previous": "true"}
	for argument in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	if not options["scenario"] in Fixtures.SCENARIOS or not str(options["duration"]).is_valid_float() or not is_finite(float(options["duration"])) or float(options["duration"]) < 0.0 or not str(options["short_exact"]).is_valid_float() or not is_finite(float(options["short_exact"])) or float(options["short_exact"]) < 0.0 or not str(options["repeats"]).is_valid_int() or int(options["repeats"]) < 1 or int(options["repeats"]) > 10 or not options["profile"] in ["true", "false"] or not options["dense"] in ["true", "false"] or not options["replay_waiting"] in ["true", "false"] or not options["previous"] in ["true", "false"]:
		print("AUTOBUYER_JSON " + JSON.stringify({"failure_count": 1, "error": "Invalid experiment options."}))
		quit(1)
		return
	var test = preload("res://tests/experimental/autobuyer_tests.gd").new()
	for repeat_index in range(int(options["repeats"])):
		var result: Dictionary = test.measure(options["scenario"], float(options["duration"]), options["profile"] == "true", float(options["short_exact"]), options["dense"] == "true", options["replay_waiting"] == "true", options["previous"] == "true")
		result["repeat"] = repeat_index
		result["engine"] = Engine.get_version_info()["string"]
		print("AUTOBUYER_JSON " + JSON.stringify(result))
		if not test.failures.is_empty():
			for failure in test.failures:
				push_error(failure)
			quit(1)
			return
	quit()
