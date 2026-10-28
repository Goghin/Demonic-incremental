extends RefCounted

const Metrics = preload("res://tests/experimental/adaptive_metrics.gd")


static func capture(simulation: Simulation, journal: RefCounted = null, include_configuration: bool = false) -> PackedByteArray:
	var state: GameState = simulation.state
	var caches: Dictionary = {}
	for id: String in state.generators:
		var generator: Generator = state.generators[id]
		var entries: Dictionary = {}
		for resource_id: String in generator._production_modifier_cache:
			var indexes: Array[int] = []
			for modifier: Modifier in generator._production_modifier_cache[resource_id]:
				indexes.append(generator.modifiers.find(modifier))
			entries[resource_id] = indexes
		caches[id] = entries
	var configuration: Dictionary = {}
	if include_configuration:
		for id: String in state.generators:
			var generator: Generator = state.generators[id]
			configuration[id] = [_objects(generator.modifiers), _objects(generator.modifier_sensitivities), _objects(generator.event_effects)]
	return var_to_bytes([Metrics.numeric(state), Metrics.discrete(state), state.gameplay_rng.seed, state.gameplay_rng.state, caches, state.track_gameplay_interval_statistics, state.gameplay_interval_produced, state.gameplay_interval_consumed, state.gameplay_interval_lost, simulation._gameplay_snapshot_elapsed, simulation._gameplay_was_offline, simulation._gameplay_snapshot_realm_run_index, simulation._offline_upgrade_count, simulation._offline_realm_run_index, state.generator_automation_manager._offline_enabled_ids, state.generator_automation_manager._offline_index_dirty, state.upgrade_automation_manager._offline_enabled_ids, state.upgrade_automation_manager._offline_index_dirty, journal.events if journal != null else [], configuration])


static func _objects(objects: Array) -> Array:
	var result: Array = []
	for object: Object in objects:
		var fields: Dictionary = {}
		for property: Dictionary in object.get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
				fields[property["name"]] = object.get(property["name"])
		result.append(fields)
	return result
