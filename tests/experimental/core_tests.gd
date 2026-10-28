extends RefCounted

const Fixtures = preload("res://tests/experimental/core_fixtures.gd")
const Investigation = preload("res://tests/experimental/core_investigation_runner.gd")
const Previous = preload("res://tests/experimental/resource_flow_offline.gd")
const Tests = preload("res://tests/experimental/autobuyer_tests.gd")
const Bounds = preload("res://tests/experimental/core_cycle_bound.gd")
const Checkpoint = preload("res://tests/experimental/continuous_checkpoint.gd")
var failures: Array[String] = []


func run_all() -> Dictionary:
	var test = Tests.new()
	var endpoints: int = 0
	for scenario: String in ["early", "mid", "forge_competing", "forge_running", "forge"]:
		var candidate = _runner(Fixtures.make_state(scenario), false, test)
		var reference = _runner(Fixtures.make_state(scenario), true, test)
		for runner in [candidate, reference]:
			runner.overrides = {"short_exact_seconds": 0.0, "audit_interval": 0.1}
			runner.run(120.0)
			test.check(runner.counters["strict_failure"] == "", "Dense core trial failed: " + scenario)
		test.validate(reference, candidate, "dense core/" + scenario)
		test.check(candidate.samples.size() == 1200 and reference.samples.size() == 1200, "Missing dense core endpoints")
		test.check(candidate.counters["accepted"] == 0, "Unproved core state was admitted")
		endpoints += candidate.samples.size()
		# The observational survey must not change gameplay or event timing.
		var surveyed = _runner(Fixtures.make_state(scenario), false, test)
		surveyed.survey = true
		surveyed.overrides = {"short_exact_seconds": 0.0, "audit_interval": 0.1}
		surveyed.run(120.0)
		test.check(test.full(surveyed.simulation.state) == test.full(reference.simulation.state), "Instrumentation changed state: " + scenario)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/core_event_fixture.json"))
	var event_probe = _runner(Fixtures.from_save(raw["before"]), true, test)
	event_probe.run(2.0)
	var event_tick: int = 0
	for event: Dictionary in event_probe.simulation.state.gameplay_log.events:
		if event["category"] == "signal" and event["event"] in ["normal_cycle", "critical_cycle"]:
			event_tick = int(event["tick"])
			break
	test.check(event_tick > 0, "Real completion witness did not complete after loading")
	for offset: int in [-1, 0, 1]:
		var seconds: float = maxf(0.0, float(event_tick + offset) * TimeManager.OFFLINE_MAX_GAME_STEP)
		var candidate = _runner(Fixtures.from_save(raw["before"]), false, test)
		var exact = _runner(Fixtures.from_save(raw["before"]), true, test)
		for runner in [candidate, exact]:
			runner.overrides = {"short_exact_seconds": 0.0, "audit_interval": 0.1}
			runner.run(seconds)
		test.validate(exact, candidate, "real completion boundary/" + str(offset))
		test.check(test.full(exact.simulation.state) == test.full(candidate.simulation.state), "Completion boundary changed binary state")
	var state: GameState = Fixtures.from_save(raw["before"])
	var simulation := Simulation.new(state)
	var forge: Generator = state.get_generator("infernal_forge")
	test.check(Bounds.inspect(forge, state)["status"] == "unknown", "Unfrozen cycle was certified")
	var original: String = test.full(state)
	var bound: Dictionary = Bounds.inspect(forge, state, true)
	test.check(bound["status"] == "conditional_bound", "Real Ash-speed formula has no conditional envelope")
	test.check(test.full(state) == original, "Cycle-bound inspection mutated state")
	var upper: float = float(bound.get("speed_upper", 0.0))
	for amount: float in [0.0, 1.0, 10.0, 1000.0, 1000000.0]:
		# Formula-domain unit probes only; not reachable fixtures or timings.
		var held: float = state.get_resource_amount(ResourceIds.ASH)
		state.resources[ResourceIds.ASH].amount = amount
		test.check(simulation._get_cycle_speed_multiplier(forge) <= upper, "Ash speed exceeded global envelope")
		state.resources[ResourceIds.ASH].amount = held
	var saved: Dictionary = Checkpoint.capture(simulation)
	var progress: float = forge.cycle_progress
	simulation.update(0.1, true)
	Checkpoint.restore(simulation, saved)
	var cycle_gap: bool = not forge.cycle_active and forge.cycle_progress != progress
	test.check(cycle_gap, "Restricted checkpoint contract changed: update architecture investigation")
	state = Fixtures.make_state("early")
	simulation = Simulation.new(state)
	var condensation: Generator = state.get_generator("thermal_furnace")
	var remainder: Dictionary = condensation.production_progress.duplicate(true)
	saved = Checkpoint.capture(simulation)
	simulation.update(0.1, true)
	Checkpoint.restore(simulation, saved)
	var remainder_gap: bool = condensation.production_progress != remainder
	test.check(remainder_gap, "Restricted discrete-output checkpoint contract changed")
	failures = test.failures
	return {"dense_endpoints": endpoints, "completion_tick_after_reload": event_tick, "completion_windows": 3, "cycle_checkpoint_out_of_contract": cycle_gap, "output_remainder_out_of_contract": remainder_gap, "failures": failures}


func _runner(state: GameState, precise: bool, test):
	var runner = Investigation.new(Simulation.new(state)) if not precise else Previous.new(Simulation.new(state))
	runner.overrides = {"short_exact_seconds": 0.0}
	if precise:
		runner.accuracy_mode = "precise"
	var ref: WeakRef = weakref(runner)
	state.gameplay_log.clock = func() -> float: return float(ref.get_ref().elapsed)
	test.observe(runner.simulation)
	return runner
