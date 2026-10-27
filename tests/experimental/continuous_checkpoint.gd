extends RefCounted

# ONLY valid after the prototype's event/input/automation guards pass. This is
# not a general GameState clone or save/resume implementation. Direct writes
# restore statistics without invoking setters that would record extra peaks.
static func capture(simulation: Simulation) -> Dictionary:
	var state: GameState = simulation.state
	var amounts: Dictionary = {}
	var flags: Dictionary = {}
	for id in state.resources:
		amounts[id] = state.get_resource_amount(id)
	for id in state.generators:
		var g: Generator = state.generators[id]
		flags[id] = [g.operating, g.is_throttled]
	var stats: Array = []
	for item in [state.resource_statistics, state.current_run_statistics, state.simulation_statistics]:
		stats.append([item.statistics.duplicate(true), item.total_overflow, item.total_matter_decayed] if item != null else [])
	return {"amounts": amounts, "flags": flags, "stats": stats,
		"discovered": state.discovered_resources.duplicate(true),
		"overflow": state.total_overflow_this_prestige, "decay": state.total_matter_decayed_this_prestige,
		"dormancy": state.lava_mite_dormancy_penalty, "track": state.track_gameplay_interval_statistics,
		"interval": [state.gameplay_interval_produced.duplicate(true), state.gameplay_interval_consumed.duplicate(true), state.gameplay_interval_lost.duplicate(true)],
		"sim": [simulation._gameplay_snapshot_elapsed, simulation._gameplay_was_offline, simulation._gameplay_snapshot_realm_run_index]}


static func restore(simulation: Simulation, checkpoint: Dictionary) -> void:
	var state: GameState = simulation.state
	for id in checkpoint["amounts"]:
		state.resources[id].amount = checkpoint["amounts"][id]
	for id in checkpoint["flags"]:
		state.generators[id].operating = checkpoint["flags"][id][0]
		state.generators[id].is_throttled = checkpoint["flags"][id][1]
	var objects: Array = [state.resource_statistics, state.current_run_statistics, state.simulation_statistics]
	for index in range(objects.size()):
		if objects[index] != null:
			objects[index].statistics = checkpoint["stats"][index][0].duplicate(true)
			objects[index].total_overflow = checkpoint["stats"][index][1]
			objects[index].total_matter_decayed = checkpoint["stats"][index][2]
	state.discovered_resources = checkpoint["discovered"].duplicate(true)
	state.total_overflow_this_prestige = checkpoint["overflow"]
	state.total_matter_decayed_this_prestige = checkpoint["decay"]
	state.lava_mite_dormancy_penalty = checkpoint["dormancy"]
	state.track_gameplay_interval_statistics = checkpoint["track"]
	state.gameplay_interval_produced = checkpoint["interval"][0].duplicate(true)
	state.gameplay_interval_consumed = checkpoint["interval"][1].duplicate(true)
	state.gameplay_interval_lost = checkpoint["interval"][2].duplicate(true)
	simulation._gameplay_snapshot_elapsed = checkpoint["sim"][0]
	simulation._gameplay_was_offline = checkpoint["sim"][1]
	simulation._gameplay_snapshot_realm_run_index = checkpoint["sim"][2]
