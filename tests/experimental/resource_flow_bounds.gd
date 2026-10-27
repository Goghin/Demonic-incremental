extends RefCounted

# Capability proof for invariant continuous rates. A gross-flow box encloses
# EVERY ordered microstep, not just the endpoint. No replenishment is credited
# to the input lower bound. No consumer is removed from the reference map.
static func inspect(state: GameState, horizon: float) -> Dictionary:
	var changed: Dictionary = {}
	var production: Dictionary = {}
	var consumption: Dictionary = {}
	var active: Array[Generator] = []
	var has_consumer: bool = false
	for g: Generator in state.generators.values():
		if g.cycle_active or g.auto_run_cycles:
			return _failure("cycle/active/" + g.definition.id)
	for g: Generator in state.generators.values():
		if not g.unlocked or g.definition.cycle_based:
			continue
		# Production has a hardcoded throttle controller not described by IO.
		# This explicit rejection documents that metadata gap, not a rate rule.
		if g.definition.id == "lava_mite_colony":
			return _failure("controller/unmodelled_throttle/" + g.definition.id)
		if g.manually_paused or g.level <= 0:
			if g.operating or not g.get_active_inputs().is_empty():
				return _failure("controller/inactive_consumer/" + g.definition.id)
			continue
		active.append(g)
		for input: GeneratorIO in g.get_active_inputs():
			has_consumer = true
			changed[input.resource_id] = true
		for output: GeneratorIO in g.get_active_outputs():
			if output.unlocked:
				changed[output.resource_id] = true
	if not has_consumer:
		return {"reason": "", "consumers": false}
	for g: Generator in active:
		var mode: GeneratorOperationMode = g.get_operation_mode()
		var transfer: bool = mode != null and mode.is_resource_transfer
		for modifier: Modifier in g.modifiers:
			if modifier.type != ModifierTypes.INPUT_DRAW and (modifier.type != ModifierTypes.PRODUCTION or transfer):
				continue
			if not modifier.operation_mode_ids.is_empty() and not modifier.operation_mode_ids.has(g.operation_mode_id):
				continue
			if modifier.dynamic:
				if modifier.dynamic_formula == Modifier.DYNAMIC_LAVA_MITE_DORMANCY:
					return _failure("modifier/time/" + g.definition.id)
				if not modifier.dynamic_formula in [Modifier.DYNAMIC_RESOURCE_LOG10, Modifier.DYNAMIC_RESOURCE_SQRT, Modifier.DYNAMIC_RESOURCE_SQRT_INVERSE, Modifier.DYNAMIC_RESOURCE_INVERSE_BOOST, Modifier.DYNAMIC_RESOURCE_EXPONENT, Modifier.DYNAMIC_RESOURCE_POWER_THRESHOLD, Modifier.DYNAMIC_GENERATOR_LEVEL]:
					return _failure("modifier/unknown_formula/" + g.definition.id)
				if modifier.dynamic_formula != Modifier.DYNAMIC_GENERATOR_LEVEL:
					if modifier.dynamic_resource_id == "" or changed.has(modifier.dynamic_resource_id):
						return _failure("modifier/resource/" + g.definition.id + "/" + modifier.dynamic_resource_id)
			for sensitivity: ModifierSensitivity in g.modifier_sensitivities:
				if sensitivity.modifier_id == modifier.id and sensitivity.dynamic:
					if sensitivity.dynamic_formula != ModifierSensitivity.DYNAMIC_RESOURCE_SQRT_INVERSE or sensitivity.dynamic_resource_id == "" or changed.has(sensitivity.dynamic_resource_id):
						return _failure("sensitivity/resource/" + g.definition.id + "/" + sensitivity.dynamic_resource_id)
		for input: GeneratorIO in g.get_active_inputs():
			var rate: float = g.get_input_consumption_per_second(input, state)
			if not is_finite(rate) or rate < 0.0:
				return _failure("rate/invalid_input/" + g.definition.id)
			consumption[input.resource_id] = float(consumption.get(input.resource_id, 0.0)) + rate
		for output: GeneratorIO in g.get_active_outputs():
			if not output.unlocked:
				continue
			if output.discrete:
				return _failure("output/discrete/" + g.definition.id)
			var rate: float = g.get_production_rate(output, state)
			if not is_finite(rate) or rate < 0.0:
				return _failure("rate/invalid_output/" + g.definition.id)
			production[output.resource_id] = float(production.get(output.resource_id, 0.0)) + rate
	# Bound accumulated binary64 roundoff for the reference transaction count.
	# The ceiling also covers a fractional final tick; two epsilons per IO
	# transaction cover the multiply and ordered add/subtract.
	var transactions: int = 1
	for g: Generator in active:
		transactions += g.get_active_inputs().size() + g.get_active_outputs().size()
	var rounding: float = ceilf(horizon / TimeManager.OFFLINE_MAX_GAME_STEP) * float(transactions) * 4.440892098500626e-16
	if not is_finite(rounding) or rounding >= 0.5:
		return _failure("numerical/unbounded_roundoff_horizon")
	var outward_fraction: float = maxf(1e-10, rounding / (1.0 - rounding))
	var lower: Dictionary = {}
	var upper: Dictionary = {}
	for id: String in state.resources:
		var amount: float = state.get_resource_amount(id)
		if not is_finite(amount) or amount < 0.0:
			return _failure("resource/invalid/" + id)
		# Outward padding covers summation roundoff; strict inequalities keep
		# resource exhaustion and environmental regimes on exact ticks.
		var padding: float = 1e-8 + (amount + horizon * (float(production.get(id, 0.0)) + float(consumption.get(id, 0.0)))) * outward_fraction
		lower[id] = amount - horizon * float(consumption.get(id, 0.0)) - padding
		upper[id] = amount + horizon * float(production.get(id, 0.0)) + padding
		if not is_finite(float(lower[id])) or not is_finite(float(upper[id])):
			return _failure("resource/nonfinite_bound/" + id)
		if consumption.has(id) and float(lower[id]) <= padding:
			return _failure("input/exhaustion/" + id)
	for pair: Array in [[ResourceIds.HEAT, state.realm_effects.heat_leak_threshold], [ResourceIds.MATTER, state.realm_effects.matter_decay_threshold]]:
		if float(upper[pair[0]]) >= float(pair[1]):
			return _failure("environment/regime/" + str(pair[0]))
	# Auto upgrades may be activated by an increase OR by a decreasing
	# resource satisfying a custom requirement. Only immutable blockers count.
	for upgrade: Upgrade in state.upgrades.values():
		if not upgrade.definition.automatic or upgrade.is_maxed():
			continue
		var blocked: bool = false
		for requirement: Requirement in upgrade.definition.requirements:
			if not state.upgrade_system.requirement_met(requirement):
				if requirement.type != RequirementTypes.RESOURCE or not changed.has(requirement.target_id):
					blocked = true
		if not blocked:
			return _failure("upgrade/automatic_resource/" + upgrade.definition.id)
	return {"reason": "", "consumers": true, "lower": lower, "upper": upper, "changed": changed}


static func _failure(reason: String) -> Dictionary:
	return {"reason": reason, "consumers": true}
