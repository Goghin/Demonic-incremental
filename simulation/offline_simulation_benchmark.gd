extends SceneTree


const Comparison = preload("res://simulation/offline_simulation_comparison.gd")

const BASELINE_STEP: float = 0.1
const COMPARISON_STEPS: Array[float] = [0.5, 1.0]
const BENCHMARK_DURATIONS: Array[Dictionary] = [
	{"label": "1 hour", "seconds": 3600.0}
]


func _initialize() -> void:
	call_deferred("_run_benchmarks")


func _run_benchmarks() -> void:
	print("")
	print("========================================")
	print(" OFFLINE SIMULATION BASELINE BENCHMARK")
	print("========================================")
	print("Baseline step: %.2f seconds" % BASELINE_STEP)
	print("Test profile: high realm stats, seeded resources,")
	print("all generators unlocked, cycle generator and automation enabled.")
	print("Accuracy report includes per-resource totals and generator states.")
	print("These are controlled test results, not a copy of a player save.")
	print("")

	var one_hour_baseline: Dictionary = {}

	for duration_data in BENCHMARK_DURATIONS:
		var label: String = str(duration_data["label"])
		var duration: float = float(duration_data["seconds"])
		var capture_diagnostics: bool = is_equal_approx(duration, 3600.0)
		var result: Dictionary = _run_case(
			duration,
			BASELINE_STEP,
			false,
			capture_diagnostics
		)

		print(
			"%s | wall time: %s | steps: %s | simulated: %s" % [
				label,
				_format_elapsed(float(result["elapsed_seconds"])),
				_format_integer(int(result["steps"])),
				_format_duration(duration)
			]
		)

		if is_equal_approx(duration, 3600.0):
			one_hour_baseline = result

	# Run profiling separately so its measurement overhead does not distort
	# the baseline wall time or the step-size speedup comparison.
	var profiled_case: Dictionary = _run_case(
		3600.0,
		BASELINE_STEP,
		true
	)
	_print_profile_report(profiled_case["profile"])

	print("")
	print("========================================")
	print(" STEP-SIZE ACCURACY CHECK (1 HOUR)")
	print("========================================")

	for step_size in COMPARISON_STEPS:
		var result: Dictionary = _run_case(
			3600.0,
			step_size,
			false,
			true
		)
		var max_deviation: float = _get_max_deviation(
			one_hour_baseline,
			result
		)

		if not is_finite(max_deviation):
			push_error("Invalid or non-finite benchmark comparison data.")
			quit(1)
			return

		var speedup: float = 1.0
		if float(result["elapsed_seconds"]) > 0.0:
			speedup = (
				float(one_hour_baseline["elapsed_seconds"])
				/ float(result["elapsed_seconds"])
			)

		print(
			"Step %.2fs | wall time: %s | speedup: %.2fx | max metric deviation: %.4f%%" % [
				step_size,
				_format_elapsed(float(result["elapsed_seconds"])),
				speedup,
				max_deviation
			]
		)
		_print_detailed_comparison(one_hour_baseline, result)
		_print_first_progression_divergence(
			one_hour_baseline.get("diagnostic_events", []),
			result.get("diagnostic_events", []),
			step_size
		)
		_print_affordability_checkpoints(
			one_hour_baseline.get("diagnostic_checkpoints", []),
			result.get("diagnostic_checkpoints", []),
			step_size
		)
		_print_heat_leak_checkpoints(
			one_hour_baseline.get("diagnostic_environmental_checkpoints", []),
			result.get("diagnostic_environmental_checkpoints", []),
			step_size
		)

	print("")
	print("Benchmark complete. No save file was read or modified.")
	quit()


