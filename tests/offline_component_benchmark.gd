extends "res://tests/offline_performance_benchmark.gd"

func _run_benchmarks() -> void:
	seed(123456)
	var state := GameState.new()
	state.gameplay_rng.seed = 123456
	_configure_test_state(state)
	state.gameplay_log = TraceLog.new()
	var simulation: Variant = Simulation.new(state)
	if not simulation.has_method("_get_offline_automatic_upgrades"):
		push_error("Component benchmark requires the optimized candidate; use offline_performance_benchmark.gd for the reference.")
		quit(1)
		return
	simulation.update_automatic_upgrades()
	var raw_times: Array[int] = []
	var indexed_times: Array[int] = []
	for repeat_index in range(80):
		for indexed in ([false, true] if repeat_index % 2 == 0 else [true, false]):
			var start: int = Time.get_ticks_usec()
			for _index in range(1000):
				simulation.update_automatic_upgrades(indexed)
			var elapsed: int = Time.get_ticks_usec() - start
			if indexed:
				indexed_times.append(elapsed)
			else:
				raw_times.append(elapsed)
	print("COMPONENT_JSON " + JSON.stringify({"component": "automatic_upgrades", "raw_usec": raw_times, "indexed_usec": indexed_times}))
	var original_start: Array[int] = []
	var combined_start: Array[int] = []
	for repeat_index in range(40):
		var checksums: Array[float] = []
		for combined in ([false, true] if repeat_index % 2 == 0 else [true, false]):
			var checksum: float = 0.0
			var start: int = Time.get_ticks_usec()
			for _index in range(200):
				for generator in state.generators.values():
					if not generator.unlocked or generator.definition.cycle_based:
						continue
					var available: float = 0.0
					var can_start: bool = generator.can_start_operating(state, true) if combined else _original_partial_input_start(generator, state)
					if can_start:
						available = simulation._get_available_operating_delta(generator, 0.1)
					checksum += available
			var elapsed: int = Time.get_ticks_usec() - start
			checksums.append(checksum)
			if combined:
				combined_start.append(elapsed)
			else:
				original_start.append(elapsed)
		if checksums[0] != checksums[1]:
			push_error("Startup gate benchmark changed operating duration.")
			quit(1)
			return
	print("COMPONENT_JSON " + JSON.stringify({"component": "startup_gate", "raw_usec": original_start, "indexed_usec": combined_start}))
	quit()


func _original_partial_input_start(generator: Generator, state: GameState) -> bool:
	if not generator.unlocked or generator.level <= 0 or generator.manually_paused:
		return false
	if generator.definition.cycle_based and not generator.cycle_active:
		return false
	for input in generator.get_active_inputs():
		var amount: float = state.get_resource_amount(input.resource_id)
		var rate: float = generator.get_input_consumption_per_second(input, state)
		if rate > 0.0 and amount <= 0.0:
			return false
	return true
