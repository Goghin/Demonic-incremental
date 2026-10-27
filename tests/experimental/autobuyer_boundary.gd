extends RefCounted

# An invariant resource box, not a current-rate extrapolation. Valid only inside
# the inherited continuous-only guard: no purchases, unlocks, cycles or consumers.
# A source-free resource cannot increase under the existing environmental sinks.
static func inspect(simulation: Simulation) -> Dictionary:
	var state: GameState = simulation.state
	var sources: Dictionary = {}
	for generator in state.generators.values():
		if not generator.unlocked or generator.manually_paused or (generator.level <= 0 and not generator.operating):
			continue
		for output in generator.get_active_outputs():
			if output.unlocked:
				sources[output.resource_id] = true
	# Environmental conversion is also a source: apply_matter_decay adds the
	# removed Matter to Heat before Heat leak. Do not infer Heat is source-free
	# merely because no generator outputs it. Future Matter production also
	# makes this dependency possible, even below the current decay threshold.
	if sources.has(ResourceIds.MATTER) or state.get_resource_amount(ResourceIds.MATTER) > state.realm_effects.matter_decay_threshold:
		sources[ResourceIds.HEAT] = true
	var upper: Dictionary = {}
	for id in state.resources:
		if not sources.has(id):
			var amount: float = state.get_resource_amount(id)
			if is_finite(amount) and amount >= 0.0:
				upper[id] = amount
	var enabled: bool = false
	var gm: GeneratorAutomationManager = state.generator_automation_manager
	for id in gm.automation_states:
		var entry: Dictionary = gm.automation_states[id]
		if not entry["enabled"]:
			continue
		enabled = true
		var generator: Generator = state.get_generator(id)
		if not gm.is_automation_unlocked(id) or generator == null or not generator.unlocked:
			continue
		if simulation.can_buy_generator(id):
			return _failure("currently_affordable")
		if not entry["waiting_for_resources"] or gm._waiting_cost_needs_refresh(generator, entry):
			return _failure("generator_wait_transition")
		# Reject dynamic cost AND sensitivity dependencies; do not guess a lower
		# bound for arbitrary resource-dependent formulas or mode-specific effects.
		for modifier in generator.modifiers:
			if modifier.type in [ModifierTypes.COST, ModifierTypes.COST_SCALING]:
				if modifier.dynamic:
					return _failure("dynamic_cost")
				for sensitivity in generator.modifier_sensitivities:
					if sensitivity.modifier_id == modifier.id and sensitivity.dynamic:
						return _failure("dynamic_cost_sensitivity")
		var cost: float = generator.get_cost(state)
		if not is_finite(cost) or cost != float(entry["waiting_cost"]):
			return _failure("waiting_cost_mismatch")
		var resource: String = generator.definition.cost_resource_id
		if not upper.has(resource) or float(upper[resource]) >= cost:
			return _failure("possible_purchase_boundary" if sources.has(resource) else "unknown_resource_bound")
	var um: UpgradeAutomationManager = state.upgrade_automation_manager
	for id in um.automation_states:
		if not um.automation_states[id]["enabled"]:
			continue
		enabled = true
		if not um.is_automation_unlocked(id):
			continue
		var generator: Generator = state.get_generator(id)
		if id != UpgradeAutomationManager.GENERAL_TREE_ID and (generator == null or not generator.unlocked):
			continue
		# Only ready buyers have invariant timer state. Positive timers must
		# expire on the original tick grid before waiting checks can be skipped.
		if float(um.automation_states[id]["remaining_cooldown"]) != 0.0:
			return _failure("upgrade_cooldown_transition")
		for upgrade in state.upgrades.values():
			var definition: UpgradeDefinition = upgrade.definition
			if not um._upgrade_belongs_to_tree(definition, id) or upgrade.is_maxed():
				continue
			if definition.exclusivity_group != "" and not um.is_exclusive_preference_selected(definition.id):
				continue
			if simulation.can_buy_upgrade(definition.id):
				return _failure("currently_affordable")
			# Any unmet non-resource requirement is invariant while the parent
			# guard excludes every automatic/discrete transition and purchase.
			var blocked: bool = not state.upgrade_system.upgrade_exclusivity_available(upgrade)
			for requirement in definition.requirements:
				if not state.upgrade_system.requirement_met(requirement):
					if requirement.type != RequirementTypes.RESOURCE:
						blocked = true
					elif upper.has(requirement.target_id) and float(upper[requirement.target_id]) < requirement.value:
						blocked = true
			if blocked:
				continue
			var cost: float = simulation.get_upgrade_cost(upgrade)
			if not is_finite(cost) or not upper.has(definition.cost_resource_id) or float(upper[definition.cost_resource_id]) >= cost:
				return _failure("possible_upgrade_boundary" if sources.has(definition.cost_resource_id) else "unknown_upgrade_bound")
	return {"status": "provably_waiting" if enabled else "disabled", "upper": upper}


static func _failure(reason: String) -> Dictionary:
	return {"status": reason, "upper": {}}