func _run_case(
	duration_seconds: float,
	step_size: float,
	enable_profiling: bool = false,
	enable_diagnostics: bool = false
) -> Dictionary:
	# Keep stochastic cycle events reproducible across step-size comparisons.
	seed(123456)
	var state := GameState.new()
	state.gameplay_rng.seed = 123456
	_configure_test_state(state)

	var simulation := Simulation.new(state)
	simulation.profiling_enabled = enable_profiling
	simulation.diagnostics_enabled = enable_diagnostics
	var time_manager := TimeManager.new(simulation)
	var offline_statistics := ResourceStatistics.new()
	state.simulation_statistics = offline_statistics

	var elapsed_seconds: float = 0.0
	var steps: int = 0
	var target_steps: int = ceili(duration_seconds / step_size)
	var start_usec: int = Time.get_ticks_usec()

	# Use a fixed iteration count instead of a floating-point while condition.
	# This prevents an extra tiny step at exact duration boundaries.
	for step_index in range(target_steps):
		var delta: float = min(
			step_size,
			duration_seconds - elapsed_seconds
		)
		if delta <= 0.0:
			break

		state.set_lava_mite_dormancy_penalty(
			time_manager.get_dormancy_penalty(
				elapsed_seconds + delta
			)
		)

		simulation.diagnostic_time_seconds = elapsed_seconds + delta
		simulation.update(delta, true)
		elapsed_seconds = min(
			duration_seconds,
			elapsed_seconds + delta
		)
		steps += 1

	var wall_seconds: float = (
		float(Time.get_ticks_usec() - start_usec) / 1000000.0
	)

	var result: Dictionary = {
		"elapsed_seconds": wall_seconds,
		"steps": steps,
		"resources": _snapshot_resources(state),
		"generators": _snapshot_generators(state),
		"overflow": state.total_overflow_this_prestige,
		"statistics": offline_statistics.to_dictionary(),
		"profile": simulation.get_profile_report(),
		"diagnostic_events": simulation.diagnostic_events.duplicate(true),
		"diagnostic_checkpoints": simulation.diagnostic_checkpoints.duplicate(true),
		"diagnostic_environmental_checkpoints": simulation.diagnostic_environmental_checkpoints.duplicate(true)
	}

	# GameState and its managers reference one another. Break those references
	# for this throwaway benchmark instance so the headless process can clean up.
	state.simulation_statistics = null
	state.generator_automation_manager.state = null
	state.upgrade_automation_manager.state = null
	state.upgrade_system.state = null
	simulation.state = null
	time_manager.simulation = null
	state.generator_automation_manager = null
	state.upgrade_automation_manager = null
	state.upgrade_system = null

	return result


func _print_first_progression_divergence(
	baseline_events: Array,
	comparison_events: Array,
	comparison_step: float
) -> void:
	print("")
	print("  PROGRESSION EVENT TRACE (0.10s baseline vs %.2fs)" % comparison_step)
	print("    Baseline events: %s | comparison events: %s" % [
		baseline_events.size(),
		comparison_events.size()
	])

	var shared_count: int = mini(baseline_events.size(), comparison_events.size())
	var divergence_index: int = -1
	var timing_only: bool = false
	for i in range(shared_count):
		var a: Dictionary = baseline_events[i]
		var b: Dictionary = comparison_events[i]
		var same_event: bool = (
			str(a.get("type", "")) == str(b.get("type", ""))
			and str(a.get("id", "")) == str(b.get("id", ""))
			and int(a.get("level", 0)) == int(b.get("level", 0))
			and str(a.get("source", "")) == str(b.get("source", ""))
		)
		if not same_event:
			divergence_index = i
			break
		if absf(float(a.get("time", 0.0)) - float(b.get("time", 0.0))) > 1.0:
			divergence_index = i
			timing_only = true
			break

	if divergence_index < 0 and baseline_events.size() != comparison_events.size():
		divergence_index = shared_count

	if divergence_index < 0:
		print("    No event-sequence divergence found (timing differences stayed within 1 second).")
		return

	if timing_only:
		print("    First detected divergence: event timing differs by more than 1.0 simulated second.")
	else:
		print("    First detected divergence: event identity/order differs.")
	print("    Event index: %s" % divergence_index)
	for i in range(maxi(0, divergence_index - 2), mini(divergence_index + 4, shared_count)):
		var a: Dictionary = baseline_events[i]
		var b: Dictionary = comparison_events[i]
		print("      #%s baseline t=%s: %s %s L%s (%s)" % [
			i,
			_format_number(float(a.get("time", 0.0))),
			str(a.get("type", "")),
			str(a.get("id", "")),
			str(a.get("level", "")),
			str(a.get("source", ""))
		])
		print("         step %.2fs t=%s: %s %s L%s (%s)" % [
			comparison_step,
			_format_number(float(b.get("time", 0.0))),
			str(b.get("type", "")),
			str(b.get("id", "")),
			str(b.get("level", "")),
			str(b.get("source", ""))
		])
	if divergence_index >= shared_count:
		print("    One trace ended before the other at the first unmatched event.")


