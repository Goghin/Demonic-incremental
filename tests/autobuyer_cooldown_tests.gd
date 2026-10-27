extends RefCounted

class Log extends RefCounted:
	var events: Array[Dictionary] = []
	var tick: int = 0
	func record_event(category: String, event: String, details: Dictionary = {}, source: String = "game") -> void:
		events.append({"category": category, "event": event, "details": details.duplicate(true), "source": source, "tick": tick})

class UpgradeProbe extends UpgradeAutomationManager:
	var attempts: int = 0
	func _attempt_purchase(id: String, simulation: Simulation) -> bool:
		attempts += 1
		return super(id, simulation)

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func make_state() -> GameState:
	var state := GameState.new()
	state.gameplay_log = Log.new()
	state.gameplay_rng.seed = 24680
	# Tiny test-only registry, using the production purchase/requirements code.
	# No production definition is changed or test balance copied into gameplay.
	state.upgrades.clear()
	state.upgrade_automation_manager = UpgradeProbe.new(state)
	return state


func add_upgrade(state: GameState, id: String, cost: float = 10.0, maximum: int = 1, tree: String = "atomic_friction", requirements: Array[Requirement] = [], group: String = "") -> Upgrade:
	var definition := UpgradeDefinition.new(id, id, "Cooldown regression fixture", ResourceIds.HEAT, cost, [], requirements, false, group, tree, maximum, 1.0, tree)
	var upgrade := Upgrade.new(definition)
	state.upgrades[id] = upgrade
	return upgrade


func enable(state: GameState, id: String = "atomic_friction") -> void:
	state.eternal_flame_state.unlock_technology(state.upgrade_automation_manager.get_automation_technology_id(id))
	check(state.upgrade_automation_manager.set_enabled(id, true), "Could not enable fixture autobuyer.")


func step(simulation: Simulation, delta: float, offline: bool = true) -> void:
	simulation.state.gameplay_log.tick += 1
	simulation.state.upgrade_automation_manager.update(delta, simulation, offline)


func purchases(state: GameState) -> Array:
	return state.gameplay_log.events.filter(func(event: Dictionary) -> bool: return event["category"] == "purchase")


func test_success_and_waiting() -> void:
	for offline in [false, true]:
		var state: GameState = make_state()
		var upgrade: Upgrade = add_upgrade(state, "cooldown_repeat", 20.0, 5)
		var simulation := Simulation.new(state)
		var manager: UpgradeProbe = state.upgrade_automation_manager as UpgradeProbe
		enable(state)
		check(manager.automation_states["atomic_friction"]["remaining_cooldown"] == manager.BASE_COOLDOWN, "Enabling did not start the initial cooldown.")
		step(simulation, 9.9, offline)
		check(purchases(state).is_empty() and manager.attempts == 0, "Initial cooldown attempted a purchase early.")
		step(simulation, 0.1, offline)
		check(manager.attempts == 1 and manager.automation_states["atomic_friction"]["remaining_cooldown"] == 0.0, "Failure restarted a cooldown.")
		for _index in range(3):
			step(simulation, 1000.0, offline)
		check(manager.attempts == 4 and purchases(state).is_empty(), "Repeated failure retried within a large update.")
		check(manager.automation_states["atomic_friction"]["remaining_cooldown"] == 0.0, "Repeated failures did not stay ready.")
		state.set_resource_amount(ResourceIds.HEAT, 40.0)
		step(simulation, 0.1, offline)
		var events: Array = purchases(state)
		check(events.size() == 1 and events[0]["tick"] == 6 and events[0]["details"]["upgrade_id"] == upgrade.definition.id, "First restored-affordability update missed its actual purchase.")
		check(events.size() == 1 and events[0]["details"]["cost"] == 20.0 and state.get_resource_amount(ResourceIds.HEAT) == 20.0, "Waiting purchase deducted the wrong amount.")
		check(manager.automation_states["atomic_friction"]["remaining_cooldown"] == manager.BASE_COOLDOWN, "Success did not start a full new cooldown.")
		step(simulation, 9.9, offline)
		check(purchases(state).size() == 1, "Success cooldown allowed an early second purchase.")
		step(simulation, 0.1, offline)
		check(purchases(state).size() == 2 and upgrade.level == 2, "Success cooldown did not expire correctly.")
		manager.set_enabled("atomic_friction", false)
		state.set_resource_amount(ResourceIds.HEAT, 100.0)
		step(simulation, 100.0, offline)
		check(purchases(state).size() == 2, "Disabled buyer purchased.")
		manager.set_enabled("atomic_friction", true)
		step(simulation, 9.9, offline)
		check(purchases(state).size() == 2, "Re-enabling bypassed initial cooldown.")
		step(simulation, 0.1, offline)
		check(purchases(state).size() == 3, "Re-enabled buyer missed its purchase.")


