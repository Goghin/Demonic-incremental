extends "res://tests/experimental/adaptive_tests.gd"

const Runner = preload("res://tests/experimental/horizon_runner.gd")
const Modes = preload("res://tests/experimental/accuracy_modes.gd")
const Fixtures = preload("res://tests/experimental/horizon_fixtures.gd")

func run_mode(scenario: String, mode: String, seconds: float, options: Dictionary = {}, dense: bool = true):
	var state: GameState = Fixtures.make_state(scenario)
	var runner = Runner.new(Simulation.new(state))
	observe(runner.simulation)
	runner.accuracy_mode = mode
	runner.overrides = options
	runner.audit_all_accepted = dense
	var result: Dictionary = runner.run(seconds)
	check(result.get("strict_failure", "") == "", "Experimental mode failed: " + str(result))
	return runner


func test_modes() -> void:
	check(Modes.configuration("unknown").has("error"), "Unknown mode was accepted.")
	for options in [{"relative_tolerance": NAN}, {"minimum_step": 0.01}, {"numerical_retry_max_ticks": -1},
		{"fallback_window_ticks": 0}, {"force_exact": "false"}, {"new_parameter": 1}]:
		check(Modes.configuration("balanced", options).has("error"), "Invalid mode configuration was accepted.")
	check(Modes.configuration("precise", {"force_exact": false}).has("error"), "Precise mode could approximate.")
	for scenario in ["feedback", "cycles"]:
		var reference = run_mode(scenario, "precise", 15.0)
		for mode in ["balanced", "fast"]:
			var runner = run_mode(scenario, mode, 15.0)
			check(full(reference.simulation.state) == full(runner.simulation.state), "Short duration mitigation was not binary exact.")
			check(runner.counters["accepted"] == 0 and runner.counters["fallback_ticks"] == 150, "Short duration did not select exact simulation.")
			check(runner.counters.get("fallback_reasons", {}).has("short_duration_exact"), "Short duration decision was not reported.")
	for seconds in [0.0, 0.01, 0.15]:
		var reference = run_mode("stable", "precise", seconds)
		var runner = run_mode("stable", "balanced", seconds)
		check(full(reference.simulation.state) == full(runner.simulation.state), "Zero/fractional interval changed state.")


func test_exact_cleanups() -> void:
	var options: Dictionary = {"short_exact_seconds": 0.0, "reuse_probe_fields": false, "ensure_statistics_once": false}
	var baseline = run_mode("feedback", "balanced", 60.0, options)
	for candidate in [{"reuse_probe_fields": true}, {"ensure_statistics_once": true}, {"reuse_probe_fields": true, "ensure_statistics_once": true}]:
		var settings: Dictionary = options.duplicate(true)
		settings.merge(candidate, true)
		var actual = run_mode("feedback", "balanced", 60.0, settings)
		check(var_to_bytes(baseline.samples) == var_to_bytes(actual.samples), "A static cleanup changed a sampled numeric/discrete/RNG state.")
		check(full(baseline.simulation.state) == full(actual.simulation.state), "A static cleanup changed final binary state.")
		check(baseline.counters["evaluations"] == actual.counters["evaluations"], "Cleanup changed controller decisions.")


func test_diagnostics() -> void:
	var plain = run_mode("feedback", "balanced", 120.0, {"short_exact_seconds": 0.0}, true)
	var state: GameState = Fixtures.make_state("feedback")
	var instrumented = Runner.new(Simulation.new(state))
	observe(instrumented.simulation)
	instrumented.overrides = {"short_exact_seconds": 0.0}
	instrumented.diagnostics = true
	instrumented.segment_seconds = 60.0
	instrumented.audit_all_accepted = false
	instrumented.run(120.0)
	check(full(plain.simulation.state) == full(state), "Diagnostics/retained-audit policy changed numerical behavior.")
	check(instrumented.segments.size() == 2, "Hourly/minute diagnostic segments were not emitted.")
	var accepted: int = 0
	var fallback: int = 0
	for segment in instrumented.segments:
		accepted += int(segment["counters"]["accepted"])
		fallback += int(segment["counters"]["fallback_ticks"])
		check(float(segment["adaptive_coverage"]) >= 0.0 and float(segment["adaptive_coverage"]) <= 1.0, "Invalid adaptive coverage.")
		check(segment["counters"]["all_restore_usec"] > 0, "State restoration was not profiled.")
	check(accepted == instrumented.counters["accepted"] and fallback == instrumented.counters["fallback_ticks"], "Segment deltas did not sum to global counts.")