func _print_affordability_checkpoints(
	baseline_checkpoints: Array,
	comparison_checkpoints: Array,
	comparison_step: float
) -> void:
	print("")
	print("  RESOURCE / PURCHASE AFFORDABILITY CHECK (4.5s–5.5s)")
	for label in ["0.10s baseline", "%.2fs comparison" % comparison_step]:
		var checkpoints: Array = baseline_checkpoints if label == "0.10s baseline" else comparison_checkpoints
		print("    %s:" % label)
		var printed: int = 0
		for checkpoint_variant in checkpoints:
			var checkpoint: Dictionary = checkpoint_variant
			var time: float = float(checkpoint.get("time", 0.0))
			if time < 4.5 or time > 5.5:
				continue
			var resources: Dictionary = checkpoint.get("resources", {})
			var generators: Dictionary = checkpoint.get("generators", {})
			var states: Array[String] = []
			for generator_id in [
				"atomic_friction",
				"molecular_agitation",
				"thermal_furnace",
				"thermal_compressor",
				"matter_furnace"
			]:
				var info: Dictionary = generators.get(generator_id, {})
				states.append("%s L%s %s/%s %s" % [
					generator_id,
					str(info.get("level", "?")),
					_format_number(float(info.get("available", 0.0))),
					_format_number(float(info.get("cost", 0.0))),
					"CAN BUY" if bool(info.get("affordable", false)) else "can't buy"
				])
			print("      t=%s | Heat=%s Matter=%s Ash=%s" % [
				_format_number(time),
				_format_number(float(resources.get(str(ResourceIds.HEAT), 0.0))),
				_format_number(float(resources.get(str(ResourceIds.MATTER), 0.0))),
				_format_number(float(resources.get(str(ResourceIds.ASH), 0.0)))
			])
			for state_line in states:
				print("        %s" % state_line)
			printed += 1
		if printed == 0:
			print("      No checkpoints recorded in this interval.")


func _print_heat_leak_checkpoints(
	baseline_checkpoints: Array,
	comparison_checkpoints: Array,
	comparison_step: float
) -> void:
	print("")
	print("  HEAT-LEAK DIAGNOSTICS (4.0s–6.0s)")
	for label in ["0.10s baseline", "%.2fs comparison" % comparison_step]:
		var checkpoints: Array = baseline_checkpoints if label == "0.10s baseline" else comparison_checkpoints
		print("    %s:" % label)
		var printed: int = 0
		for checkpoint_variant in checkpoints:
			var checkpoint: Dictionary = checkpoint_variant
			var time: float = float(checkpoint.get("time", 0.0))
			if time < 4.0 or time > 6.0:
				continue
			print("      t=%s Δt=%s | Heat %s -> %s | threshold=%s | rate/s=%s | requested=%s | actual=%s" % [
				_format_number(time),
				_format_number(float(checkpoint.get("delta", 0.0))),
				_format_number(float(checkpoint.get("heat_before", 0.0))),
				_format_number(float(checkpoint.get("heat_after", 0.0))),
				_format_number(float(checkpoint.get("threshold", 0.0))),
				_format_number(float(checkpoint.get("leak_rate_per_second", 0.0))),
				_format_number(float(checkpoint.get("requested_loss", 0.0))),
				_format_number(float(checkpoint.get("actual_loss", 0.0)))
			])
			printed += 1
		if printed == 0:
			print("      No checkpoints recorded in this interval.")


