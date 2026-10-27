extends RefCounted

const Tests = preload("res://tests/experimental/autobuyer_tests.gd")
const Fixtures = preload("res://tests/experimental/resource_flow_fixtures.gd")
const Runner = preload("res://tests/experimental/resource_flow_offline.gd")
const Bounds = preload("res://tests/experimental/resource_flow_bounds.gd")


var failures: Array[String] = []


func run_all() -> Dictionary:
	var test = Tests.new()
	var cases: int = 0
	for scenario: String in ["transfer", "exhaustion", "generator_wait", "upgrade_wait", "matter_modifier", "threshold", "cycles"]:
		for seconds: float in [0.0, 0.01, 0.15, 1.05, 9.9, 20.05, 120.05]:
			var adaptive = _runner(scenario, false, test)
			var reference = _runner(scenario, true, test)
			adaptive.run(seconds)
			for tick: int in adaptive.samples:
				reference.requested_audits[tick] = true
			reference.run(seconds)
			test.check(adaptive.counters["strict_failure"] == "", "Trial failed: " + scenario)
			test.validate(reference, adaptive, scenario + "/" + str(seconds))
			test.check(reference.samples.size() >= adaptive.samples.size(), "Dense audits missing")
			if scenario == "cycles":
				test.check(test.full(reference.simulation.state) == test.full(adaptive.simulation.state), "Cycle fallback changed binary state")
			cases += 1
	var state: GameState = Fixtures.make_state("transfer")
	var simulation := Simulation.new(state)
	for _tick: int in range(10):
		simulation.update(0.1, true)
	var before: String = test.full(state)
	test.check(Bounds.inspect(state, 60.1)["reason"] == "", "Funded transfer proof missing")
	test.check(before == test.full(state), "Proof mutated state")
	state.set_resource_amount(ResourceIds.NEXUM, 1.0)
	test.check(Bounds.inspect(state, 60.1)["reason"] == "input/exhaustion/nexum", "Exhaustion was accepted")
	state = Fixtures.make_state("matter_modifier")
	simulation = Simulation.new(state)
	for _tick: int in range(10):
		simulation.update(0.1, true)
	test.check(str(Bounds.inspect(state, 60.1)["reason"]).begins_with("modifier/resource/"), "Changing Matter dependency was accepted")
	state = Fixtures.make_state("transfer")
	var transfer: Generator = state.get_generator("thermal_compressor")
	var modifier := Modifier.new(ModifierTypes.INPUT_DRAW, ResourceIds.NEXUM, 1.0)
	modifier.dynamic = true
	modifier.dynamic_formula = "unsupported_future_formula"
	modifier.dynamic_resource_id = ResourceIds.ESSENCE
	transfer.modifiers.append(modifier)
	test.check(str(Bounds.inspect(state, 60.1)["reason"]).begins_with("modifier/unknown_formula/"), "Unknown formula was accepted")
	# Proofs are rebuilt across external changes; automatic effects and the
	# original controllers settle on exact ticks before adapting again.
	var candidate = _runner("transfer", false, test)
	var exact = _runner("transfer", true, test)
	for index: int in range(6):
		candidate = _continue(candidate, false)
		exact = _continue(exact, true)
		for item in [candidate, exact]:
			item.simulation.state.get_generator("atomic_friction").manually_paused = index % 2 == 0
		candidate.run(20.05)
		for tick: int in candidate.samples:
			exact.requested_audits[tick] = true
		exact.run(20.05)
		test.check(candidate.counters["strict_failure"] == "" and exact.counters["strict_failure"] == "", "Repeated interval failed")
		test.validate(exact, candidate, "alternating dependency " + str(index))
	failures = test.failures
	return {"endpoint_cases": cases, "proof_and_invalidation_checks": 5, "transition_runs": 6, "failures": failures}



func _runner(scenario: String, precise: bool, test):
	var state: GameState = Fixtures.make_state(scenario)
	var runner = Runner.new(Simulation.new(state))
	runner.accuracy_mode = "precise" if precise else "balanced"
	runner.overrides = {"short_exact_seconds": 0.0}
	var ref: WeakRef = weakref(runner)
	state.gameplay_log.clock = func() -> float: return float(ref.get_ref().elapsed)
	test.observe(runner.simulation)
	return runner


func _continue(previous, precise: bool):
	var runner = Runner.new(previous.simulation)
	runner.accuracy_mode = "precise" if precise else "balanced"
	runner.overrides = {"short_exact_seconds": 0.0}
	var ref: WeakRef = weakref(runner)
	runner.simulation.state.gameplay_log.clock = func() -> float: return float(ref.get_ref().elapsed)
	return runner
