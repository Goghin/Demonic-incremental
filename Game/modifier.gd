
class_name Modifier
extends RefCounted


var id: String = ""
var type: String
var target_id: String
var multiplier: float
var source_upgrade_id: String = ""
var operation_mode_ids: Array[String] = []

const DYNAMIC_NONE = ""
const DYNAMIC_RESOURCE_LOG10 = "resource_log10"
const DYNAMIC_RESOURCE_SQRT = "resource_sqrt"
const DYNAMIC_RESOURCE_SQRT_INVERSE = "resource_sqrt_inverse"
const DYNAMIC_RESOURCE_INVERSE_BOOST = "resource_inverse_boost"
const DYNAMIC_GENERATOR_LEVEL = "generator_level"
const DYNAMIC_RESOURCE_EXPONENT = "resource_exponent"
const DYNAMIC_LAVA_MITE_DORMANCY = "lava_mite_dormancy"
const DYNAMIC_RESOURCE_POWER_THRESHOLD = "resource_power_threshold"

var dynamic_threshold: float = 1000.0
var dynamic_exponent: float = 0.35
var dynamic: bool = false
var dynamic_resource_id: String = ""
var dynamic_formula: String = ""
var dynamic_generator_id: String = ""
var dynamic_realm_effect_id: String = ""
var dynamic_realm_effect_is_divisor: bool = false


func _init(
	modifier_type: String,
	modifier_target_id: String,
	modifier_multiplier: float
) -> void:
	type = modifier_type
	target_id = modifier_target_id
	multiplier = modifier_multiplier


func applies_to(
	target_type: String,
	target_id_to_check: String = ""
) -> bool:
	if type != target_type:
		return false
	
	if target_id == "":
		return true
	
	return target_id == target_id_to_check


func apply(
	value: float,
	state: GameState,
	generator: Generator
) -> float:
	return value * get_effective_multiplier(
		state,
		generator
	)


func get_effective_multiplier(
	state: GameState,
	generator: Generator
) -> float:
	
	if not operation_mode_ids.is_empty() and not operation_mode_ids.has(generator.operation_mode_id):
		return 1.0
	
	var raw_multiplier = get_multiplier(state)
	
	var sensitivity = generator.get_modifier_sensitivity(
		id,
		state
	)
	
	# Crystallization is a compounding penalty, not a linear modifier.
	# Essence reduces the exponent applied to the raw penalty, allowing
	# severe penalties to remain scalable without imposing a flat floor.
	if id == "crystallization":
		return pow(
			maxf(raw_multiplier, 0.0),
			clampf(sensitivity, 0.0, 1.0)
		)

	return 1.0 + (
		raw_multiplier - 1.0
	) * sensitivity


# Event chance modifiers are additive percentage-point values rather than
# multipliers. Dynamic formulas still return a multiplier, so convert their
# result back to a delta before applying it to the base event chance.
func get_effective_additive(
	state: GameState,
	generator: Generator
) -> float:
	if not operation_mode_ids.is_empty() and not operation_mode_ids.has(generator.operation_mode_id):
		return 0.0

	var additive_value := multiplier
	if dynamic:
		additive_value = get_multiplier(state) - 1.0

	return additive_value * generator.get_modifier_sensitivity(id, state)


func get_multiplier(state: GameState) -> float:
	if not dynamic:
		return multiplier
	
	if dynamic_formula == DYNAMIC_RESOURCE_LOG10:
		var resource_amount = state.get_resource_amount(
			dynamic_resource_id
	)
	
		if resource_amount <= 1.0:
			return 1.0
	
		var scaling_multiplier = 1.0
		if dynamic_realm_effect_id != "":
			var realm_effect_multiplier := float(
				state.realm_effects.get(dynamic_realm_effect_id)
			)
			if dynamic_realm_effect_is_divisor:
				if realm_effect_multiplier > 0.0:
					scaling_multiplier /= realm_effect_multiplier
			else:
				scaling_multiplier *= realm_effect_multiplier
	
		return 1.0 + (
			multiplier
			* scaling_multiplier
			* log(resource_amount)
			/ log(10.0)
		)
		
	if dynamic_formula == DYNAMIC_RESOURCE_SQRT:
		var resource_amount = state.get_resource_amount(
			dynamic_resource_id
		)
		
		if resource_amount <= 0.0:
			return 1.0
		
		return 1.0 + multiplier * sqrt(resource_amount)
		
	if dynamic_formula == DYNAMIC_GENERATOR_LEVEL:
		var generator = state.get_generator(
			dynamic_generator_id
		)
		
		if generator == null:
			return 1.0
		
		return 1.0 + multiplier * generator.level
	
	if dynamic_formula == DYNAMIC_RESOURCE_SQRT_INVERSE:
		var resource_amount = state.get_resource_amount(
			dynamic_resource_id
		)
	
		# Use the configured threshold for this resource when one exists.
		# dynamic_threshold remains the fallback for unconfigured resources.
		var threshold: float = state.get_resource_threshold(
			dynamic_resource_id,
			dynamic_threshold
		)
		threshold = maxf(threshold, 0.0)
	
		if resource_amount <= threshold:
			return 1.0
	
		var excess = sqrt(resource_amount) - sqrt(threshold)
	
		var scaling_multiplier = multiplier
		if dynamic_realm_effect_id != "":
			var realm_effect_multiplier := float(
				state.realm_effects.get(dynamic_realm_effect_id)
			)
			if dynamic_realm_effect_is_divisor:
				if realm_effect_multiplier > 0.0:
					scaling_multiplier /= realm_effect_multiplier
			else:
				scaling_multiplier *= realm_effect_multiplier
	
		return 1.0 / (
			1.0 + scaling_multiplier * excess
		)
	
	if dynamic_formula == DYNAMIC_RESOURCE_INVERSE_BOOST:
		var resource_amount := maxf(0.0, state.get_resource_amount(dynamic_resource_id))
		var decay_scale := maxf(dynamic_threshold, 1.0)
		var decay_exponent := maxf(dynamic_exponent, 0.0)
		# The rolled multiplier value represents bonus strength, not a final
		# multiplier. The bonus is strongest at zero stock and fades smoothly
		# toward 1.0 as the configured resource accumulates.
		return 1.0 + maxf(multiplier, 0.0) / pow(
			1.0 + resource_amount / decay_scale,
			decay_exponent
		)

	if dynamic_formula == DYNAMIC_RESOURCE_EXPONENT:
		var resource_amount = state.get_resource_amount(
			dynamic_resource_id
		)
		
		return pow(multiplier, resource_amount)
		
	if dynamic_formula == DYNAMIC_LAVA_MITE_DORMANCY:
		return state.get_lava_mite_dormancy_multiplier()
	
	if dynamic_formula == DYNAMIC_RESOURCE_POWER_THRESHOLD:
		var resource_amount = state.get_resource_amount(
			dynamic_resource_id
		)
	
		if resource_amount <= dynamic_threshold:
			return 1.0
	
		return 1.0 + multiplier * (
			pow(
				resource_amount / dynamic_threshold,
				dynamic_exponent
			) - 1.0
		)
	
			
	return multiplier
