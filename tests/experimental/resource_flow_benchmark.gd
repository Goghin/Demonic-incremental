extends SceneTree

const Fixtures = preload("res://tests/experimental/resource_flow_fixtures.gd")
const NewRunner = preload("res://tests/experimental/resource_flow_offline.gd")
const OldRunner = preload("res://tests/experimental/autobuyer_offline.gd")
const Tests = preload("res://tests/experimental/autobuyer_tests.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options: Dictionary = {"scenario": "transfer", "duration": "120", "repeats": "1", "survey": "false"}
	for arg: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	if not Fixtures.SCENARIOS.has(options["scenario"]) or not str(options["duration"]).is_valid_float() or not is_finite(float(options["duration"])) or float(options["duration"]) < 0.0 or not str(options["repeats"]).is_valid_int() or int(options["repeats"]) < 1 or int(options["repeats"]) > 10:
		push_error("Invalid resource-flow benchmark options")
		quit(1)
		return
	for repeat_index: int in range(int(options["repeats"])):
		var test = Tests.new()
		var runners: Dictionary = {}
		var result: Dictionary = {"scenario": options["scenario"], "duration": float(options["duration"]), "repeat": repeat_index, "engine": Engine.get_version_info()["string"], "runs": {}}
		# Alternate candidate order; run dense reference last, with the union of
		# ALL accepted endpoints. Exact samples are timed consistently too.
		var kinds: Array[String] = ["new", "old", "exact"]
		if repeat_index % 2 != 0:
			kinds = ["old", "new", "exact"]
		for kind: String in kinds:
			var state: GameState = Fixtures.make_state(options["scenario"])
			var runner = NewRunner.new(Simulation.new(state)) if kind == "new" else OldRunner.new(Simulation.new(state))
			if kind == "old" and options["survey"] == "true":
				runner = preload("res://tests/experimental/resource_flow_diagnostics.gd").new(Simulation.new(state))
			runner.overrides = {"short_exact_seconds": 0.0}
			if kind == "exact":
				runner.accuracy_mode = "precise"
				for candidate: String in ["new", "old"]:
					for tick: int in runners[candidate].samples:
						runner.requested_audits[tick] = true
			var ref: WeakRef = weakref(runner)
			state.gameplay_log.clock = func() -> float: return float(ref.get_ref().elapsed)
			test.observe(runner.simulation)
			var start: int = Time.get_ticks_usec()
			var counters: Dictionary = runner.run(float(options["duration"]))
			var wall: float = float(Time.get_ticks_usec() - start) / 1e6
			runners[kind] = runner
			result["runs"][kind] = {"seconds": wall, "counters": counters, "samples": runner.samples.size()}
			test.check(counters.get("strict_failure", "") == "", "Strict failure: " + kind)
			if kind == "old" and options["survey"] == "true":
				result["runs"][kind]["overlapping_blocker_calls"] = runner.blocker_calls
		for kind: String in ["new", "old"]:
			result["runs"][kind].merge(test.validate(runners["exact"], runners[kind], str(options["scenario"]) + "/" + kind))
			result["runs"][kind]["speedup"] = float(result["runs"]["exact"]["seconds"]) / float(result["runs"][kind]["seconds"])
		if options["scenario"] == "transfer" and float(options["duration"]) >= 120.0:
			test.check(runners["new"].counters["accepted"] > 0, "Real consumer never adapted")
			test.check(runners["old"].counters["accepted"] == 0, "Old runner unexpectedly adapted")
		result["failures"] = test.failures
		print("FLOW_JSON " + JSON.stringify(result))
		if not test.failures.is_empty():
			for failure: String in test.failures:
				push_error(failure)
			quit(1)
			return
	quit()