func test_requirements_and_preferences() -> void:
	var state: GameState = make_state()
	var requirement := Requirement.new(RequirementTypes.GENERATOR_LEVEL, "atomic_friction", 2)
	var upgrade: Upgrade = add_upgrade(state, "requires_level", 10.0, 1, "atomic_friction", [requirement])
	var simulation := Simulation.new(state)
	enable(state)
	state.set_resource_amount(ResourceIds.HEAT, 10.0)
	step(simulation, 10.0)
	check(purchases(state).is_empty() and state.upgrade_automation_manager.automation_states["atomic_friction"]["remaining_cooldown"] == 0.0, "Unmet requirement started another cooldown.")
	state.get_generator("atomic_friction").level = 2
	step(simulation, 0.1)
	check(upgrade.level == 1 and purchases(state).size() == 1 and purchases(state)[0]["tick"] == 2, "Satisfied requirement was not observed on the first update.")
	state = make_state()
	add_upgrade(state, "option_a", 10.0, 1, "atomic_friction", [], "choice")
	add_upgrade(state, "option_b", 10.0, 1, "atomic_friction", [], "choice")
	simulation = Simulation.new(state)
	enable(state)
	state.set_resource_amount(ResourceIds.HEAT, 100.0)
	step(simulation, 10.0)
	check(purchases(state).is_empty(), "Unselected exclusive upgrade was purchased.")
	state.upgrade_automation_manager.set_exclusive_preference("option_a", true)
	state.upgrade_automation_manager.set_exclusive_preference("option_b", true)
	step(simulation, 0.1)
	check(purchases(state).size() == 1 and purchases(state)[0]["details"]["upgrade_id"] == "option_b", "Waiting buyer cached an old exclusivity preference.")
	state.upgrade_automation_manager.set_exclusive_preference("option_a", true)
	step(simulation, 10.0)
	check(purchases(state).size() == 1 and state.upgrade_automation_manager.automation_states["atomic_friction"]["remaining_cooldown"] == 0.0, "Owned exclusivity conflict was ignored.")
	state = make_state()
	add_upgrade(state, "locked_tree", 10.0, 1, "molecular_agitation")
	enable(state, "molecular_agitation")
	state.set_resource_amount(ResourceIds.HEAT, 10.0)
	simulation = Simulation.new(state)
	step(simulation, 1000.0)
	check(purchases(state).is_empty() and state.upgrade_automation_manager.automation_states["molecular_agitation"]["remaining_cooldown"] == 10.0, "Locked generator advanced its autobuyer timer.")
	state.get_generator("molecular_agitation").unlocked = true
	step(simulation, 9.9)
	check(purchases(state).is_empty(), "Generator unlock bypassed the frozen initial timer.")
	step(simulation, 0.1)
	check(purchases(state).size() == 1 and purchases(state)[0]["details"]["upgrade_id"] == "locked_tree", "Unlocked tree missed its actual purchase.")
	state = make_state()
	var automatic: Upgrade = add_upgrade(state, "excluded_automatic", 0.0, 1, "")
	automatic.definition.automatic = true
	add_upgrade(state, "general_paid", 10.0, 1, "")
	enable(state, UpgradeAutomationManager.GENERAL_TREE_ID)
	simulation = Simulation.new(state)
	step(simulation, 10.0)
	check(purchases(state).is_empty(), "General tree purchased an automatic effect.")
	state.set_resource_amount(ResourceIds.HEAT, 10.0)
	step(simulation, 0.1)
	check(purchases(state).size() == 1 and purchases(state)[0]["details"]["upgrade_id"] == "general_paid", "General tree missed its first affordable update.")




