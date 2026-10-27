extends "res://tests/experimental/adaptive_tests.gd"

const EventRunner = preload("res://tests/experimental/autobuyer_offline.gd")
const Previous = preload("res://tests/experimental/horizon_runner.gd")
const EventFixtures = preload("res://tests/experimental/autobuyer_fixtures.gd")
const Boundary = preload("res://tests/experimental/autobuyer_boundary.gd")


func make_runner(scenario: String, kind: String, short_exact: float = 0.0):
	var state: GameState = EventFixtures.make_state(scenario)
	var runner = Previous.new(Simulation.new(state)) if kind == "previous" else EventRunner.new(Simulation.new(state))
	if kind == "precise":
		runner.accuracy_mode = "precise"
	runner.overrides = {"short_exact_seconds": short_exact}
	var clock_ref: WeakRef = weakref(runner)
	state.gameplay_log.clock = func() -> float: return float(clock_ref.get_ref().elapsed)
	observe(runner.simulation)
	return runner


func measure(scenario: String, seconds: float, profile: bool = false, short_exact: float = 0.0, dense_reference: bool = false) -> Dictionary:
	var result: Dictionary = {"scenario": scenario, "duration": seconds, "profiled": profile, "dense_reference": dense_reference, "runs": {}, "source_hashes": {}}
	for file in ["autobuyer_boundary.gd", "autobuyer_offline.gd", "autobuyer_fixtures.gd", "autobuyer_tests.gd", "autobuyer_activity.gd", "adaptive_offline.gd", "feedback_offline.gd", "horizon_runner.gd"]:
		result["source_hashes"][file] = FileAccess.get_file_as_string("res://tests/experimental/" + file).sha256_text()
	var candidates: Dictionary = {}
	# Serial, separate timers; no reference caches or diagnostic CPU attribution
	# mixed into the non-profiled measurements.
	var order: Array = ["event", "previous", "precise"] if dense_reference else ["precise", "previous", "event"]
	for kind in order:
		var runner = make_runner(scenario, kind, short_exact)
		if profile:
			preload("res://tests/experimental/autobuyer_activity.gd").install(runner.simulation.state)
		runner.simulation.profiling_enabled = profile
		if dense_reference and kind == "precise":
			for candidate_kind in ["event", "previous"]:
				for tick in candidates[candidate_kind].samples:
					runner.requested_audits[tick] = true
		var start: int = Time.get_ticks_usec()
		var counters: Dictionary = runner.run(seconds)
		var wall: float = float(Time.get_ticks_usec() - start) / 1e6
		check(counters.get("strict_failure", "") == "", "Trial failure: " + scenario + "/" + kind + ": " + str(counters))
		candidates[kind] = runner
		var consumers: Array[String] = []
		var cycles: Array[String] = []
		for generator in runner.simulation.state.generators.values():
			if generator.unlocked and not generator.get_active_inputs().is_empty():
				consumers.append(generator.definition.id)
			if generator.cycle_active or generator.auto_run_cycles:
				cycles.append(generator.definition.id)
		var purchases: Array = []
		for event in runner.simulation.state.gameplay_log.events:
			if event["category"] == "purchase":
				purchases.append(event)
		result["runs"][kind] = {"seconds": wall, "counters": counters, "purchases": purchases,
			"profile": runner.simulation.get_profile_report() if profile else {},
			"other_blockers": {"consumers": consumers, "cycles": cycles, "prestige_currency": preload("res://tests/experimental/accuracy_modes.gd").prestige_exposed(runner.simulation.state)},
			"activity": {"generator": runner.simulation.state.generator_automation_manager.get("metrics"), "upgrade": runner.simulation.state.upgrade_automation_manager.get("metrics")} if profile else {}}
		print("AUTOBUYER_PHASE " + JSON.stringify({"kind": kind, "scenario": scenario, "seconds": wall}))
	var reference = candidates["precise"]
	for kind in ["previous", "event"]:
		var runner = candidates[kind]
		var comparison: Dictionary = validate(reference, runner, scenario + "/" + kind)
		comparison["speedup"] = float(result["runs"]["precise"]["seconds"]) / maxf(float(result["runs"][kind]["seconds"]), 1e-9)
		result["runs"][kind].merge(comparison)
	result["failure_count"] = failures.size()
	return result


