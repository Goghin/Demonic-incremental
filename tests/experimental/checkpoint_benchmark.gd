extends SceneTree

const Fixtures = preload("res://tests/experimental/core_fixtures.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const Reference = preload("res://tests/experimental/transaction_checkpoint.gd")
var implementation: Script = Reference
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _context(scenario: String) -> Dictionary:
	var simulation := Simulation.new(Fixtures.make_state(scenario))
	simulation.state.simulation_statistics = ResourceStatistics.new()
	var journal: RefCounted = Events.new()
	journal.attach(simulation)
	return {"simulation": simulation, "journal": journal}


func _run() -> void:
	var kind: String = "reference"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--kind="):
			kind = argument.trim_prefix("--kind=")
	if kind != "reference":
		implementation = load("res://tests/experimental/compact_checkpoint.gd")
	var rows: Array[Dictionary] = []
	var profiles: Array[Dictionary] = []
	for scenario: String in ["early", "mid", "forge_competing"]:
		for repeat: int in range(8):
			rows.append(_measure(scenario, repeat))
		profiles.append(_profile(scenario))
	profiles.append(_profile("forge_competing", true))
	var result: Dictionary = {"kind": kind, "engine": Engine.get_version_info(), "platform": OS.get_name(), "cpu": OS.get_processor_name(), "debug_build": OS.is_debug_build(), "runs": rows, "profiles": profiles, "failures": failures}
	var output := FileAccess.open("res://tests/experimental/checkpoint_" + kind + "_measurements.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t") + "\n")
	output.close()
	for failure: String in failures:
		push_error(failure)
	print("CHECKPOINT_BENCHMARK " + kind + " failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)


func _measure(scenario: String, repeat: int) -> Dictionary:
	var context: Dictionary = _context(scenario)
	var simulation: Simulation = context["simulation"]
	var journal: RefCounted = context["journal"]
	var memory_before: int = OS.get_static_memory_usage()
	var started: int = Time.get_ticks_usec()
	var checkpoint: RefCounted = implementation.new()
	if not checkpoint.capture(simulation, journal):
		failures.append(checkpoint.error)
	var capture_usec: int = Time.get_ticks_usec() - started
	var bytes: int = OS.get_static_memory_usage() - memory_before
	var ticks: int = 600 if scenario == "mid" else 100
	started = Time.get_ticks_usec()
	for tick: int in range(ticks):
		simulation.update(0.1, true)
	var advance_usec: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	checkpoint.restore()
	var restore_usec: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	if not checkpoint.matches():
		failures.append("Restoration mismatch: " + scenario)
	var verify_usec: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	checkpoint = null
	var release_usec: int = Time.get_ticks_usec() - started
	checkpoint = implementation.new()
	if not checkpoint.capture(simulation, journal):
		failures.append(checkpoint.error)
	for tick: int in range(ticks):
		simulation.update(0.1, true)
	started = Time.get_ticks_usec()
	checkpoint = null
	var commit_usec: int = Time.get_ticks_usec() - started
	return {"scenario": scenario, "repeat": repeat, "warmup": repeat == 0, "capture_usec": capture_usec, "heap_delta_bytes": bytes, "advance_usec": advance_usec, "restore_usec": restore_usec, "verify_usec": verify_usec, "release_usec": release_usec, "commit_usec": commit_usec, "rejected_overhead_usec": capture_usec + restore_usec + verify_usec + release_usec}


func _profile(scenario: String, populated_inventory: bool = false) -> Dictionary:
	var context: Dictionary = _context(scenario)
	var simulation: Simulation = context["simulation"]
	var state: GameState = simulation.state
	if populated_inventory:
		state.gameplay_rng.seed = 27481
		for index: int in range(12):
			state.relic_manager.add_random_relic_for_tier(1, 0.25)
	var runtime: Array = []
	var definitions: Array = []
	var phases: Array = []
	var cycles: Array = []
	for generator: Generator in state.generators.values():
		var fields: Dictionary = {}
		for property: Dictionary in generator.get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0 and property["name"] != "definition":
				fields[property["name"]] = generator.get(property["name"])
		runtime.append(fields)
		definitions.append(generator.definition)
		phases.append(generator.production_progress)
		cycles.append([generator.cycle_active, generator.cycle_progress, generator.cycle_critical_chance_snapshot, generator.operation_mode_id, generator.operating, generator.is_throttled, generator.auto_run_cycles])
	var levels: Dictionary = {}
	var metadata: Array = []
	for upgrade: Upgrade in state.upgrades.values():
		levels[upgrade.definition.id] = upgrade.level
		metadata.append(upgrade.definition)
	var roots: Dictionary = {
		"resources": [state.resources, state.discovered_resources, state.resource_thresholds],
		"generator_runtime_with_effects": runtime, "generator_definitions": definitions,
		"output_accumulators": phases, "cycle_runtime": cycles,
		"automation": [state.generator_automation_manager, state.upgrade_automation_manager],
		"upgrade_state_with_definitions": state.upgrades, "upgrade_level_values": levels, "upgrade_definitions_effects": metadata,
		"relic_inventory_equipment": [state.relic_manager.inventory, state.relic_manager.inventory_positions, state.relic_manager.machine_slots, state.relic_manager.equipped],
		"relic_effect_metadata": [state.relic_manager.generation_manager, state.relic_manager.inventory],
		"statistics_history": [state.resource_statistics, state.current_run_statistics, state.simulation_statistics, state.gameplay_log],
		"prestige": [state.eternal_flame_state, state.eternal_flame_upgrade_manager, state.total_overflow_this_prestige, state.total_matter_decayed_this_prestige],
		"rng": state.gameplay_rng, "signals": context["journal"],
		"other_state": [state.realm_configuration, state.realm_effects, state.lava_palette, state.gameplay_interval_produced, state.gameplay_interval_consumed, state.gameplay_interval_lost, state.achievement_manager, state.last_prestige_report]
	}
	var rows: Array[Dictionary] = []
	for category: String in roots:
		for repeat: int in range(5):
			var memory_before: int = OS.get_static_memory_usage()
			var started: int = Time.get_ticks_usec()
			var checkpoint: RefCounted = implementation.new()
			checkpoint.journal = context["journal"]
			if implementation == Reference:
				checkpoint._encode(roots[category])
			else:
				checkpoint._intern(roots[category])
			var elapsed: int = Time.get_ticks_usec() - started
			var bytes: int = OS.get_static_memory_usage() - memory_before
			if not checkpoint.error.is_empty():
				failures.append(category + ": " + checkpoint.error)
			rows.append({"category": category, "repeat": repeat, "capture_usec": elapsed, "heap_delta_bytes": bytes})
			checkpoint = null
	return {"scenario": scenario, "diagnostic_populated_inventory": populated_inventory, "isolated_subgraph_nonadditive": true, "rows": rows}
