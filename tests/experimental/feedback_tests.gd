extends "res://tests/experimental/adaptive_tests.gd"

const Feedback = preload("res://tests/experimental/feedback_offline.gd")

func compare_feedback(scenario: String, seconds: float, tolerance: float = 1e-4, exact: bool = false, loaded: bool = false, resistant: bool = false) -> Dictionary:
	var a: GameState = Fixture.make_state(scenario)
	var b: GameState = Fixture.make_state(scenario)
	if resistant:
		for state in [a, b]:
			state.set_resource_amount(ResourceIds.CRYSTALLIZED_FLAME, 3.0)
			state.set_resource_amount(ResourceIds.ESSENCE, 100.0)
	if loaded:
		var saved: Dictionary = JSON.parse_string(JSON.stringify(SaveManager.new().state_to_dictionary(a)))
		for state in [a, b]:
			check(SaveManager.new().dictionary_to_state(state, saved, SaveManager.SAVE_VERSION), "Feedback save failed to load.")
	if scenario == "feedback_threshold":
		# Settle discrete eligibility without advancing resources, so the
		# adaptive trial itself encounters the imminent environmental boundary.
		for state in [a, b]:
			state.set_resource_amount(ResourceIds.HEAT, state.realm_effects.heat_leak_threshold - 10.0)
			state.set_resource_amount(ResourceIds.MATTER, state.realm_effects.matter_decay_threshold - 0.5)
			Simulation.new(state).update_automatic_upgrades(true)
			for generator in state.generators.values():
				if generator.unlocked and generator.level > 0 and not generator.manually_paused and not generator.definition.cycle_based and generator.get_active_inputs().is_empty():
					generator.operating = true
	var initial_values: Dictionary = Metrics.numeric(a)
	var prototype = Feedback.new(Simulation.new(a))
	prototype.relative_tolerance = tolerance
	observe(prototype.simulation)
	prototype.run(seconds)
	var reference := Simulation.new(b)
	observe(reference)
	var manager := TimeManager.new(reference)
	if seconds > 0.0:
		b.simulation_statistics = manager.simulation_statistics
	for tick in range(ceili(seconds / 0.1)):
		var delta: float = minf(0.1, seconds - manager.game_time)
		manager.game_time += delta
		manager.offline_time += delta
		manager.prestige_time += delta
		manager.current_offline_duration += delta
		b.set_lava_mite_dormancy_penalty(manager.get_dormancy_penalty(manager.game_time))
		reference.update(delta, true)
		if prototype.samples.has(tick + 1):
			var sample: Dictionary = prototype.samples[tick + 1]
			var difference: Dictionary = Metrics.compare(Metrics.numeric(b, manager), sample["numeric"], 1e-8, tolerance)
			check(float(difference["normalized"]) <= 1.0, scenario + " sampled numeric failure: " + str(difference))
			check(Metrics.discrete(b) == sample["discrete"], scenario + " sampled discrete mismatch.")
			check(str(b.gameplay_rng.state) == sample["rng"], scenario + " sampled RNG mismatch.")
	check(prototype.counters["strict_failure"] == "", scenario + " trial mutated discrete state.")
	check(Metrics.discrete(a) == Metrics.discrete(b), scenario + " final discrete mismatch.")
	check(a.gameplay_rng.state == b.gameplay_rng.state, scenario + " final RNG mismatch.")
	check(float(Metrics.compare(Metrics.numeric(b, manager), Metrics.numeric(a, prototype.manager), 1e-8, tolerance)["normalized"]) <= 1.0, scenario + " final accuracy failure.")
	if exact:
		check(full(a) == full(b), scenario + " fallback not binary exact.")
	# Check actual flow accounting, independently of oracle agreement.
	for id in [ResourceIds.HEAT, ResourceIds.MATTER]:
		var path: String = "lifetime/" + str(id) + "/"
		var final: Dictionary = Metrics.numeric(a)
		var balance: float = float(initial_values["resource/" + str(id)])
		for pair in [["total_produced", 1.0], ["total_consumed", -1.0], ["total_lost", -1.0]]:
			balance += float(pair[1]) * (float(final.get(path + pair[0], 0.0)) - float(initial_values.get(path + pair[0], 0.0)))
		check(absf(balance - a.get_resource_amount(id)) <= 1e-7 * maxf(1.0, absf(balance)), "Integrated flow conservation failed for " + str(id))
	for state in [a, b]:
		var lifetime: ResourceStatistics = state.resource_statistics
		var offline: ResourceStatistics = state.simulation_statistics
		if offline != null:
			check(is_equal_approx(lifetime.total_overflow, state.total_overflow_this_prestige), "Overflow reward accounting diverged.")
			check(is_equal_approx(lifetime.total_matter_decayed, state.total_matter_decayed_this_prestige), "Decay reward accounting diverged.")
	return prototype.counters


