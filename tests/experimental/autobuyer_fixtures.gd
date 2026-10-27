extends RefCounted

const SCENARIOS: Array[String] = ["early", "competing", "unlock", "upgrades", "technology_locked", "middle", "consumption", "oscillation", "all_wait", "mixed", "late_wait", "late_upgrade", "late_both", "late_dynamic", "late_all_wait", "late_heat_wait"]

const Existing = preload("res://tests/experimental/horizon_fixtures.gd")

class TickLog extends RefCounted:
	var events: Array[Dictionary] = []
	var clock: Callable
	func record_event(category: String, event: String, details: Dictionary = {}, source: String = "game") -> void:
		events.append({"category": category, "event": event, "details": details.duplicate(true),
			"source": source, "tick": roundi(float(clock.call()) / TimeManager.OFFLINE_MAX_GAME_STEP) if clock.is_valid() else 0})


static func enable(state: GameState, id: String, upgrades: bool = false) -> void:
	var manager = state.upgrade_automation_manager if upgrades else state.generator_automation_manager
	state.eternal_flame_state.unlock_technology(manager.get_automation_technology_id(id))
	manager.set_enabled(id, true)


static func make_state(scenario: String) -> GameState:
	var state: GameState
	if scenario in ["late_wait", "late_upgrade", "late_both", "late_dynamic", "late_all_wait", "late_heat_wait"]:
		state = Existing.make_state("feedback")
		var furnace: Generator = state.get_generator("matter_furnace")
		furnace.unlocked = true
		furnace.set_operation_mode("ash_production")
		state.set_resource_amount(ResourceIds.MATTER, furnace.get_cost(state) * 0.5)
		if scenario != "late_upgrade":
			enable(state, furnace.definition.id)
		if scenario in ["late_upgrade", "late_both"]:
			enable(state, furnace.definition.id, true)
		if scenario == "late_heat_wait":
			var source: Generator = state.get_generator("atomic_friction")
			source.level = 50
			state.set_resource_amount(ResourceIds.HEAT, source.get_cost(state) * 0.5)
			enable(state, source.definition.id)
			enable(state, furnace.definition.id, true)
		if scenario == "late_all_wait":
			var source: Generator = state.get_generator("atomic_friction")
			source.level = 30
			source.manually_paused = true
			state.set_resource_amount(ResourceIds.HEAT, source.get_cost(state) * 0.5)
			enable(state, source.definition.id)
		if scenario == "late_dynamic":
			var modifier := Modifier.new(ModifierTypes.COST, furnace.definition.cost_resource_id, 1.0)
			modifier.dynamic = true
			modifier.dynamic_resource_id = ResourceIds.HEAT
			modifier.dynamic_formula = Modifier.DYNAMIC_RESOURCE_LOG10
			furnace.modifiers.append(modifier)
	elif scenario == "mixed":
		state = Existing.make_state("mixed")
	elif scenario in ["middle", "consumption", "oscillation"]:
		state = Existing.make_state("automation")
		if scenario != "middle":
			for id in UpgradeAutomationManager.AUTOMATABLE_GENERATOR_IDS:
				enable(state, id, true)
		if scenario == "consumption":
			# A deliberately well-funded validation realm, not a timing fixture.
			# Existing configuration/formulas and actual upgrade costs are reused.
			state.realm_configuration.stability = 1000000000000
			state.realm_configuration.density = 1000000000000
			state.rebuild_realm_effects()
			state.get_generator("matter_furnace").level = 5
			var simulation := Simulation.new(state)
			state.set_resource_amount(ResourceIds.HEAT, simulation.get_upgrade_cost(state.get_upgrade("thermal_conversion")) * 4.0)
		if scenario == "oscillation":
			var generator: Generator = state.get_generator("atomic_friction")
			state.set_resource_amount(ResourceIds.HEAT, generator.get_cost(state) * 1.001)
	elif scenario == "all_wait":
		state = Existing.make_state("automation")
		for generator in state.generators.values():
			generator.manually_paused = true
		state.set_resource_amount(ResourceIds.HEAT, 0.0)
		state.set_resource_amount(ResourceIds.MATTER, 0.0)
	else:
		state = Existing.make_state("early")
		enable(state, "atomic_friction")
		if scenario == "competing":
			state.get_generator("molecular_agitation").unlocked = true
			enable(state, "molecular_agitation")
			state.set_resource_amount(ResourceIds.HEAT, 1000.0)
		elif scenario == "unlock":
			enable(state, "molecular_agitation")
			var generator: Generator = state.get_generator("atomic_friction")
			generator.level = 24
			state.set_resource_amount(ResourceIds.HEAT, generator.get_cost(state) * 0.99)
		elif scenario == "upgrades":
			enable(state, "atomic_friction", true)
			state.set_resource_amount(ResourceIds.HEAT, 10000.0)
		elif scenario == "technology_locked":
			state.eternal_flame_state.unlocked_technologies.erase(state.generator_automation_manager.get_automation_technology_id("atomic_friction"))
	state.gameplay_log = TickLog.new()
	return state
