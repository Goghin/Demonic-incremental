extends SceneTree

const Fixtures = preload("res://tests/experimental/core_fixtures.gd")
const Previous = preload("res://tests/experimental/resource_flow_offline.gd")
const Investigation = preload("res://tests/experimental/core_investigation_runner.gd")
const Tests = preload("res://tests/experimental/autobuyer_tests.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options: Dictionary = {"scenario": "early", "duration": "120", "repeats": "1", "survey": "false", "ablation": "none"}
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	if not Fixtures.SCENARIOS.has(options["scenario"]) or not str(options["duration"]).is_valid_float() or not is_finite(float(options["duration"])) or float(options["duration"]) < 0.0 or not str(options["repeats"]).is_valid_int() or int(options["repeats"]) < 1 or int(options["repeats"]) > 10 or not options["survey"] in ["true", "false"] or not options["ablation"] in ["none", "cycles", "automation", "cycles_automation", "consumers"]:
		push_error("Invalid core benchmark options")
		quit(1)
		return
	for repeat_index: int in range(int(options["repeats"])):
		var test = Tests.new()
		var result: Dictionary = {"scenario": options["scenario"], "duration": float(options["duration"]), "repeat": repeat_index, "survey": options["survey"] == "true", "ablation": options["ablation"], "engine": Engine.get_version_info()["string"], "runs": {}}
		var candidates: Dictionary = {}
		var order: Array[String] = ["new", "old", "exact"]
		if repeat_index % 2 == 1:
			order = ["old", "new", "exact"]
		for kind: String in order:
			var state: GameState = Fixtures.make_state(options["scenario"])
			Fixtures.ablate(state, options["ablation"])
			var runner = Investigation.new(Simulation.new(state)) if kind == "new" else Previous.new(Simulation.new(state))
			runner.overrides = {"short_exact_seconds": 0.0}
			if kind == "new":
				runner.survey = options["survey"] == "true"
			if kind == "exact":
				runner.accuracy_mode = "precise"
				for candidate: String in ["new", "old"]:
					for tick: int in candidates[candidate].samples:
						runner.requested_audits[tick] = true
			var ref: WeakRef = weakref(runner)
			state.gameplay_log.clock = func() -> float: return float(ref.get_ref().elapsed)
			test.observe(runner.simulation)
			var start: int = Time.get_ticks_usec()
			var counters: Dictionary = runner.run(float(options["duration"]))
			var wall: float = float(Time.get_ticks_usec() - start) / 1e6
			candidates[kind] = runner
			result["runs"][kind] = {"seconds": wall, "counters": counters, "events": state.gameplay_log.events, "samples": runner.samples.size()}
			test.check(counters.get("strict_failure", "") == "", "Strict failure: " + kind)
		for kind: String in ["new", "old"]:
			result["runs"][kind].merge(test.validate(candidates["exact"], candidates[kind], str(options["scenario"]) + "/" + kind))
			result["runs"][kind]["speedup"] = float(result["runs"]["exact"]["seconds"]) / float(result["runs"][kind]["seconds"])
		result["failures"] = test.failures
		print("CORE_JSON " + JSON.stringify(result))
		if not test.failures.is_empty():
			for failure: String in test.failures:
				push_error(failure)
			quit(1)
			return
	quit()
