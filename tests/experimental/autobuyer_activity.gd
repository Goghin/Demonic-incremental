extends RefCounted

# Optional instrumentation only; never used for throughput measurements.
class GeneratorProbe extends GeneratorAutomationManager:
	var metrics: Dictionary = {"entry_evaluations": 0, "waiting_checks": 0, "attempts": 0,
		"no_affordable_seconds": 0.0, "unlock_wait_seconds": 0.0, "body_usec": 0}
	func update(delta: float, simulation: Simulation, offline_mode: bool = false) -> void:
		for id in automation_states:
			if not is_enabled(id):
				continue
			metrics["entry_evaluations"] += 1
			var generator: Generator = state.get_generator(id)
			if not is_automation_unlocked(id) or generator == null or not generator.unlocked:
				metrics["unlock_wait_seconds"] += delta
			elif not simulation.can_buy_generator(id):
				metrics["no_affordable_seconds"] += delta
			if automation_states[id]["waiting_for_resources"]:
				metrics["waiting_checks"] += 1
		var start: int = Time.get_ticks_usec()
		super(delta, simulation, offline_mode)
		metrics["body_usec"] += Time.get_ticks_usec() - start
	func _attempt_purchase(id: String, simulation: Simulation, checked: bool = false) -> void:
		metrics["attempts"] += 1
		super(id, simulation, checked)


class UpgradeProbe extends UpgradeAutomationManager:
	var metrics: Dictionary = {"entry_evaluations": 0, "attempts": 0,
		"no_affordable_seconds": 0.0, "unlock_wait_seconds": 0.0, "body_usec": 0}
	func update(delta: float, simulation: Simulation, offline_mode: bool = false) -> void:
		for id in automation_states:
			if not is_enabled(id):
				continue
			metrics["entry_evaluations"] += 1
			var generator: Generator = state.get_generator(id)
			if not is_automation_unlocked(id) or (id != GENERAL_TREE_ID and (generator == null or not generator.unlocked)):
				metrics["unlock_wait_seconds"] += delta
				continue
			var affordable: bool = false
			for upgrade in state.upgrades.values():
				if _upgrade_belongs_to_tree(upgrade.definition, id) and (upgrade.definition.exclusivity_group == "" or is_exclusive_preference_selected(upgrade.definition.id)) and simulation.can_buy_upgrade(upgrade.definition.id):
					affordable = true
					break
			if not affordable:
				metrics["no_affordable_seconds"] += delta
		var start: int = Time.get_ticks_usec()
		super(delta, simulation, offline_mode)
		metrics["body_usec"] += Time.get_ticks_usec() - start
	func _attempt_purchase(id: String, simulation: Simulation) -> bool:
		metrics["attempts"] += 1
		return super(id, simulation)


static func install(state: GameState) -> void:
	var generator := GeneratorProbe.new(state)
	generator.automation_states = state.generator_automation_manager.automation_states.duplicate(true)
	var upgrade := UpgradeProbe.new(state)
	upgrade.automation_states = state.upgrade_automation_manager.automation_states.duplicate(true)
	upgrade.exclusive_preferences = state.upgrade_automation_manager.exclusive_preferences.duplicate(true)
	state.generator_automation_manager = generator
	state.upgrade_automation_manager = upgrade
