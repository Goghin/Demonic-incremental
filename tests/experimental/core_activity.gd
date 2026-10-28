extends SceneTree

const Fixtures = preload("res://tests/experimental/core_fixtures.gd")
const Bound = preload("res://tests/experimental/core_cycle_bound.gd")
var elapsed: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options: Dictionary = {"scenarios": "early,mid,forge_competing,forge_running,forge", "output": "res://tests/experimental/core_activity.json"}
	for argument: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	for scenario: String in str(options["scenarios"]).split(","):
		if not Fixtures.SCENARIOS.has(scenario):
			push_error("Invalid activity scenario")
			quit(1)
			return
	var results: Array[Dictionary] = []
	for scenario: String in str(options["scenarios"]).split(","):
		var state: GameState = Fixtures.make_state(scenario)
		var simulation := Simulation.new(state)
		var manager := TimeManager.new(simulation)
		state.simulation_statistics = manager.simulation_statistics
		elapsed = 0.0
		state.gameplay_log.clock = func() -> float: return elapsed
		simulation.prepare_offline()
		var counts: Dictionary = {}
		var flags: Dictionary = {}
		var speed: Dictionary = {}
		var cycle_bounds: Dictionary = {}
		var boundary_usec: int = 0
		var boundary_calls: int = 0
		for g: Generator in state.generators.values():
			flags[g.definition.id] = [g.operating, g.is_throttled, g.cycle_active]
			if g.cycle_active:
				var start: int = Time.get_ticks_usec()
				cycle_bounds[g.definition.id] = Bound.inspect(g, state, true)
				boundary_usec += Time.get_ticks_usec() - start
				boundary_calls += 1
		var last_event: int = 0
		var gaps: Array[int] = []
		var event_ticks: Array[int] = []
		var initial: Dictionary = state.current_run_statistics.statistics.duplicate(true)
		for tick: int in range(6000):
			elapsed = float(tick + 1) * TimeManager.OFFLINE_MAX_GAME_STEP
			state.set_lava_mite_dormancy_penalty(manager.get_dormancy_penalty(elapsed))
			var matter_before: float = _stat(state, ResourceIds.MATTER, "total_produced")
			var heat_loss_before: float = _stat(state, ResourceIds.HEAT, "total_lost")
			var decay_before: float = state.total_matter_decayed_this_prestige
			var events_before: int = state.gameplay_log.events.size()
			for g: Generator in state.generators.values():
				if g.cycle_active:
					var value: float = simulation._get_cycle_speed_multiplier(g)
					var id: String = g.definition.id
					if not speed.has(id):
						speed[id] = {"min": value, "max": value, "active_ticks": 0}
					speed[id]["min"] = minf(speed[id]["min"], value)
					speed[id]["max"] = maxf(speed[id]["max"], value)
					speed[id]["active_ticks"] += 1
			simulation.update(TimeManager.OFFLINE_MAX_GAME_STEP, true)
			var event: bool = state.gameplay_log.events.size() != events_before
			if _stat(state, ResourceIds.MATTER, "total_produced") > matter_before:
				_inc(counts, "integer_matter_output_ticks")
				event = true
			if _stat(state, ResourceIds.HEAT, "total_lost") > heat_loss_before:
				_inc(counts, "heat_loss_ticks")
			if state.total_matter_decayed_this_prestige > decay_before:
				_inc(counts, "matter_decay_to_heat_ticks")
			for g: Generator in state.generators.values():
				var id: String = g.definition.id
				var current: Array = [g.operating, g.is_throttled, g.cycle_active]
				for index: int in range(3):
					if current[index] != flags[id][index]:
						_inc(counts, ["operating/", "throttle/", "cycle_active/"][index] + id)
						event = true
				flags[id] = current
			if event:
				gaps.append(tick + 1 - last_event)
				last_event = tick + 1
				event_ticks.append(tick + 1)
		gaps.append(6000 - last_event)
		gaps.sort()
		var flows: Dictionary = {}
		for id: String in state.resources:
			flows[id] = {}
			for field: String in ["total_produced", "total_consumed", "total_lost"]:
				flows[id][field] = _stat(state, id, field) - float(initial.get(id, {}).get(field, 0.0))
		results.append({"scenario": scenario, "duration": 600.0, "counts": counts, "speed": speed, "conditional_cycle_bounds": cycle_bounds, "boundary_calls": boundary_calls, "boundary_usec": boundary_usec, "event_ticks": event_ticks, "event_gap_seconds": {"median": float(gaps[gaps.size() >> 1]) * 0.1, "p95": float(gaps[mini(gaps.size() - 1, floori(gaps.size() * 0.95))]) * 0.1, "max": float(gaps[-1]) * 0.1}, "flows": flows, "events": state.gameplay_log.events})
	var file: FileAccess = FileAccess.open(str(options["output"]), FileAccess.WRITE)
	file.store_string(JSON.stringify({"note": "600-second authoritative activity survey, not a throughput benchmark", "runs": results}, "\t") + "\n")
	print("CORE_ACTIVITY_DONE")
	quit()


func _stat(state: GameState, id: String, field: String) -> float:
	return float(state.current_run_statistics.statistics.get(id, {}).get(field, 0.0))


func _inc(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1
