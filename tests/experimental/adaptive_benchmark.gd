extends SceneTree

const Adaptive = preload("res://tests/experimental/adaptive_offline.gd")
const Metrics = preload("res://tests/experimental/adaptive_metrics.gd")

class Log extends RefCounted:
	var events: Array[Dictionary] = []
	func record_event(category: String, event: String, details: Dictionary = {}, source: String = "game") -> void:
		events.append({"category": category, "event": event, "details": details.duplicate(true), "source": source})

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var options: Dictionary = {"scenario": "fresh", "duration": "60", "tolerance": "0.0001", "maximum": "60", "absolute": "1e-8", "audit": "60", "mode": "compare", "repeats": "1", "distributed": "true"}
	for argument in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	for repeat_index in range(int(options["repeats"])):
		var result: Dictionary = await measure(options)
		result["repeat"] = repeat_index
		print("ADAPTIVE_JSON " + JSON.stringify(result))
	quit()

static func make_state(scenario: String) -> GameState:
	var state := GameState.new()
	state.gameplay_rng.seed = 123456
	state.gameplay_log = Log.new()
	if scenario == "fresh":
		return state
	if scenario in ["automation", "upgrade_automation", "starved", "cycles", "coupled"]:
		state.set_resource_amount(ResourceIds.HEAT, 200000.0)
		state.set_resource_amount(ResourceIds.MATTER, 2000.0)
		state.set_resource_amount(ResourceIds.ASH, 500.0)
		for g in state.generators.values():
			g.unlocked = true
			if not g.definition.cycle_based:
				g.level = 3
		if scenario in ["automation", "upgrade_automation"]:
			for id in GeneratorAutomationManager.AUTOMATABLE_GENERATOR_IDS:
				var manager = state.generator_automation_manager if scenario == "automation" else state.upgrade_automation_manager
				state.eternal_flame_state.unlock_technology(manager.get_automation_technology_id(id))
				manager.set_enabled(id, true)
		if scenario == "starved":
			for id in state.resources:
				state.set_resource_amount(id, 0.0)
			for g in state.generators.values():
				if g.get_active_inputs().is_empty():
					g.manually_paused = true
		if scenario == "cycles":
			for g in state.generators.values():
				g.manually_paused = not g.definition.cycle_based
			var simulation := Simulation.new(state)
			state.get_upgrade("infernal_forge_unlock").level = 1
			state.get_upgrade("infernal_forge_critical_chance").level = 1
			state.get_upgrade("infernal_forge_recrystallization").level = 1
			simulation.rebuild_upgrade_effects()
			state.realm_effects.matter_decay_threshold = 1e15
			state.realm_effects.heat_leak_threshold = 1e15
			state.set_resource_amount(ResourceIds.MATTER, 1e12)
			state.set_resource_amount(ResourceIds.HEAT, 1e12)
			for id in ["infernal_forge", "relic_shard_extractor"]:
				var g: Generator = state.get_generator(id)
				g.definition.base_cost = 0.0
				g.auto_run_cycles = true
				state.eternal_flame_state.unlock_technology(EternalFlameState.get_cycle_auto_run_technology_id(id))
			var forge: Generator = state.get_generator("infernal_forge")
			forge.operation_mode_id = "fast"
			forge.modifiers.clear()
			forge.invalidate_production_modifier_cache()
			for effect in forge.event_effects:
				effect.event_chance = 0.5
			state.get_generator("relic_shard_extractor").operation_mode_id = "forge_relic"
			state.relic_manager.add_stackable_item("relic_shard", 1000)
			var entry: Dictionary = state.relic_manager.get_inventory_entry_at_slot(0)
			state.relic_manager.move_inventory_entry_to_machine_slot(str(entry["instance_id"]), "relic_shard_extractor", 0)
		return state
	var producer: Generator = state.get_generator("atomic_friction")
	if scenario == "stable":
		# Existing realm formula raises the threshold; no leak-free formula fork.
		state.realm_configuration.stability = 1e20
		state.rebuild_realm_effects()
	elif scenario == "heat":
		state.set_resource_amount(ResourceIds.HEAT, state.realm_effects.heat_leak_threshold + 1.0)
	elif scenario == "matter":
		state.set_resource_amount(ResourceIds.MATTER, state.realm_effects.matter_decay_threshold * 2.0)
		state.set_resource_amount(ResourceIds.HEAT, state.realm_effects.heat_leak_threshold * 1.2)
	elif scenario == "ash":
		state.set_resource_amount(ResourceIds.ASH, 10000.0)
	elif scenario == "essence":
		producer.operation_mode_id = "intensified_friction"
		producer.get_operation_mode().unlocked = true
		producer.level = 1000
		state.set_resource_amount(ResourceIds.ESSENCE, 10000.0)
	elif scenario == "idle":
		for g in state.generators.values():
			g.manually_paused = true
	return state

