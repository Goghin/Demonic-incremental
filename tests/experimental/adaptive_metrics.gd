extends RefCounted

# Benchmark-only views. No tolerances are used in the discrete fingerprint.
static func numeric(state: GameState, time_manager: TimeManager = null) -> Dictionary:
	var result: Dictionary = {}
	for id in state.resources:
		result["resource/" + id] = state.get_resource_amount(id)
	for pair in [["lifetime", state.resource_statistics], ["run", state.current_run_statistics], ["offline", state.simulation_statistics]]:
		if pair[1] == null:
			continue
		var stats: ResourceStatistics = pair[1]
		result[pair[0] + "/overflow"] = stats.total_overflow
		result[pair[0] + "/decay"] = stats.total_matter_decayed
		for id in stats.statistics:
			for field in stats.statistics[id]:
				result[pair[0] + "/" + id + "/" + field] = stats.statistics[id][field]
	result["reward/overflow"] = state.total_overflow_this_prestige
	result["reward/decay"] = state.total_matter_decayed_this_prestige
	result["reward/multiplier"] = state.get_combined_environmental_reward_multiplier()
	result["dormancy"] = state.get_lava_mite_dormancy_penalty()
	for id in state.generators:
		result["cycle/" + id] = state.generators[id].cycle_progress
	if time_manager != null:
		for field in ["game_time", "offline_time", "prestige_time", "current_offline_duration"]:
			result["clock/" + field] = time_manager.get(field)
	return result


static func discrete(state: GameState, include_projected_reward: bool = true) -> String:
	var generators: Dictionary = {}
	for id in state.generators:
		var g: Generator = state.generators[id]
		var unlocks: Array[bool] = []
		for mode in g.definition.operation_modes:
			unlocks.append(mode.unlocked)
			for io in mode.inputs + mode.outputs + mode.completion_outputs:
				unlocks.append(io.unlocked)
		generators[id] = [g.level, g.unlocked, g.operating, g.manually_paused, g.is_throttled,
			g.cycle_active, g.operation_mode_id, g.auto_run_cycles, g.production_progress,
			g.cycle_critical_chance_snapshot, unlocks]
	var upgrades: Dictionary = {}
	for id in state.upgrades:
		upgrades[id] = state.upgrades[id].level
	return var_to_bytes([generators, upgrades, state.relic_manager.get_save_data(),
		state.discovered_resources, state.generator_automation_manager.automation_states,
		state.upgrade_automation_manager.automation_states, state.eternal_flame_state.upgrade_levels,
		state.eternal_flame_state.unlocked_technologies, state.eternal_flame_state.prestige_count,
		state.eternal_flame_state.eternal_flame, state.prestige_planning,
		PrestigeSystem.new().calculate_eternal_flame_gain(state) if include_projected_reward else 0.0, state.gameplay_log.events]).hex_encode().sha256_text()


static func compare(reference: Dictionary, candidate: Dictionary, absolute: float, relative: float) -> Dictionary:
	var result: Dictionary = {"resource_abs": 0.0, "resource_rel": 0.0, "statistics_abs": 0.0,
		"statistics_rel": 0.0, "normalized": 0.0, "worst_key": ""}
	var keys: Dictionary = {}
	for key in reference:
		keys[key] = true
	for key in candidate:
		keys[key] = true
	for key in keys:
		var a: float = float(reference.get(key, 0.0))
		var b: float = float(candidate.get(key, 0.0))
		var error: float = absf(a - b) if is_finite(a) and is_finite(b) else INF
		var normalized: float = error / maxf(absolute + relative * absf(a), 1e-30)
		var prefix: String = "resource" if str(key).begins_with("resource/") else "statistics"
		result[prefix + "_abs"] = maxf(result[prefix + "_abs"], error)
		result[prefix + "_rel"] = maxf(result[prefix + "_rel"], error / maxf(absf(a), absolute))
		if normalized > float(result["normalized"]):
			result["normalized"] = normalized
			result["worst_key"] = key
	return result