func _print_profile_report(profile: Dictionary) -> void:
	var totals: Dictionary = profile.get("totals_usec", {})
	var counts: Dictionary = profile.get("call_counts", {})
	var sections: Array[String] = [
		"automatic_upgrades",
		"generator_processing",
		"environmental_effects",
		"generator_automation",
		"upgrade_automation"
	]
	var measured_total_usec: int = 0

	for section in sections:
		measured_total_usec += int(totals.get(section, 0))

	print("")
	print("  PROFILE BREAKDOWN (1-hour baseline)")
	print("  Timings are accumulated across all simulation steps.")
	for section in sections:
		var elapsed_usec: int = int(totals.get(section, 0))
		var calls: int = int(counts.get(section, 0))
		var percent: float = 0.0
		var average_usec: float = 0.0
		if measured_total_usec > 0:
			percent = float(elapsed_usec) / float(measured_total_usec) * 100.0
		if calls > 0:
			average_usec = float(elapsed_usec) / float(calls)
		print(
			"    %s | %s ms | %.1f%% | avg %.2f us/call | calls %s" % [
				section,
				_format_number(float(elapsed_usec) / 1000.0),
				percent,
				average_usec,
				_format_integer(calls)
			]
		)
	print(
		"    Measured phase total: %s ms" % [
			_format_number(float(measured_total_usec) / 1000.0)
		]
	)

	var environmental_details: Array[String] = [
		"matter_decay",
		"heat_leak",
		"heat_leak_integration"
	]
	var environmental_total_usec: int = int(totals.get("environmental_effects", 0))
	print("")
	print("  ENVIRONMENTAL EFFECTS DETAILS")
	print("  Subphase timings are nested within environmental_effects.")
	for section in environmental_details:
		var elapsed_usec: int = int(totals.get(section, 0))
		var calls: int = int(counts.get(section, 0))
		var percent: float = 0.0
		var average_usec: float = 0.0
		if environmental_total_usec > 0:
			percent = float(elapsed_usec) / float(environmental_total_usec) * 100.0
		if calls > 0:
			average_usec = float(elapsed_usec) / float(calls)
		print(
			"    %s | %s ms | %.1f%% of environmental phase | avg %.2f us/call | calls %s" % [
				section,
				_format_number(float(elapsed_usec) / 1000.0),
				percent,
				average_usec,
				_format_integer(calls)
			]
		)

	var automation_details: Array[String] = [
		"generator_automation_loop_checks",
		"generator_automation_waiting_checks",
		"generator_automation_purchase_attempts"
	]
	var automation_total_usec: int = int(totals.get("generator_automation", 0))
	print("")
	print("  GENERATOR AUTOMATION DETAILS")
	print("  Timings are nested within generator_automation where noted.")
	for section in automation_details:
		var elapsed_usec: int = int(totals.get(section, 0))
		var calls: int = int(counts.get(section, 0))
		var percent: float = 0.0
		var average_usec: float = 0.0
		if automation_total_usec > 0:
			percent = float(elapsed_usec) / float(automation_total_usec) * 100.0
		if calls > 0:
			average_usec = float(elapsed_usec) / float(calls)
		print(
			"    %s | %s ms | %.1f%% of automation phase | avg %.2f us/call | calls %s" % [
				section,
				_format_number(float(elapsed_usec) / 1000.0),
				percent,
				average_usec,
				_format_integer(calls)
			]
		)

	var generator_total_usec: int = int(totals.get("generator_processing", 0))
	var generator_details: Array[String] = [
		"generator_start_checks",
		"generator_continue_checks",
		"available_operating_duration",
		"input_consumption",
		"input_rate_calculation",
		"output_production",
		"production_rate_calculation",
		"cycle_generator_processing"
	]
	print("")
	print("  GENERATOR PROCESSING DETAILS")
	print("  Phase timings include nested rate-calculation timings listed below.")
	for section in generator_details:
		var elapsed_usec: int = int(totals.get(section, 0))
		var calls: int = int(counts.get(section, 0))
		var percent: float = 0.0
		var average_usec: float = 0.0
		if generator_total_usec > 0:
			percent = float(elapsed_usec) / float(generator_total_usec) * 100.0
		if calls > 0:
			average_usec = float(elapsed_usec) / float(calls)
		print(
			"    %s | %s ms | %.1f%% of generator phase | avg %.2f us/call | calls %s" % [
				section,
				_format_number(float(elapsed_usec) / 1000.0),
				percent,
				average_usec,
				_format_integer(calls)
			]
		)


func _configure_test_state(state: GameState) -> void:
	state.set_resource_amount(ResourceIds.HEAT, 2000000.0)
	state.set_resource_amount(ResourceIds.MATTER, 20000.0)
	state.set_resource_amount(ResourceIds.ASH, 5000.0)
	state.set_resource_amount(ResourceIds.CRYSTALLIZED_FLAME, 2.0)
	state.set_resource_amount(ResourceIds.ESSENCE, 100.0)

	# Stress-test realm effects using high values for the four active stats.
	# These are benchmark-only values; no player save is loaded or modified.
	state.realm_configuration.stability = 1000
	state.realm_configuration.integrity = 1000
	state.realm_configuration.intensity = 1000
	state.realm_configuration.density = 1000
	state.rebuild_realm_effects()

	var test_levels: Dictionary = {
		"atomic_friction": 20,
		"molecular_agitation": 10,
		"thermal_furnace": 5,
		"thermal_compressor": 2,
		"lava_mite_colony": 3,
		"matter_furnace": 3,
		"infernal_forge": 1
	}

	for generator_id in test_levels:
		var generator: Generator = state.get_generator(generator_id)
		if generator == null:
			continue

		generator.unlocked = true
		generator.level = int(test_levels[generator_id])
		generator.operating = false

		if generator.definition.cycle_based:
			generator.cycle_active = true
			generator.cycle_progress = 0.0

	# Unlock automation only in this temporary benchmark state.
	for generator_id in GeneratorAutomationManager.AUTOMATABLE_GENERATOR_IDS:
		state.eternal_flame_state.unlocked_technologies[
			"generator_automation_" + generator_id
		] = true
		state.generator_automation_manager.set_enabled(
			generator_id,
			true
		)

	for generator_id in UpgradeAutomationManager.AUTOMATABLE_GENERATOR_IDS:
		state.eternal_flame_state.unlocked_technologies[
			"upgrade_automation_" + generator_id
		] = true
		state.upgrade_automation_manager.set_enabled(
			generator_id,
			true
		)


