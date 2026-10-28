extends RefCounted

# Conditional investigation API, NEVER used to authorize adaptive execution.
# A bound on event time is not a proof of input/production/automation safety.
# The caller must independently prove fixed levels, mode, modifiers, thresholds
# and realm parameters. Resource amounts may vary arbitrarily but stay >= 0.
static func inspect(generator: Generator, state: GameState, configuration_frozen: bool = false) -> Dictionary:
	if not configuration_frozen:
		return {"status": "unknown", "reason": "configuration_not_proven_invariant"}
	if not generator.cycle_active or not generator.definition.cycle_based:
		return {"status": "inactive"}
	var speed_upper: float = 1.0
	for modifier: Modifier in generator.modifiers:
		if modifier.type != ModifierTypes.CYCLE_SPEED:
			continue
		if not modifier.operation_mode_ids.is_empty() and not modifier.operation_mode_ids.has(generator.operation_mode_id):
			continue
		var low: float = modifier.multiplier
		var high: float = modifier.multiplier
		if modifier.dynamic:
			if modifier.dynamic_formula == Modifier.DYNAMIC_GENERATOR_LEVEL:
				low = modifier.get_multiplier(state)
				high = low
			elif modifier.dynamic_formula == Modifier.DYNAMIC_RESOURCE_SQRT_INVERSE and modifier.multiplier >= 0.0:
				if modifier.dynamic_realm_effect_id != "":
					var realm: float = float(state.realm_effects.get(modifier.dynamic_realm_effect_id))
					if not is_finite(realm) or realm < 0.0:
						return {"status": "unknown", "reason": "invalid_realm_coefficient"}
				low = 0.0
				high = 1.0
			elif modifier.dynamic_formula == Modifier.DYNAMIC_RESOURCE_EXPONENT and modifier.multiplier >= 0.0 and modifier.multiplier <= 1.0:
				low = 0.0
				high = 1.0
			else:
				return {"status": "unknown", "reason": "unbounded_speed_formula"}
		if not is_finite(low) or not is_finite(high):
			return {"status": "unknown", "reason": "nonfinite_modifier"}
		var sensitivity_low: float = 1.0
		var sensitivity_high: float = 1.0
		for sensitivity: ModifierSensitivity in generator.modifier_sensitivities:
			if sensitivity.modifier_id != modifier.id:
				continue
			if not sensitivity.operation_mode_ids.is_empty() and not sensitivity.operation_mode_ids.has(generator.operation_mode_id):
				continue
			if sensitivity.multiplier < 0.0 or not is_finite(sensitivity.multiplier):
				return {"status": "unknown", "reason": "unsupported_sensitivity"}
			if sensitivity.dynamic:
				if sensitivity.dynamic_formula != ModifierSensitivity.DYNAMIC_RESOURCE_SQRT_INVERSE:
					return {"status": "unknown", "reason": "unknown_sensitivity_formula"}
				sensitivity_low = 0.0
			else:
				sensitivity_low *= sensitivity.multiplier
				sensitivity_high *= sensitivity.multiplier
		var factor_upper: float = 0.0
		if modifier.id == "crystallization":
			# Production's special pow(raw, clamp(sensitivity, 0, 1)).
			factor_upper = maxf(1.0, high)
		else:
			# Keep signs: sensitivities above one can make individual effective
			# multipliers negative. Absolute bounds safely cover their product.
			for raw: float in [low, high]:
				for sensitivity: float in [sensitivity_low, sensitivity_high]:
					factor_upper = maxf(factor_upper, absf(1.0 + (raw - 1.0) * sensitivity))
		speed_upper *= factor_upper
		if not is_finite(speed_upper):
			return {"status": "unknown", "reason": "nonfinite_speed_bound"}
	if not is_finite(generator.get_cycle_duration()) or generator.get_cycle_duration() <= 0.0 or not is_finite(generator.cycle_progress):
		return {"status": "unknown", "reason": "invalid_cycle_clock"}
	var remaining: float = maxf(0.0, generator.get_cycle_duration() - generator.cycle_progress)
	# Production currently compares completion with duration - 0.000001.
	# This contract is local to this source revision, not a new gameplay value.
	var lower_seconds: float = maxf(0.0, remaining - 0.000001) / (speed_upper * (1.0 + 1e-10)) if speed_upper > 0.0 else INF
	return {"status": "conditional_bound", "speed_upper": speed_upper, "remaining_progress": remaining, "completion_not_before_seconds": lower_seconds}
