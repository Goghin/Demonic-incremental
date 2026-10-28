extends SceneTree

const Fixtures = preload("res://tests/experimental/core_fixtures.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const GeneratorProbe = preload("res://tests/experimental/kernel_profile_generator.gd")
const ModifierProbe = preload("res://tests/experimental/kernel_profile_modifier.gd")
const StatisticsProbe = preload("res://tests/experimental/kernel_profile_statistics.gd")
const EventProbe = preload("res://tests/experimental/kernel_profile_events.gd")
const LogProbe = preload("res://tests/experimental/kernel_profile_log.gd")
const Metrics = preload("res://tests/experimental/adaptive_metrics.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _copy_fields(source: Object, target: Object) -> void:
	for property: Dictionary in source.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			target.set(property["name"], source.get(property["name"]))


func _instrument(state: GameState) -> void:
	state.gameplay_log = LogProbe.new()
	for id: String in state.generators:
		var original: Generator = state.generators[id]
		var probe: Generator = GeneratorProbe.new(original.definition)
		_copy_fields(original, probe)
		var replacements: Dictionary = {}
		var modifiers: Array[Modifier] = []
		for modifier: Modifier in original.modifiers:
			var measured: Modifier = ModifierProbe.new(modifier.type, modifier.target_id, modifier.multiplier)
			_copy_fields(modifier, measured)
			modifiers.append(measured)
			replacements[modifier] = measured
		probe.modifiers = modifiers
		for resource_id: String in probe._production_modifier_cache:
			var cached: Array[Modifier] = probe._production_modifier_cache[resource_id]
			for index: int in range(cached.size()):
				cached[index] = replacements[cached[index]]
		state.generators[id] = probe
	for field: String in ["resource_statistics", "current_run_statistics", "simulation_statistics"]:
		var measured: ResourceStatistics = StatisticsProbe.new()
		_copy_fields(state.get(field), measured)
		state.set(field, measured)


func _run() -> void:
	var rows: Array[Dictionary] = []
	for scenario: String in ["early", "mid", "forge_competing", "completion_witness"]:
		for kind: String in ["throughput", "native_profile", "detail_profile"]:
			for repeat: int in range(3):
				var state: GameState = _state(scenario)
				state.simulation_statistics = ResourceStatistics.new()
				if kind == "detail_profile":
					_instrument(state)
				var simulation := Simulation.new(state)
				var journal: RefCounted = EventProbe.new()
				journal.attach(simulation)
				simulation.profiling_enabled = kind != "throughput"
				var started: int = Time.get_ticks_usec()
				for tick: int in range(20 if scenario == "completion_witness" else 2000):
					simulation.update(TimeManager.OFFLINE_MAX_GAME_STEP, true)
				var wall_usec: int = Time.get_ticks_usec() - started
				var details: Dictionary = {}
				if kind == "detail_profile":
					for generator: Generator in state.generators.values():
						_merge(details, "generator/", generator.get("measured_usec"), generator.get("measured_calls"))
						for modifier: Modifier in generator.modifiers:
							if modifier.get_script() == ModifierProbe:
								_merge(details, "modifier/", modifier.get("measured_usec"), modifier.get("measured_calls"))
					for item: ResourceStatistics in [state.resource_statistics, state.current_run_statistics, state.simulation_statistics]:
						_merge(details, "statistics/", item.get("measured_usec"), item.get("measured_calls"))
				rows.append({"scenario": scenario, "kind": kind, "repeat": repeat, "ticks": 20 if scenario == "completion_witness" else 2000, "wall_usec": wall_usec, "native_totals": simulation.profile_totals_usec.duplicate(true), "native_calls": simulation.profile_call_counts.duplicate(true), "nested_details": details, "signals": journal.events.size(), "signal_handler_usec": journal.handler_usec, "unprofiled_added_modifiers": _unprofiled(state) if kind == "detail_profile" else 0, "history_usec": state.gameplay_log.measured_usec if kind == "detail_profile" else 0, "history_calls": state.gameplay_log.measured_calls if kind == "detail_profile" else 0})
				# Diagnostics must retain numerical/discrete behavior. Different
				# profile-only object types/timers are intentionally outside this view.
				var control: GameState = _state(scenario)
				control.simulation_statistics = ResourceStatistics.new()
				var exact := Simulation.new(control)
				for tick: int in range(20 if scenario == "completion_witness" else 2000):
					exact.update(TimeManager.OFFLINE_MAX_GAME_STEP, true)
				if Metrics.numeric(state) != Metrics.numeric(control) or Metrics.discrete(state) != Metrics.discrete(control) or state.gameplay_rng.state != control.gameplay_rng.state:
					failures.append("Profiling changed gameplay: " + scenario + "/" + kind)
	var output := FileAccess.open("res://tests/experimental/kernel_profile_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine": Engine.get_version_info(), "cpu": OS.get_processor_name(), "runs": rows, "failures": failures}, "\t") + "\n")
	output.close()
	for failure: String in failures:
		push_error(failure)
	print("KERNEL_PROFILE failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)


func _merge(result: Dictionary, prefix: String, times: Dictionary, calls: Dictionary) -> void:
	for key: String in times:
		var label: String = prefix + key
		if not result.has(label):
			result[label] = {"usec": 0, "calls": 0}
		result[label]["usec"] += times[key]
		result[label]["calls"] += calls[key]


func _state(scenario: String) -> GameState:
	if scenario != "completion_witness":
		return Fixtures.make_state(scenario)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/core_event_fixture.json"))
	return Fixtures.from_save(fixture["before"])


func _unprofiled(state: GameState) -> int:
	var count: int = 0
	for generator: Generator in state.generators.values():
		for modifier: Modifier in generator.modifiers:
			if modifier.get_script() != ModifierProbe:
				count += 1
	return count