func _snapshot_resources(state: GameState) -> Dictionary:
	var result: Dictionary = {}

	for resource_id in state.resources:
		result[str(resource_id)] = state.get_resource_amount(
			str(resource_id)
		)

	return result


func _snapshot_generators(state: GameState) -> Dictionary:
	var result: Dictionary = {}

	for generator_id in state.generators:
		var generator: Generator = state.get_generator(
			str(generator_id)
		)
		result[str(generator_id)] = {
			"level": generator.level,
			"operating": generator.operating,
			"cycle_progress": generator.cycle_progress,
			"cycle_active": generator.cycle_active
		}

	return result


func _get_max_deviation(
	baseline: Dictionary,
	comparison: Dictionary
) -> float:
	return Comparison.get_max_deviation(baseline, comparison)


func _print_detailed_comparison(
	baseline: Dictionary,
	comparison: Dictionary
) -> void:
	print("  Resource final amounts (baseline -> larger step):")
	var base_resources: Dictionary = baseline["resources"]
	var test_resources: Dictionary = comparison["resources"]
	for resource_id in base_resources:
		var base_amount: float = float(base_resources[resource_id])
		var test_amount: float = float(test_resources.get(resource_id, 0.0))
		print(
			"    %s: %s -> %s | delta: %s" % [
				str(resource_id),
				_format_number(base_amount),
				_format_number(test_amount),
				_format_number(test_amount - base_amount)
			]
		)

	print("  Resource flow totals (produced / consumed / lost):")
	var base_stats: Dictionary = baseline["statistics"]
	var test_stats: Dictionary = comparison["statistics"]
	for line in Comparison.format_statistics_comparison(base_stats, test_stats):
		print(line)

	print("  Generator states (level, operating, cycle active, cycle progress):")
	var base_generators: Dictionary = baseline["generators"]
	var test_generators: Dictionary = comparison["generators"]
	for generator_id in base_generators:
		var a: Dictionary = base_generators[generator_id]
		var b: Dictionary = test_generators.get(generator_id, {})
		if (
			int(a["level"]) != int(b.get("level", 0))
			or bool(a["operating"]) != bool(b.get("operating", false))
			or bool(a["cycle_active"]) != bool(b.get("cycle_active", false))
			or not is_equal_approx(
				float(a["cycle_progress"]),
				float(b.get("cycle_progress", 0.0))
			)
		):
			print(
				"    %s: L%s/%s, operating %s/%s, cycle %s/%s, progress %s/%s" % [
					str(generator_id),
					str(a["level"]),
					str(b.get("level", 0)),
					str(a["operating"]),
					str(b.get("operating", false)),
					str(a["cycle_active"]),
					str(b.get("cycle_active", false)),
					_format_number(float(a["cycle_progress"])),
					_format_number(float(b.get("cycle_progress", 0.0)))
				]
			)

	print(
		"  Total overflow: %s -> %s" % [
			_format_number(float(baseline["overflow"])),
			_format_number(float(comparison["overflow"]))
		]
	)


func _format_number(value: float) -> String:
	return str(value)


func _format_elapsed(seconds: float) -> String:
	if seconds < 1.0:
		return "%.1f ms" % (seconds * 1000.0)

	return "%.2f s" % seconds


func _format_duration(seconds: float) -> String:
	return "%.1f simulated hours" % (seconds / 3600.0)


func _format_integer(value: int) -> String:
	return String.num_int64(value)