func test_prestige_protection() -> void:
	var state: GameState = Fixtures.make_state("reward_boundary")
	var system := PrestigeSystem.new()
	var initial: float = system.calculate_eternal_flame_gain(state)
	var saved_overflow: float = state.total_overflow_this_prestige
	state.total_overflow_this_prestige += 4.0
	check(system.calculate_eternal_flame_gain(state) > initial, "Boundary fixture did not demonstrate integer sensitivity to a tiny relative flow difference.")
	state.total_overflow_this_prestige = saved_overflow
	var reference = run_mode("reward_boundary", "precise", 5.0)
	for mode in ["balanced", "fast"]:
		var actual = run_mode("reward_boundary", mode, 5.0, {"short_exact_seconds": 0.0})
		check(full(reference.simulation.state) == full(actual.simulation.state), "A mode changed resources/statistics at a prestige boundary.")
		check(system.calculate_eternal_flame_gain(actual.simulation.state) > initial, "Reward transition was not exercised.")
		check(actual.counters["accepted"] == 0 and actual.counters["fallback_reasons"].has("prestige_currency_exposure"), "Prestige exposure was approximated.")


func test_fallbacks() -> void:
	for scenario in ["mixed", "automation", "consumers"]:
		var reference = run_mode(scenario, "precise", 30.0)
		for mode in ["balanced", "fast"]:
			var actual = run_mode(scenario, mode, 30.0, {"short_exact_seconds": 0.0})
			check(full(reference.simulation.state) == full(actual.simulation.state), "Mixed/automation/consumer fallback changed binary state.")
			check(actual.counters["accepted"] == 0, "An unsupported discrete controller entered projection.")


func test_monotone_margin() -> void:
	var before = run_mode("late_feedback", "balanced", 120.0, {"short_exact_seconds": 0.0, "monotone_decay_margin": false})
	var reference = run_mode("late_feedback", "precise", 120.0)
	for mode in ["balanced", "fast"]:
		var after = run_mode("late_feedback", mode, 120.0, {"short_exact_seconds": 0.0})
		check(after.counters["proven_margin_bypasses"] > 0 and after.counters["accepted"] > 0, "Asymptotic decay remained trapped by the absolute margin.")
		check(after.counters["fallback_ticks"] < before.counters["fallback_ticks"], "Monotone sink proof did not reduce exact fallback.")
		check(Metrics.discrete(after.simulation.state) == Metrics.discrete(reference.simulation.state), "Sink proof changed a discrete outcome.")
		check(after.simulation.state.gameplay_rng.state == reference.simulation.state.gameplay_rng.state, "Sink proof changed RNG.")
		check(float(Metrics.compare(Metrics.numeric(reference.simulation.state), Metrics.numeric(after.simulation.state), after.absolute_tolerance, after.relative_tolerance)["normalized"]) <= 1.0, "Sink proof exceeded the numerical target.")
	var source = Runner.new(Simulation.new(Fixtures.make_state("matter_equilibrium")))
	check(source._near_boundary_requires_exact(ResourceIds.MATTER, 100.09, 100.08, 100.08), "A producing system incorrectly used the source-free proof.")
	var state: GameState = Fixtures.make_state("late_feedback")
	var runner = Runner.new(Simulation.new(state))
	var original: String = full(state)
	check(runner._near_boundary_requires_exact(ResourceIds.MATTER, 3000.0, 100.09, 100.08), "A reference step that can cross was classified monotone-safe.")
	check(runner._near_boundary_requires_exact(ResourceIds.MATTER, 100.09, 99.99, 100.08), "A predicted crossing was classified safe.")
	check(full(state) == original, "The loss-rate query changed state/statistics or RNG.")
