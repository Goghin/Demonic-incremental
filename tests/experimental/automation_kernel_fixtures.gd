extends RefCounted

const Consumers = preload("res://tests/experimental/consumer_fixtures.gd")
const Core = preload("res://tests/experimental/core_fixtures.gd")
const Buyers = preload("res://tests/experimental/autobuyer_fixtures.gd")
const DIAGNOSTICS: Array[String] = ["initial", "waiting", "production", "decay", "competition", "registry", "effects", "automatic", "activation", "unsupported", "cost_refresh", "general", "purchase_heavy", "upgrade_initial"]


static func make_state(label: String) -> GameState:
	if label in ["early", "consumer_50000", "mid", "forge_competing"]:
		return Consumers.make_state(label)
	if label.begins_with("reached_"):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/automation_progression.json"))
		return Core.from_save(data["snapshots"][label.trim_prefix("reached_")])
	# Explicit controlled diagnostics, never representative timing evidence.
	var state := GameState.new()
	state.gameplay_log = Buyers.TickLog.new()
	# Constructor palette uses a separate randomized visual RNG. Canonicalize
	# it from an existing save so the complete graph oracle is meaningful.
	state.lava_palette = Core.make_state("early").lava_palette.duplicate(true)
	state.gameplay_rng.seed = 974155
	state.upgrades.clear()
	for generator: Generator in state.generators.values():
		generator.manually_paused = true
		generator.operating = false
	state.realm_effects.heat_leak_threshold = 1000000000.0
	var source: Generator = state.get_generator("atomic_friction")
	source.level = 1
	source.unlocked = true
	state.set_resource_amount(ResourceIds.HEAT, source.get_cost(state) * 100.0)
	if label in ["initial", "waiting", "production", "decay", "competition", "automatic", "activation", "cost_refresh", "purchase_heavy"]:
		Buyers.enable(state, "atomic_friction")
	if label != "initial":
		state.generator_automation_manager.automation_states["atomic_friction"]["remaining_cooldown"] = 0.0
	match label:
		"waiting": state.set_resource_amount(ResourceIds.HEAT, 0.0)
		"production":
			source.manually_paused = false
			var output: GeneratorIO = source.get_active_outputs()[0]
			state.set_resource_amount(ResourceIds.HEAT, source.get_cost(state) - source.get_production_rate(output, state) * 0.05)
		"decay":
			state.set_resource_amount(ResourceIds.HEAT, 0.0)
			state.set_resource_amount(ResourceIds.MATTER, 100000.0)
		"competition":
			state.get_generator("molecular_agitation").unlocked = true
			Buyers.enable(state, "molecular_agitation")
			state.generator_automation_manager.automation_states["molecular_agitation"]["remaining_cooldown"] = 0.0
			Buyers.enable(state, "atomic_friction", true)
			state.upgrade_automation_manager.automation_states["atomic_friction"]["remaining_cooldown"] = 0.0
			add_upgrade(state, "after_generator", "atomic_friction", source.get_cost(state))
			state.set_resource_amount(ResourceIds.HEAT, source.get_cost(state))
		"registry":
			state.get_generator("molecular_agitation").unlocked = true
			add_upgrade(state, "ma_first_in_registry", "molecular_agitation", 10.0)
			add_upgrade(state, "af_first", "atomic_friction", 10.0)
			add_upgrade(state, "af_second", "atomic_friction", 10.0, [Requirement.new(RequirementTypes.UPGRADE_PURCHASED, "af_first", 1)])
			for id: String in ["atomic_friction", "molecular_agitation"]:
				Buyers.enable(state, id, true)
				state.upgrade_automation_manager.automation_states[id]["remaining_cooldown"] = 0.0
			state.set_resource_amount(ResourceIds.HEAT, 10.0)
		"effects":
			source.manually_paused = false
			add_upgrade(state, "heat_threshold_line_1", "atomic_friction", 1.0, [], [UpgradeEffect.modifier("atomic_friction", ModifierTypes.PRODUCTION, 1.5, ResourceIds.HEAT), UpgradeEffect.sensitivity("atomic_friction", "diagnostic", 0.75)], 4)
			Buyers.enable(state, "atomic_friction", true)
			state.upgrade_automation_manager.automation_states["atomic_friction"]["remaining_cooldown"] = 0.0
		"automatic":
			source.manually_paused = false
			source.level = 24
			state.set_resource_amount(ResourceIds.HEAT, source.get_cost(state) * 2.0)
			var upgrade: Upgrade = add_upgrade(state, "next_tick_unlock", "", 0.0, [Requirement.new(RequirementTypes.GENERATOR_LEVEL, "atomic_friction", 25)], [UpgradeEffect.unlock_generator("molecular_agitation"), UpgradeEffect.modifier("atomic_friction", ModifierTypes.PRODUCTION, 2.0, ResourceIds.HEAT)])
			upgrade.definition.automatic = true
		"activation": source.get_operation_mode().increase_level_on_activation = false
		"upgrade_initial":
			add_upgrade(state, "initial_upgrade", "atomic_friction", 1.0, [], [], 3)
			Buyers.enable(state, "atomic_friction", true)
		"cost_refresh":
			state.set_resource_amount(ResourceIds.HEAT, source.get_cost(state) * 0.75)
			add_upgrade(state, "cheaper_next_tick", "atomic_friction", 0.0, [], [UpgradeEffect.modifier("atomic_friction", ModifierTypes.COST, 0.5, ResourceIds.HEAT)])
			Buyers.enable(state, "atomic_friction", true)
			state.upgrade_automation_manager.automation_states["atomic_friction"]["remaining_cooldown"] = 0.0
		"general":
			var automatic: Upgrade = add_upgrade(state, "automatic_global", "", 0.0)
			automatic.definition.automatic = true
			var excluded: Upgrade = add_upgrade(state, "excluded_strip", "", 1.0)
			excluded.definition.upgrade_group_id = "infernal_forge"
			add_upgrade(state, "general_paid", "", 1.0)
			Buyers.enable(state, "general", true)
			state.upgrade_automation_manager.automation_states["general"]["remaining_cooldown"] = 0.0
		"purchase_heavy":
			# Deliberately funded stress only, at the actual configured maximum
			# permanent cooldown upgrade. Production costs/formulas unchanged.
			var id: String = state.generator_automation_manager.get_cooldown_upgrade_id("atomic_friction")
			state.eternal_flame_state.set_upgrade_level(id, state.eternal_flame_upgrade_manager.get_upgrade(id).max_level)
			state.set_resource_amount(ResourceIds.HEAT, 1e200)
			state.realm_effects.heat_leak_threshold = 1e250
		"unsupported":
			source.manually_paused = false
			source.get_operation_mode().outputs.append(GeneratorIO.new(ResourceIds.ESSENCE, 0.001, false, false))
			add_upgrade(state, "unlock_unsupported", "atomic_friction", 1.0, [], [UpgradeEffect.unlock_output("atomic_friction", ResourceIds.ESSENCE)])
			Buyers.enable(state, "atomic_friction", true)
			state.upgrade_automation_manager.automation_states["atomic_friction"]["remaining_cooldown"] = 0.0
	return state


static func add_upgrade(state: GameState, id: String, tree: String, cost: float, requirements: Array[Requirement] = [], effects: Array[UpgradeEffect] = [], maximum: int = 1) -> Upgrade:
	var definition := UpgradeDefinition.new(id, id, "Controlled automation ordering probe", ResourceIds.HEAT, cost, effects, requirements, false, "", tree, maximum, 1.0, tree)
	var upgrade := Upgrade.new(definition)
	state.upgrades[id] = upgrade
	return upgrade