func validate(reference, runner, label: String) -> Dictionary:
	var state: GameState = runner.simulation.state
	var expected: GameState = reference.simulation.state
	var discrete: bool = Metrics.discrete(state) == Metrics.discrete(expected)
	var rng: bool = state.gameplay_rng.state == expected.gameplay_rng.state
	var reward: bool = PrestigeSystem.new().calculate_eternal_flame_gain(state) == PrestigeSystem.new().calculate_eternal_flame_gain(expected)
	var maximum: Dictionary = {"normalized": 0.0, "resource_abs": 0.0, "resource_rel": 0.0, "statistics_abs": 0.0, "statistics_rel": 0.0}
	for tick in runner.samples:
		if not reference.samples.has(tick):
			continue
		var actual: Dictionary = runner.samples[tick]
		var original: Dictionary = reference.samples[tick]
		discrete = discrete and actual["discrete"] == original["discrete"]
		rng = rng and actual["rng"] == original["rng"]
		reward = reward and actual["prestige"] == original["prestige"]
		var difference: Dictionary = Metrics.compare(original["numeric"], actual["numeric"], 1e-8, 1e-4)
		for key in maximum:
			maximum[key] = maxf(float(maximum[key]), float(difference[key]))
	var final_error: Dictionary = Metrics.compare(Metrics.numeric(expected, reference.manager), Metrics.numeric(state, runner.manager), 1e-8, 1e-4)
	check(discrete, "Discrete/purchase tick or cost mismatch: " + label)
	check(rng, "RNG mismatch: " + label)
	check(reward, "Prestige mismatch: " + label)
	check(float(maximum["normalized"]) <= 1.0 and float(final_error["normalized"]) <= 1.0, "Numerical target exceeded: " + label)
	return {"discrete_parity": discrete, "rng_parity": rng, "prestige_parity": reward,
		"maximum_sampled_deviation": maximum, "final_deviation": final_error,
		"exact_state": full(state) == full(expected), "adaptive_coverage": 1.0 - float(runner.counters.get("fallback_fraction", 1.0))}


func test_waiting() -> void:
	for scenario in ["late_wait", "late_upgrade", "late_both", "technology_locked"]:
		var reference = make_runner(scenario, "precise")
		var runner = make_runner(scenario, "event")
		reference.run(120.0)
		runner.run(120.0)
		validate(reference, runner, scenario)
		check(runner.counters["accepted"] > 0, "Proven waiting scenario did not adapt: " + scenario)
		check(runner.counters["strict_failure"] == "", "Waiting trial failed: " + scenario)


func test_purchase_boundaries() -> void:
	for scenario in ["early", "competing", "unlock", "upgrades", "middle", "consumption", "oscillation", "mixed"]:
		var reference = make_runner(scenario, "precise")
		var runner = make_runner(scenario, "event")
		reference.run(60.0)
		runner.run(60.0)
		validate(reference, runner, scenario)
		check(full(reference.simulation.state) == full(runner.simulation.state), "Unsupported purchase scenario was not binary exact: " + scenario)
		check(runner.counters["accepted"] == 0, "Growing-resource affordability/consumer/cycle scenario adapted: " + scenario)
		var purchased: bool = false
		for event in reference.simulation.state.gameplay_log.events:
			purchased = purchased or event["category"] == "purchase"
		if scenario in ["early", "competing", "unlock", "upgrades", "consumption"]:
			check(purchased, "Purchase fixture did not exercise a real purchase: " + scenario)
		if scenario == "consumption":
			check(reference.simulation.state.get_upgrade("thermal_conversion").level > 0, "Input/output modifier upgrade was never bought.")
		if scenario == "unlock":
			check(reference.simulation.state.get_generator("molecular_agitation").unlocked, "Unlock fixture did not cross the level-25 unlock.")
		if scenario in ["early", "competing", "unlock", "upgrades", "consumption"]:
			var first_tick: int = 0
			for event in reference.simulation.state.gameplay_log.events:
				if event["category"] == "purchase":
					first_tick = int(event["tick"])
					break
			for offset in [-1, 0, 1]:
				var seconds: float = float(first_tick + offset) * TimeManager.OFFLINE_MAX_GAME_STEP
				var before_after_reference = make_runner(scenario, "precise")
				var before_after = make_runner(scenario, "event")
				before_after_reference.run(seconds)
				before_after.run(seconds)
				validate(before_after_reference, before_after, scenario + "/purchase boundary/" + str(offset))
				check(full(before_after_reference.simulation.state) == full(before_after.simulation.state), "Pre/post purchase balances changed.")

	for seconds in [4.9, 5.0, 5.1, 9.9, 10.0, 10.1, 20.05]:
		var reference = make_runner("upgrades", "precise")
		var runner = make_runner("upgrades", "event")
		reference.run(seconds)
		runner.run(seconds)
		validate(reference, runner, "cooldown boundary " + str(seconds))
		check(full(reference.simulation.state) == full(runner.simulation.state), "Cooldown boundary changed binary state.")