func measure(options: Dictionary) -> Dictionary:
	var scenario: String = options["scenario"]
	var duration: float = float(options["duration"])
	var adaptive_state: GameState = make_state(scenario)
	var prototype = Adaptive.new(Simulation.new(adaptive_state))
	prototype.maximum_step = float(options["maximum"])
	prototype.minimum_step = float(options.get("minimum", "0.1"))
	prototype.event_safety_margin = float(options.get("margin", "0.1"))
	prototype.fallback_window_ticks = int(options.get("fallback_window", "10"))
	prototype.force_exact = options.get("force_exact", "false") == "true"
	prototype.allow_environmental_feedback = options.get("environment", "true") == "true"
	prototype.relative_tolerance = float(options["tolerance"])
	prototype.absolute_tolerance = float(options["absolute"])
	prototype.audit_interval = float(options["audit"])
	prototype.distribute_error_budget = options["distributed"] == "true"
	var memory_before: int = OS.get_static_memory_usage()
	var start: int = Time.get_ticks_usec()
	var counters: Dictionary = prototype.run(duration)
	var adaptive_seconds: float = float(Time.get_ticks_usec() - start) / 1e6
	var memory_after: int = OS.get_static_memory_usage()
	var reference: GameState = make_state(scenario)
	var simulation := Simulation.new(reference)
	var manager := TimeManager.new(simulation)
	reference.simulation_statistics = manager.simulation_statistics
	var elapsed: float = 0.0
	var max_error: Dictionary = {"resource_abs": 0.0, "resource_rel": 0.0, "statistics_abs": 0.0, "statistics_rel": 0.0, "normalized": 0.0, "worst_key": ""}
	var strict: bool = counters["strict_failure"] == ""
	var rng: bool = true
	var audits: int = 0
	var reference_audit_usec: int = 0
	start = Time.get_ticks_usec()
	var evaluations: int = 0
	for tick in range(ceili(duration / TimeManager.OFFLINE_MAX_GAME_STEP)):
		var delta: float = minf(TimeManager.OFFLINE_MAX_GAME_STEP, duration - elapsed)
		if delta <= 0.0:
			break
		elapsed = minf(duration, elapsed + delta)
		manager.game_time += delta
		manager.offline_time += delta
		manager.prestige_time += delta
		manager.current_offline_duration += delta
		reference.set_lava_mite_dormancy_penalty(manager.get_dormancy_penalty(elapsed))
		simulation.update(delta, true)
		evaluations += 1
		if prototype.samples.has(tick + 1):
			var audit_start: int = Time.get_ticks_usec()
			var sample: Dictionary = prototype.samples[tick + 1]
			var errors: Dictionary = Metrics.compare(Metrics.numeric(reference, manager), sample["numeric"], prototype.absolute_tolerance, prototype.relative_tolerance)
			for key in max_error:
				if key == "worst_key":
					continue
				if float(errors[key]) > float(max_error[key]):
					max_error[key] = errors[key]
			max_error["worst_key"] = errors["worst_key"] if float(errors["normalized"]) >= float(max_error["normalized"]) else max_error["worst_key"]
			strict = strict and Metrics.discrete(reference) == sample["discrete"]
			rng = rng and str(reference.gameplay_rng.state) == sample["rng"]
			audits += 1
			reference_audit_usec += Time.get_ticks_usec() - audit_start
	var reference_wall: float = float(Time.get_ticks_usec() - start) / 1e6
	var reference_seconds: float = reference_wall - float(reference_audit_usec) / 1e6
	var final_error: Dictionary = Metrics.compare(Metrics.numeric(reference, manager), Metrics.numeric(adaptive_state, prototype.manager), prototype.absolute_tolerance, prototype.relative_tolerance)
	strict = strict and Metrics.discrete(reference) == Metrics.discrete(adaptive_state)
	rng = rng and reference.gameplay_rng.state == adaptive_state.gameplay_rng.state
	var result: Dictionary = {"scenario": scenario, "duration": duration, "relative_tolerance": prototype.relative_tolerance,
		"absolute_tolerance": prototype.absolute_tolerance, "maximum_step": prototype.maximum_step,
		"distributed_budget": prototype.distribute_error_budget, "audit_interval": prototype.audit_interval,
		"reference_seconds": reference_seconds, "reference_wall_with_audits": reference_wall, "reference_audit_usec": reference_audit_usec, "adaptive_seconds": adaptive_seconds, "speedup": reference_seconds / maxf(adaptive_seconds, 1e-9),
		"reference_evaluations": evaluations, "adaptive_counters": counters, "maximum_sampled_deviation": max_error,
		"final_deviation": final_error, "audits": audits, "discrete_parity": strict, "rng_parity": rng,
		"accuracy_pass": float(max_error["normalized"]) <= 1.0 and float(final_error["normalized"]) <= 1.0,
		"static_memory_before": memory_before, "static_memory_after": memory_after, "engine_static_peak": OS.get_static_memory_peak_usage(),
		"trace_bytes": var_to_bytes(prototype.samples).size(),
		"sources": {"simulation": String(simulation.get_script().source_code).sha256_text(),
			"time_manager": String(manager.get_script().source_code).sha256_text(),
			"game_state": String(reference.get_script().source_code).sha256_text(),
			"rng": FileAccess.get_file_as_string("res://Game/gameplay_random.gd").sha256_text(),
			"prototype": FileAccess.get_file_as_string("res://tests/experimental/adaptive_offline.gd").sha256_text(),
			"checkpoint": FileAccess.get_file_as_string("res://tests/experimental/continuous_checkpoint.gd").sha256_text(),
			"metrics": FileAccess.get_file_as_string("res://tests/experimental/adaptive_metrics.gd").sha256_text(),
			"fixture": FileAccess.get_file_as_string("res://tests/experimental/adaptive_benchmark.gd").sha256_text()}, "engine": Engine.get_version_info()["string"]}
	if options["mode"] == "manager":
		var managed: GameState = make_state(scenario)
		var managed_time := TimeManager.new(Simulation.new(managed))
		start = Time.get_ticks_usec()
		await managed_time.simulate_offline(duration)
		result["manager_seconds"] = float(Time.get_ticks_usec() - start) / 1e6
		result["manager_yields"] = managed_time.offline_yield_count
		result["manager_steps"] = managed_time.offline_steps_processed
		result["manager_vs_direct"] = Metrics.compare(Metrics.numeric(reference, manager), Metrics.numeric(managed, managed_time), prototype.absolute_tolerance, prototype.relative_tolerance)
		result["manager_discrete_parity"] = Metrics.discrete(reference) == Metrics.discrete(managed)
		result["manager_rng_parity"] = reference.gameplay_rng.state == managed.gameplay_rng.state
	return result
