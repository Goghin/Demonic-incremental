extends "res://simulation/offline_simulation_benchmark.gd"


class TraceLog extends RefCounted:
	var events: Array[Dictionary] = []
	var elapsed: float = 0.0
	var manager: WeakRef

	func record_event(category: String, event: String, details: Dictionary = {}, source: String = "game") -> void:
		var time: float = elapsed
		if manager != null:
			time = manager.get_ref().current_offline_duration
		events.append({"time": time, "category": category, "event": event, "details": details.duplicate(true), "source": source})


func _run_benchmarks() -> void:
	var options: Dictionary = {"duration": "3600", "mode": "direct", "scenario": "stress", "repeats": "1", "profile": "false"}
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			options[parts[0]] = parts[1]
	for repeat_index in range(int(options["repeats"])):
		var result: Dictionary = await _measure(float(options["duration"]), str(options["mode"]), str(options["scenario"]), options["profile"] == "true")
		result["repeat"] = repeat_index
		print("PERFORMANCE_JSON " + JSON.stringify(result))
	quit()


func _measure(duration: float, mode: String, scenario: String, profile: bool) -> Dictionary:
	seed(123456)
	var state := GameState.new()
	_configure_test_state(state)
	var logger := TraceLog.new()
	state.gameplay_log = logger
	if scenario == "feedback":
		state.realm_configuration.stability = 0
		state.realm_configuration.integrity = 0
		state.realm_configuration.intensity = 0
		state.realm_configuration.density = 0
		state.rebuild_realm_effects()
		state.set_resource_amount(ResourceIds.HEAT, 2000.0)
		state.set_resource_amount(ResourceIds.MATTER, 200.0)
		state.set_resource_amount(ResourceIds.ASH, 20.0)
	elif scenario == "cycles":
		# Isolate affordable repeated cycles from resource starvation.
		for generator in state.generators.values():
			generator.manually_paused = not generator.definition.cycle_based
		state.realm_effects.matter_decay_threshold = 1e15
		state.realm_effects.heat_leak_threshold = 1e15
		state.set_resource_amount(ResourceIds.MATTER, 1e12)
		state.set_resource_amount(ResourceIds.HEAT, 1e12)
		for id in ["infernal_forge", "relic_shard_extractor"]:
			var generator: Generator = state.get_generator(id)
			generator.auto_run_cycles = true
			state.eternal_flame_state.unlock_technology(EternalFlameState.get_cycle_auto_run_technology_id(id))
		# Fast mode has no Heat input, so completion Heat resets do not starve it.
		var forge: Generator = state.get_generator("infernal_forge")
		forge.operation_mode_id = "fast"
		forge.get_operation_mode().unlocked = true
		state.get_upgrade("infernal_forge_unlock").level = 1
	var simulation := Simulation.new(state)
	if scenario == "critical_cycles":
		for generator in state.generators.values():
			generator.manually_paused = not generator.definition.cycle_based
		state.set_resource_amount(ResourceIds.MATTER, 1e12)
		state.set_resource_amount(ResourceIds.HEAT, 1e12)
		state.get_upgrade("infernal_forge_unlock").level = 1
		state.get_upgrade("infernal_forge_critical_chance").level = 1
		state.get_upgrade("infernal_forge_recrystallization").level = 1
		state.get_upgrade("infernal_forge_critical_production").level = 1
		simulation.rebuild_upgrade_effects()
		simulation.update_automatic_upgrades()
		state.realm_effects.matter_decay_threshold = 1e15
		state.realm_effects.heat_leak_threshold = 1e15
		for id in ["infernal_forge", "relic_shard_extractor"]:
			var generator: Generator = state.get_generator(id)
			generator.auto_run_cycles = true
			generator.definition.base_cost = 0.0
			state.eternal_flame_state.unlock_technology(EternalFlameState.get_cycle_auto_run_technology_id(id))
		var forge: Generator = state.get_generator("infernal_forge")
		forge.operation_mode_id = "fast"
		for effect in forge.event_effects:
			effect.event_chance = 0.5
		# Keep the existing formulas, but isolate cycle RNG from Ash starvation.
		forge.modifiers.clear()
		forge.invalidate_production_modifier_cache()
		var crucible: Generator = state.get_generator("relic_shard_extractor")
		crucible.operation_mode_id = "forge_relic"
		state.relic_manager.add_stackable_item("relic_shard", 1000)
		var entry: Dictionary = state.relic_manager.get_inventory_entry_at_slot(0)
		state.relic_manager.move_inventory_entry_to_machine_slot(str(entry["instance_id"]), "relic_shard_extractor", 0)
	simulation.profiling_enabled = profile
	simulation.diagnostics_enabled = true
	var manager := TimeManager.new(simulation)
	state.simulation_statistics = manager.simulation_statistics
	var updates: int = 0
	var progress_updates: int = 0
	var start_usec: int = Time.get_ticks_usec()
	if mode == "manager":
		logger.manager = weakref(manager)
		var progress_counter: Array[int] = [0]
		manager.offline_simulation_progress.connect(func(_current: int, _total: int) -> void: progress_counter[0] += 1)
		await manager.simulate_offline(duration)
		progress_updates = progress_counter[0]
		updates = manager.simulation_tick
	else:
		var elapsed: float = 0.0
		for _index in range(ceili(duration / BASELINE_STEP)):
			var delta: float = minf(BASELINE_STEP, duration - elapsed)
			if delta <= 0.0:
				break
			state.set_lava_mite_dormancy_penalty(manager.get_dormancy_penalty(elapsed + delta))
			logger.elapsed = elapsed + delta
			simulation.diagnostic_time_seconds = elapsed + delta
			simulation.update(delta, mode != "normal")
			elapsed = minf(duration, elapsed + delta)
			updates += 1
	var wall_seconds: float = float(Time.get_ticks_usec() - start_usec) / 1000000.0
	var generators: Dictionary = _snapshot_generators(state)
	for id in generators:
		var generator: Generator = state.get_generator(id)
		generators[id]["production_progress"] = generator.production_progress.duplicate(true)
		generators[id]["throttled"] = generator.is_throttled
		generators[id]["mode"] = generator.operation_mode_id
		generators[id]["critical_snapshot"] = generator.cycle_critical_chance_snapshot
	var upgrades: Dictionary = {}
	for id in state.upgrades:
		upgrades[id] = state.upgrades[id].level
	var rng_tail: Array[int] = []
	for _index in range(4):
		rng_tail.append(randi())
	var generator_automation: Dictionary = state.generator_automation_manager.automation_states.duplicate(true)
	# Internal cost-cache metadata is implementation detail; retain behavior state.
	for automation in generator_automation.values():
		for key in automation.keys():
			if str(key).begins_with("waiting_") and key != "waiting_for_resources":
				automation.erase(key)
	var source_hashes: Dictionary = {
		"simulation": String(simulation.get_script().source_code).sha256_text(),
		"generator": String(state.generators.values()[0].get_script().source_code).sha256_text(),
		"time_manager": String(manager.get_script().source_code).sha256_text()
	}
	var result: Dictionary = {"source_sha256": source_hashes,
		"seconds": wall_seconds, "duration": duration, "mode": mode, "scenario": scenario,
		"updates": updates, "progress_updates": progress_updates, "profile": simulation.get_profile_report(),
		"snapshot": {"resources": _snapshot_resources(state), "generators": generators, "upgrades": upgrades,
			"statistics": manager.simulation_statistics.to_dictionary(), "lifetime_statistics": state.resource_statistics.to_dictionary(),
			"run_statistics": state.current_run_statistics.to_dictionary(), "overflow": state.total_overflow_this_prestige,
			"matter_decayed": state.total_matter_decayed_this_prestige, "inventory": state.relic_manager.get_save_data(),
			"discoveries": state.get_discovered_resources_save_data(), "dormancy": state.get_lava_mite_dormancy_penalty(),
			"generator_automation": generator_automation, "upgrade_automation": state.upgrade_automation_manager.automation_states.duplicate(true),
			"events": logger.events.duplicate(true), "rng_tail": rng_tail}
	}
	if mode == "manager":
		result["clocks"] = {"game": manager.game_time, "offline": manager.offline_time, "prestige": manager.prestige_time, "duration": manager.current_offline_duration}
	# Hash Variant encoding as well as JSON: this retains every double's bits.
	result["snapshot_binary_sha256"] = var_to_bytes(result["snapshot"]).hex_encode().sha256_text()
	if result.has("clocks"):
		result["clocks_binary_sha256"] = var_to_bytes(result["clocks"]).hex_encode().sha256_text()
	state.simulation_statistics = null
	return result