func test_feedback_targets() -> void:
	for tolerance in [1e-3, 1e-4, 1e-5]:
		for scenario in ["heat", "matter", "feedback_matter", "feedback_combined", "feedback_threshold", "feedback_equilibrium", "feedback_high", "feedback_dynamic"]:
			if scenario == "feedback_equilibrium" and tolerance != 1e-4:
				continue # The separate benchmark sweeps all three equilibrium targets.
			var counters: Dictionary = compare_feedback(scenario, 10.0, tolerance)
			if scenario == "feedback_threshold":
				check(int(counters["rejection_reasons"].get("environmental_threshold", 0)) > 0, "Threshold test did not reject an adaptive crossing.")


func test_feedback_long_clocks() -> void:
	var counters: Dictionary = compare_feedback("feedback_representative", 1200.0)
	check(int(counters["accepted"]) > 0, "Combined feedback did not use the reference-map operator.")
	check(int(counters["evaluations"]) < 12000, "Combined feedback did not reduce evaluations.")


func test_feedback_fallbacks() -> void:
	for scenario in ["automation", "upgrade_automation", "cycles", "coupled", "feedback_starved", "feedback_recovery"]:
		var counters: Dictionary = compare_feedback(scenario, 30.0, 1e-4, true)
		check(int(counters["accepted"]) == 0, "Unsupported system entered adaptive feedback: " + scenario)


func test_feedback_retry_control() -> void:
	var state: GameState = Fixture.make_state("heat")
	var prototype = Feedback.new(Simulation.new(state))
	prototype.relative_tolerance = 1e-12
	prototype.absolute_tolerance = 1e-14
	var counters: Dictionary = prototype.run(60.0)
	check(int(counters["rejected"]) > 0, "Retry fixture did not reject trials.")
	check(int(counters["rejected"]) < 59, "Retry cooldown failed to bound trial overhead.")
	check(int(counters["fallback_reasons"].get("numerical_retry_cooldown", 0)) > 0, "Numerical cooldown was not reported.")
	check(int(counters["rejected_usec"]) > 0 and not counters["rejection_fields"].is_empty(), "Rejection diagnostics missing.")
	var reference: GameState = Fixture.make_state("heat")
	var simulation := Simulation.new(reference)
	reference.simulation_statistics = ResourceStatistics.new()
	var elapsed: float = 0.0
	for _tick in range(600):
		var delta: float = minf(0.1, 60.0 - elapsed)
		elapsed = minf(60.0, elapsed + delta)
		simulation.update(delta, true)
	check(full(state) == full(reference), "Rejected trials contaminated exact fallback statistics.")


func test_feedback_save_short() -> void:
	compare_feedback("matter", 120.0, 1e-4, false, true)
	compare_feedback("matter", 120.0, 1e-4, false, false, true)
	for seconds in [0.0, 0.01, 0.15, 0.5]:
		compare_feedback("feedback_combined", seconds, 1e-4, true)


func test_feedback_offline_entry() -> void:
	var state: GameState = Fixture.make_state("idle")
	state.gameplay_interval_produced[ResourceIds.HEAT] = 9.0
	var simulation := Simulation.new(state)
	simulation._gameplay_snapshot_elapsed = 12.0
	var prototype = Feedback.new(simulation)
	check(prototype.guard() == "offline_entry_transition", "Uncommitted offline entry was not guarded.")
	var counters: Dictionary = prototype.run(1.0)
	check(int(counters["fallback_reasons"].get("offline_entry_transition", 0)) == 10, "Offline entry did not use reference ticks.")
	check(simulation._gameplay_was_offline and simulation._gameplay_snapshot_elapsed == 0.0, "Offline logging transition was lost.")
	check(simulation._gameplay_snapshot_realm_run_index == state.gameplay_realm_run_index, "Realm logging snapshot was not committed.")
	check(not state.track_gameplay_interval_statistics and state.gameplay_interval_produced.is_empty(), "Offline entry mixed active interval counters into catch-up.")