func test_proof_invalidation() -> void:
	var runner = make_runner("late_wait", "event")
	# Settle the real cache, never fabricate a waiting dictionary.
	runner.simulation.update(6.0, true)
	check(Boundary.inspect(runner.simulation)["status"] == "provably_waiting", "Settled real waiting cache was not proved.")
	var converted = make_runner("late_all_wait", "event")
	converted.simulation.update(6.0, true)
	check(not Boundary.inspect(converted.simulation).get("upper", {}).has(ResourceIds.HEAT), "Matter-to-Heat conversion was omitted from the source graph.")
	var furnace: Generator = runner.simulation.state.get_generator("matter_furnace")
	furnace.level += 1
	check(Boundary.inspect(runner.simulation)["status"] == "generator_wait_transition", "Level change reused stale cost.")
	runner.simulation.update(0.1, true)
	check(Boundary.inspect(runner.simulation)["status"] == "provably_waiting", "Cost refresh did not restore proof.")
	runner.simulation.state.set_resource_amount(ResourceIds.MATTER, furnace.get_cost(runner.simulation.state))
	check(Boundary.inspect(runner.simulation)["status"] == "currently_affordable", "Affordable purchase was declared idle.")
	var dynamic = make_runner("late_dynamic", "event")
	dynamic.simulation.update(6.0, true)
	check(Boundary.inspect(dynamic.simulation)["status"] == "dynamic_cost", "Dynamic cost was treated as static.")
	var modifier: Modifier
	for candidate in dynamic.simulation.state.get_generator("matter_furnace").modifiers:
		if candidate.type == ModifierTypes.COST:
			modifier = candidate
			break
	modifier.dynamic = false
	modifier.id = "experimental_cost"
	var sensitivity := ModifierSensitivity.new(modifier.id, 1.0)
	sensitivity.dynamic = true
	sensitivity.dynamic_formula = ModifierSensitivity.DYNAMIC_RESOURCE_SQRT_INVERSE
	sensitivity.dynamic_resource_id = ResourceIds.HEAT
	dynamic.simulation.state.get_generator("matter_furnace").modifier_sensitivities.append(sensitivity)
	check(Boundary.inspect(dynamic.simulation)["status"] == "dynamic_cost_sensitivity", "Dynamic sensitivity was treated as static.")
	runner.simulation.state.set_resource_amount(ResourceIds.MATTER, 0.0)
	runner.simulation.state.realm_effects.generator_cost_multiplier *= 0.5
	check(Boundary.inspect(runner.simulation)["status"] == "generator_wait_transition", "Realm change reused stale waiting cost.")
	# Alternating external availability invalidates a previous proof immediately.
	# This is a boundary unit test; consumer-driven fluctuation uses exact ticks
	# in test_purchase_boundaries, not an assumed constant-rate forecast.
	var oscillating = make_runner("late_wait", "event")
	var oscillating_reference = make_runner("late_wait", "precise")
	for candidate in [oscillating, oscillating_reference]:
		candidate.simulation.update(6.0, true)
	for index in range(20):
		for candidate in [oscillating, oscillating_reference]:
			var target: Generator = candidate.simulation.state.get_generator("matter_furnace")
			candidate.simulation.state.set_resource_amount(ResourceIds.MATTER, target.get_cost(candidate.simulation.state) * (0.99 if index % 2 == 0 else 1.01))
		var before: String = full(oscillating.simulation.state)
		var prediction: Dictionary = Boundary.inspect(oscillating.simulation)
		check(full(oscillating.simulation.state) == before, "Affordability inspection mutated gameplay state.")
		check((prediction["status"] == "currently_affordable") == (index % 2 == 1), "Oscillating availability reused a stale prediction.")
		for candidate in [oscillating, oscillating_reference]:
			candidate.simulation.state.generator_automation_manager.update(0.1, candidate.simulation, true)
		check(full(oscillating.simulation.state) == full(oscillating_reference.simulation.state), "Oscillating manager purchase/cost state diverged.")



func test_zero_short() -> void:
	for seconds in [0.0, 0.01, 0.15, 30.0]:
		var reference = make_runner("late_both", "precise")
		var runner = make_runner("late_both", "event", 600.0)
		reference.run(seconds)
		runner.run(seconds)
		check(full(reference.simulation.state) == full(runner.simulation.state), "Short/zero mitigation changed state.")