func test_priority_and_competition() -> void:
	var state: GameState = make_state()
	add_upgrade(state, "first")
	add_upgrade(state, "second", 10.0, 1, "atomic_friction", [Requirement.new(RequirementTypes.UPGRADE_PURCHASED, "first", 1)])
	var simulation := Simulation.new(state)
	enable(state)
	state.set_resource_amount(ResourceIds.HEAT, 10.0)
	step(simulation, 10.0)
	check(purchases(state).size() == 1 and purchases(state)[0]["details"]["upgrade_id"] == "first", "Registry priority changed.")
	step(simulation, 10.0)
	state.set_resource_amount(ResourceIds.HEAT, 10.0)
	step(simulation, 0.1)
	check(purchases(state).size() == 2 and purchases(state)[1]["details"]["upgrade_id"] == "second", "Competing upgrade missed restored resources.")
	state = make_state()
	# Reverse registry order across trees; manager tree order must still win.
	add_upgrade(state, "ma_first_in_registry", 10.0, 1, "molecular_agitation")
	add_upgrade(state, "af_second_in_registry")
	state.get_generator("molecular_agitation").unlocked = true
	enable(state, "molecular_agitation")
	enable(state)
	simulation = Simulation.new(state)
	state.set_resource_amount(ResourceIds.HEAT, 10.0)
	step(simulation, 10.0)
	check(purchases(state).size() == 1 and purchases(state)[0]["details"]["upgrade_id"] == "af_second_in_registry", "Automation tree priority changed.")
	state.set_resource_amount(ResourceIds.HEAT, 10.0)
	step(simulation, 0.1)
	check(purchases(state).size() == 2 and purchases(state)[1]["details"]["upgrade_id"] == "ma_first_in_registry", "Later waiting tree did not buy on its first eligible update.")
	state = make_state()
	var generator: Generator = state.get_generator("atomic_friction")
	generator.manually_paused = true
	var cost: float = generator.get_cost(state)
	add_upgrade(state, "competing_with_generator", cost)
	enable(state)
	state.eternal_flame_state.unlock_technology(state.generator_automation_manager.get_automation_technology_id(generator.definition.id))
	state.generator_automation_manager.set_enabled(generator.definition.id, true)
	state.generator_automation_manager.automation_states[generator.definition.id]["remaining_cooldown"] = 0.1
	state.upgrade_automation_manager.automation_states[generator.definition.id]["remaining_cooldown"] = 0.1
	state.set_resource_amount(ResourceIds.HEAT, cost)
	simulation = Simulation.new(state)
	state.gameplay_log.tick = 1
	simulation.update(0.1, true)
	check(purchases(state).size() == 1 and purchases(state)[0]["event"] == "generator_level_purchased", "Upgrade buyer ran ahead of generator automation.")
	check(state.upgrade_automation_manager.automation_states[generator.definition.id]["remaining_cooldown"] == 0.0, "Resource competition restarted the failed upgrade timer.")
	state.set_resource_amount(ResourceIds.HEAT, cost)
	state.gameplay_log.tick = 2
	simulation.update(0.1, true)
	check(purchases(state).size() == 2 and purchases(state)[1]["event"] == "upgrade_purchased" and purchases(state)[1]["tick"] == 2, "Upgrade missed resources restored on the next simulation tick.")
	check(state.get_resource_amount(ResourceIds.HEAT) == 0.0, "Competing purchases changed deductions.")


