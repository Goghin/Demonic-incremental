extends SceneTree


const BASELINE_STEP: float = 0.1
const COMPARISON_STEPS: Array[float] = [0.5, 1.0]
const BENCHMARK_DURATIONS: Array[Dictionary] = [
	{"label": "1 hour", "seconds": 3600.0},
	{"label": "8 hours", "seconds": 28800.0},
	{"label": "24 hours", "seconds": 86400.0}
]


func _initialize() -> void:
	call_deferred("_run_benchmarks")


func _run_benchmarks() -> void:
	print("")
	print("========================================")
	print(" OFFLINE SIMULATION BASELINE BENCHMARK")
	print("========================================")
	print("Baseline step: %.2f seconds" % BASELINE_STEP)
	print("Test profile: seeded resources, all generators unlocked,")
	print("cycle generator and automation behavior enabled.")
	print("Accuracy report includes per-resource totals and generator states.")
	print("These are controlled test results, not a copy of a player save.")
	print("")

	var one_hour_baseline: Dictionary = {}

	for duration_data in BENCHMARK_DURATIONS:
		var label: String = str(duration_data["label"])
		var duration: float = float(duration_data["seconds"])
		var result: Dictionary = _run_case(duration, BASELINE_STEP)

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

	print("")
	print("========================================")
	print(" STEP-SIZE ACCURACY CHECK (1 HOUR)")
	print("========================================")

	for step_size in COMPARISON_STEPS:
		var result: Dictionary = _run_case(3600.0, step_size)
		var max_deviation: float = _get_max_deviation(
			one_hour_baseline,
			result
		)

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

	print("")
	print("Benchmark complete. No save file was read or modified.")
	quit()


func _run_case(
	duration_seconds: float,
	step_size: float
) -> Dictionary:
	var state := GameState.new()
	_configure_test_state(state)

	var simulation := Simulation.new(state)
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

		simulation.update(delta)
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
		"statistics": offline_statistics.to_dictionary()
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


func _configure_test_state(state: GameState) -> void:
	state.set_resource_amount(ResourceIds.HEAT, 2000000.0)
	state.set_resource_amount(ResourceIds.MATTER, 20000.0)
	state.set_resource_amount(ResourceIds.ASH, 5000.0)
	state.set_resource_amount(ResourceIds.CRYSTALIZED_FLAME, 2.0)
	state.set_resource_amount(ResourceIds.ESSENCE, 100.0)

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
	var maximum_deviation: float = 0.0

	var baseline_resources: Dictionary = baseline["resources"]
	var comparison_resources: Dictionary = comparison["resources"]

	for resource_id in baseline_resources:
		var base_value: float = float(baseline_resources[resource_id])
		var test_value: float = float(
			comparison_resources.get(resource_id, 0.0)
		)
		maximum_deviation = max(
			maximum_deviation,
			_relative_deviation_percent(base_value, test_value)
		)

	var baseline_generators: Dictionary = baseline["generators"]
	var comparison_generators: Dictionary = comparison["generators"]

	for generator_id in baseline_generators:
		var base_generator: Dictionary = baseline_generators[generator_id]
		var test_generator: Dictionary = comparison_generators.get(
			generator_id,
			{}
		)

		maximum_deviation = max(
			maximum_deviation,
			_relative_deviation_percent(
				float(base_generator["level"]),
				float(test_generator.get("level", 0.0))
			)
		)
		maximum_deviation = max(
			maximum_deviation,
			_relative_deviation_percent(
				float(base_generator["cycle_progress"]),
				float(test_generator.get("cycle_progress", 0.0))
			)
		)

	maximum_deviation = max(
		maximum_deviation,
		_relative_deviation_percent(
			float(baseline["overflow"]),
			float(comparison["overflow"])
		)
	)

	var baseline_statistics: Dictionary = baseline["statistics"]
	var comparison_statistics: Dictionary = comparison["statistics"]

	for resource_id in baseline_statistics:
		if resource_id == "_total_overflow":
			continue

		var base_stats: Dictionary = baseline_statistics[resource_id]
		var test_stats: Dictionary = comparison_statistics.get(
			resource_id,
			{}
		)

		for metric in ["total_produced", "total_consumed", "total_lost"]:
			maximum_deviation = max(
				maximum_deviation,
				_relative_deviation_percent(
					float(base_stats.get(metric, 0.0)),
					float(test_stats.get(metric, 0.0))
				)
			)

	maximum_deviation = max(
		maximum_deviation,
		_relative_deviation_percent(
			float(baseline_statistics.get("_total_overflow", 0.0)),
			float(comparison_statistics.get("_total_overflow", 0.0))
		)
	)

	return maximum_deviation


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
	for resource_id in base_stats:
		if resource_id == "_total_overflow":
			continue
		var a: Dictionary = base_stats[resource_id]
		var b: Dictionary = test_stats.get(resource_id, {})
		print(
			"    %s produced %s -> %s | consumed %s -> %s | lost %s -> %s" % [
				str(resource_id),
				_format_number(float(a.get("total_produced", 0.0))),
				_format_number(float(b.get("total_produced", 0.0))),
				_format_number(float(a.get("total_consumed", 0.0))),
				_format_number(float(b.get("total_consumed", 0.0))),
				_format_number(float(a.get("total_lost", 0.0))),
				_format_number(float(b.get("total_lost", 0.0)))
			]
		)

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


func _relative_deviation_percent(
	baseline: float,
	comparison: float
) -> float:
	# Relative deviation is anchored to at least 1 to avoid enormous
	# percentages when comparing tiny values close to zero.
	var scale: float = max(abs(baseline), 1.0)
	return abs(comparison - baseline) / scale * 100.0


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
