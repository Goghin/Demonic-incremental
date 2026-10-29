extends RefCounted

const Equipment = preload("res://tests/experimental/relic_equipment_fixtures.gd")
const Core = Equipment.Core
const Random = preload("res://Game/gameplay_random.gd")
const ID: String = "relic_shard_extractor"
const DIAGNOSTICS: Array[String] = ["idle", "extraction", "starved", "exact_exhaustion", "forge_standard", "critical_standard", "forge_greater", "critical_greater", "recycle", "combine", "auto_standard", "auto_extraction", "auto_combine", "auto_unfunded", "auto_no_matter", "essence", "nexum", "forge_together", "separate_rng", "full_inventory", "stack_overflow", "speed", "paused", "automation", "late_mixed", "canonical_cycles"]


static func make_state(label: String) -> GameState:
	if label.begins_with("earned_craft_"):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/relic_crafting_progression.json"))
		return Core.from_save(data["snapshots"][label.trim_prefix("earned_craft_")])
	if label not in DIAGNOSTICS:
		return Equipment.make_state(label)
	if label == "canonical_cycles":
		var source: GameState = preload("res://tests/experimental/resource_flow_fixtures.gd").make_state("cycles")
		source.lava_palette = Core.make_state("early").lava_palette.duplicate(true)
		return Core.from_save(SaveManager.new().state_to_dictionary(source))
	# Controlled diagnostics, never earned-progression claims.
	var state: GameState = Equipment.make_state("forge_completion" if label in ["forge_together", "separate_rng"] else ("nexum_relics" if label in ["nexum", "late_mixed"] else "one"))
	var crucible: Generator = state.get_generator(ID)
	var simulation := Simulation.new(state)
	crucible.manually_paused = false
	state.set_resource_amount(ResourceIds.MATTER, 500.0)
	if label == "idle":
		return state
	var mode: String = "normal"
	if label in ["forge_standard", "critical_standard", "auto_standard", "essence", "nexum", "full_inventory", "forge_together", "separate_rng", "speed", "paused", "automation", "late_mixed", "auto_no_matter"]:
		mode = "forge_relic"
	elif label in ["forge_greater", "critical_greater"]:
		mode = "forge_greater_relic"
	elif label in ["combine", "auto_combine"]:
		mode = "combine_shards"
	elif label in ["recycle", "stack_overflow"]:
		mode = "recycle_relic"
	assert(crucible.set_operation_mode(mode))
	if label == "late_mixed":
		state.get_upgrade("infernal_forge_unlock").level = 1
		state.get_upgrade("infernal_forge_fast_mode").level = 1
		simulation.rebuild_upgrade_effects()
		state.set_resource_amount(ResourceIds.HEAT, 5000000.0)
		assert(state.get_generator("infernal_forge").set_operation_mode("fast"))
		assert(simulation.buy_generator("infernal_forge", "crafting_diagnostic"))
	if label == "auto_unfunded":
		assert(crucible.set_operation_mode("forge_relic"))
		enable_auto(state)
		return state
	if mode in ["forge_relic", "combine_shards"]:
		ingredient(state, "relic_shard", 30 if label in ["auto_standard", "auto_combine"] else 10)
	elif mode == "forge_greater_relic":
		ingredient(state, "greater_relic_shard", 5)
	elif mode == "recycle_relic":
		if label == "stack_overflow":
			state.relic_manager.add_stackable_item("relic_shard", 999)
		var id: String = state.relic_manager.add_random_relic_for_tier(1)
		assert(state.relic_manager.move_inventory_entry_to_machine_slot(id, ID, 0))
	if label == "automation":
		state.get_generator("atomic_friction").level = 10
		state.get_upgrade("atomic_friction_optimization").level = 0
		simulation.rebuild_upgrade_effects()
		state.set_resource_amount(ResourceIds.HEAT, 100000.0)
		Equipment.Cycles.Automation.Buyers.enable(state, "atomic_friction")
		Equipment.Cycles.Automation.Buyers.enable(state, "atomic_friction", true)
	if label == "full_inventory":
		for index: int in range(26):
			state.relic_manager.add_random_relic_for_tier(1)
	if label == "separate_rng":
		var separate := RandomNumberGenerator.new()
		separate.seed = 71351
		state.relic_manager._gameplay_rng = separate
	if label == "auto_no_matter":
		state.set_resource_amount(ResourceIds.MATTER, 0.0)
		enable_auto(state)
		return state
	state.gameplay_rng.seed = witness_seed(label.begins_with("critical_"))
	assert(simulation.buy_generator(ID, "crafting_diagnostic"))
	if label in ["auto_standard", "auto_extraction", "auto_combine"]:
		enable_auto(state)
	if label in ["starved", "exact_exhaustion"]:
		for generator: Generator in state.generators.values():
			if not generator.definition.cycle_based:
				generator.manually_paused = true
		state.set_resource_amount(ResourceIds.MATTER, 0.01 if label == "starved" else (100.0 / 60.0) * TimeManager.OFFLINE_MAX_GAME_STEP)
	if label in ["forge_together", "separate_rng"]:
		crucible.cycle_progress = crucible.get_cycle_duration() - 0.000001
	if label == "speed":
		# Numeric native-controller diagnostic; current production has no
		# Crucible equipment slot. This is not an equipped/earned modifier.
		var modifier := Modifier.new(ModifierTypes.CYCLE_SPEED, "", 0.5)
		modifier.id = "diagnostic_live_crafting_speed"
		modifier.dynamic = true
		modifier.dynamic_resource_id = ResourceIds.MATTER
		modifier.dynamic_formula = Modifier.DYNAMIC_RESOURCE_SQRT
		crucible.modifiers.append(modifier)
	if label == "paused":
		crucible.manually_paused = true
	return state


static func ingredient(state: GameState, item: String, quantity: int) -> void:
	state.relic_manager.add_stackable_item(item, quantity)
	for entry: Dictionary in state.relic_manager.inventory:
		if str(entry.get("item_id", "")) == item and int(entry.get("quantity", 0)) >= quantity:
			if state.relic_manager.get_machine_entry_at_slot(ID, 0).get("instance_id", "") != entry["instance_id"]:
				assert(state.relic_manager.move_inventory_entry_to_machine_slot(str(entry["instance_id"]), ID, 0))
			return
	assert(false, "Missing diagnostic ingredient")


static func enable_auto(state: GameState) -> void:
	state.eternal_flame_state.unlock_technology(EternalFlameState.get_cycle_auto_run_technology_id(ID))
	state.get_generator(ID).auto_run_cycles = true


static func witness_seed(critical: bool) -> int:
	for seed_value: int in range(10000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		if (Random.sample_unit(rng) < 0.05) == critical:
			return seed_value
	return -1