func test_large_delta() -> void:
	var state: GameState = make_state()
	var upgrade: Upgrade = add_upgrade(state, "large_step", 1.0, 10)
	var simulation := Simulation.new(state)
	enable(state)
	var manager: UpgradeProbe = state.upgrade_automation_manager as UpgradeProbe
	step(simulation, 1000000.0)
	check(manager.attempts == 1 and purchases(state).is_empty(), "Large delta repeated a failed scan.")
	state.set_resource_amount(ResourceIds.HEAT, 100.0)
	step(simulation, 1000000.0)
	check(purchases(state).size() == 1 and manager.automation_states["atomic_friction"]["remaining_cooldown"] == 10.0, "Waiting time was carried into a successful purchase.")
	step(simulation, 25.0)
	check(purchases(state).size() == 3 and upgrade.level == 3 and manager.automation_states["atomic_friction"]["remaining_cooldown"] == 5.0, "Positive-timer large delta lost successful-purchase overshoot.")
	state.set_resource_amount(ResourceIds.HEAT, 0.0)
	var attempts: int = manager.attempts
	step(simulation, 1000000.0)
	check(manager.attempts == attempts + 1 and manager.automation_states["atomic_friction"]["remaining_cooldown"] == 0.0, "Exhausted large update did not stop at its first failure.")
	state.set_resource_amount(ResourceIds.HEAT, 100.0)
	step(simulation, 0.1)
	check(purchases(state).size() == 4, "Large-delta failure blocked next-tick purchase.")
	step(simulation, 1000000.0)
	check(upgrade.level == 10 and purchases(state).size() == 10 and manager.automation_states["atomic_friction"]["remaining_cooldown"] == 0.0, "Maxed upgrades did not terminate large-step processing.")
	# Generator cooldown upgrades and its existing waiting behavior stay intact.
	state = make_state()
	state.eternal_flame_state.upgrade_levels["generator_automation_cooldown_atomic_friction"] = 3
	var gm: GeneratorAutomationManager = state.generator_automation_manager
	state.eternal_flame_state.unlock_technology(gm.get_automation_technology_id("atomic_friction"))
	gm.set_enabled("atomic_friction", true)
	var cooldown: float = gm.get_cooldown("atomic_friction")
	check(cooldown == maxf(gm.MINIMUM_COOLDOWN, gm.BASE_COOLDOWN * pow(gm.COOLDOWN_MULTIPLIER_PER_LEVEL, 3)), "Generator cooldown upgrade changed.")
	simulation = Simulation.new(state)
	gm.update(cooldown, simulation, true)
	state.set_resource_amount(ResourceIds.HEAT, state.get_generator("atomic_friction").get_cost(state))
	gm.update(1000000.0, simulation, true)
	check(purchases(state).size() == 1 and gm.automation_states["atomic_friction"]["remaining_cooldown"] == cooldown, "Existing generator waiting semantics changed.")


func test_save_and_reset() -> void:
	var state: GameState = make_state()
	add_upgrade(state, "persisted", 10.0, 5)
	enable(state)
	var simulation := Simulation.new(state)
	step(simulation, 10.0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(SaveManager.new().state_to_dictionary(state)))
	var loaded: GameState = make_state()
	add_upgrade(loaded, "persisted", 10.0, 5)
	check(SaveManager.new().dictionary_to_state(loaded, saved, SaveManager.SAVE_VERSION), "Existing save format failed to load.")
	check(loaded.upgrade_automation_manager.is_enabled("atomic_friction") and loaded.upgrade_automation_manager.automation_states["atomic_friction"]["remaining_cooldown"] == 10.0, "Load did not preserve enabled state and restart the existing initial cooldown.")
	var automation_data: Dictionary = state.upgrade_automation_manager.get_save_data()
	check(automation_data["trees"]["atomic_friction"].keys() == ["enabled"], "Runtime waiting state changed the save schema.")
	loaded.set_resource_amount(ResourceIds.HEAT, 10.0)
	var loaded_simulation := Simulation.new(loaded)
	step(loaded_simulation, 9.9)
	check(purchases(loaded).is_empty(), "Loaded buyer skipped initial cooldown.")
	step(loaded_simulation, 0.1)
	check(purchases(loaded).size() == 1 and purchases(loaded)[0]["details"]["upgrade_id"] == "persisted", "Loaded buyer missed its purchase.")
	state.reset_current_run()
	check(state.upgrade_automation_manager.is_enabled("atomic_friction") and state.upgrade_automation_manager.automation_states["atomic_friction"]["remaining_cooldown"] == 10.0, "Prestige reset retained a zero waiting timer.")
	state.set_resource_amount(ResourceIds.HEAT, 10.0)
	step(simulation, 9.9)
	check(purchases(state).is_empty(), "Reset buyer skipped initial cooldown.")
	step(simulation, 0.1)
	check(purchases(state).size() == 1, "Reset buyer missed its actual purchase.")
	var locked: GameState = make_state()
	locked.upgrade_automation_manager.load_save_data(automation_data)
	check(not locked.upgrade_automation_manager.is_enabled("atomic_friction"), "Save bypassed missing automation technology.")
	check(not locked.upgrade_automation_manager.set_enabled("atomic_friction", true), "Enable bypassed missing automation technology.")
