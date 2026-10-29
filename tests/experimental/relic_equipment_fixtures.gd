extends RefCounted

const Resources = preload("res://tests/experimental/essence_nexum_fixtures.gd")
const Cycles = preload("res://tests/experimental/cycle_kernel_fixtures.gd")
const Core = preload("res://tests/experimental/core_fixtures.gd")
const Generation = preload("res://Game/relic_generation_manager.gd")
const DIAGNOSTICS: Array[String] = ["passive", "one", "multiple", "stacked", "secondary", "universal", "specific", "input_compressor", "sensitivity", "essence_relics", "nexum_relics", "expansion_relics", "forge_critical", "forge_speed", "forge_sensitivity", "forge_completion", "forge_auto", "relic_heavy", "crafting", "machine_passive"]


static func make_state(label: String) -> GameState:
	if label in ["early", "consumer_50000", "mid", "forge_competing", "earned_essence", "earned_feedback"]:
		return Resources.make_state(label)
	if label.begins_with("reached_"):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/relic_equipment_progression.json"))
		return Core.from_save(data["snapshots"][label.trim_prefix("reached_")])
	# Controlled diagnostics. Slot/stock/level grants are never earned evidence.
	var is_forge: bool = label.begins_with("forge_")
	var state: GameState = Cycles.make_state("real_completion") if is_forge else Resources.make_state("essence_feedback" if label in ["one", "stacked", "sensitivity", "universal", "specific"] or label.begins_with("effect/") else "mixed_resources")
	state.gameplay_rng.seed = 821775
	unlock_slots(state)
	if is_forge:
		var forge: Generator = state.get_generator("infernal_forge")
		forge.cycle_active = false
		forge.operating = false
		state.get_upgrade("infernal_forge_fast_mode").level = 1
		state.get_upgrade("infernal_forge_critical_chance").level = 5
		state.get_upgrade("infernal_forge_critical_production").level = 2
		Simulation.new(state).rebuild_upgrade_effects()
		state.set_resource_amount(ResourceIds.HEAT, 100000000.0)
		state.set_resource_amount(ResourceIds.MATTER, 600.0)
		state.set_resource_amount(ResourceIds.ASH, 10.0)
		forge.set_operation_mode("fast")
		put(state, forge.definition.id, "ash_contamination_sensitivity_reduction" if label == "forge_sensitivity" else ("cycle_speed_increase" if label in ["forge_speed", "forge_auto"] else "critical_chance"), 3)
		put(state, "atomic_friction", "heat_reservoir_boost", 2)
		assert(Simulation.new(state).buy_generator(forge.definition.id, "relic_diagnostic"))
		if label in ["forge_critical", "forge_completion"]:
			forge.cycle_progress = forge.get_cycle_duration() - 0.000001
		if label == "forge_auto":
			Cycles.enable_auto(state)
			# Stress actual formulas, including leak/decay/CF feedback. Huge
			# source levels are explicit diagnostics; no rates/thresholds edited.
			state.get_generator("atomic_friction").level = 100000000000000000
			state.get_generator("atomic_friction").manually_paused = false
			state.get_generator("thermal_furnace").level = 1000
			state.get_generator("thermal_furnace").manually_paused = false
			state.get_generator("lava_mite_colony").level = 100000
			state.get_generator("lava_mite_colony").manually_paused = false
		return state
	if label.begins_with("effect/"):
		if label == "effect/crystallization_sensitivity_reduction":
			state.get_upgrade("infernal_forge_unlock").level = 1
			state.set_resource_amount(ResourceIds.CRYSTALLIZED_FLAME, 10.0)
			Simulation.new(state).rebuild_upgrade_effects()
		if label == "effect/matter_reservoir_boost":
			put(state, "thermal_furnace", "matter_reservoir_boost", 3)
			return state
		put(state, "atomic_friction", label.trim_prefix("effect/"), 3)
		put(state, "lava_mite_colony", label.trim_prefix("effect/"), 2)
		return state
	match label:
		"passive": state.relic_manager.add_random_relic_for_tier(3)
		"one": put(state, "atomic_friction", "heat_reservoir_boost", 1)
		"multiple":
			put(state, "atomic_friction", "output_increase", 3)
			put(state, "molecular_agitation", "heat_reservoir_boost", 2)
			put(state, "lava_mite_colony", "input_draw_reduction", 2)
		"secondary": put(state, "atomic_friction", "output_increase", 3)
		"stacked":
			var selected: String = ""
			for attempt: int in range(256):
				var id: String = state.relic_manager.add_random_relic_for_tier(3, 0.0, "output_increase")
				var entry: Dictionary = state.relic_manager.get_relic(id)
				var stats: Array = [entry["generated_definition"], entry.get("secondary_stat", {})] + entry.get("additional_secondary_stats", [])
				var matching: int = 0
				for stat: Dictionary in stats:
					if str(stat.get("modifier_type", "")) == ModifierTypes.PRODUCTION and str(stat.get("target_id", "")) in ["", ResourceIds.HEAT]:
						matching += 1
				if matching >= 2:
					selected = id
					break
			assert(not selected.is_empty())
			assert(state.relic_manager.equip_relic("atomic_friction", selected, state))
			state.rebuild_relic_modifiers()
		"relic_heavy":
			for generator: Generator in state.generators.values():
				if state.eternal_flame_upgrade_manager.get_relic_slot_count(generator.definition.id, state.eternal_flame_state) > 0:
					put(state, generator.definition.id, "output_decrease", 3)
		"universal":
			put(state, "atomic_friction", "output_increase", 2, 0, "")
			put(state, "lava_mite_colony", "input_draw_reduction", 2, 0, "")
		"specific":
			put(state, "atomic_friction", "output_increase", 2, 0, ResourceIds.HEAT)
			put(state, "thermal_furnace", "output_decrease", 2, 0, ResourceIds.MATTER)
			put(state, "lava_mite_colony", "input_draw_increase", 2, 0, ResourceIds.ASH)
		"input_compressor": put(state, "thermal_compressor", "input_draw_reduction", 3, 0, "")
		"sensitivity":
			put(state, "atomic_friction", "thermic_mass_sensitivity_increase", 3)
			put(state, "lava_mite_colony", "ash_contamination_sensitivity_reduction", 2)
		"essence_relics":
			put(state, "lava_mite_colony", "input_draw_reduction", 3)
			put(state, "molecular_agitation", "output_increase", 2)
			put(state, "atomic_friction", "output_decrease", 3)
		"nexum_relics", "expansion_relics":
			put(state, "thermal_compressor", "output_increase", 3)
			put(state, "lava_mite_colony", "input_draw_reduction", 3)
			if label == "expansion_relics":
				state.get_generator("thermal_compressor").set_operation_mode("expansion")
		"machine_passive":
			var id: String = state.relic_manager.add_random_relic_for_tier(2)
			assert(state.relic_manager.move_inventory_entry_to_machine_slot(id, "relic_shard_extractor", 0))
		"crafting":
			state.relic_manager.add_stackable_item("relic_shard", 10)
			var entry: Dictionary = state.relic_manager.inventory[-1]
			var crucible: Generator = state.get_generator("relic_shard_extractor")
			crucible.manually_paused = false
			assert(crucible.set_operation_mode("forge_relic"))
			assert(state.relic_manager.move_inventory_entry_to_machine_slot(str(entry["instance_id"]), crucible.definition.id, 0))
			assert(Simulation.new(state).buy_generator(crucible.definition.id, "relic_diagnostic"))
			crucible.cycle_progress = crucible.get_cycle_duration() - 0.000001
	return state


static func unlock_slots(state: GameState) -> void:
	# Diagnostic capacities use the native data-driven permanent slot API.
	for upgrade: EternalFlameUpgrade in state.eternal_flame_upgrade_manager.upgrades.values():
		if upgrade.effect_type in [EternalFlameUpgrade.EFFECT_UNLOCK_RELIQUARY, EternalFlameUpgrade.EFFECT_UNLOCK_RELIC_SLOTS]:
			state.eternal_flame_state.set_upgrade_level(upgrade.id, upgrade.max_level)
	state.rebuild_realm_effects()


static func put(state: GameState, holder: String, effect: String, tier: int, slot: int = 0, target: String = "__any") -> String:
	var id: String = ""
	for attempt: int in range(256):
		id = state.relic_manager.add_random_relic_for_tier(tier, 0.0, effect)
		assert(not id.is_empty())
		if target == "__any" or str(state.relic_manager.get_relic_definition(state.relic_manager.get_relic(id)).get("target_id", "")) == target:
			break
		id = ""
	assert(not id.is_empty())
	assert(state.relic_manager.equip_relic(holder, id, state, slot))
	state.rebuild_relic_modifiers()
	return id
