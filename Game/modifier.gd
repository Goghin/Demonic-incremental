
class_name Modifier
extends RefCounted


var id: String = ""
var type: String
var target_id: String
var multiplier: float
var source_upgrade_id: String = ""

const DYNAMIC_NONE = ""
const DYNAMIC_RESOURCE_LOG10 = "resource_log10"
const DYNAMIC_RESOURCE_SQRT = "resource_sqrt"
const DYNAMIC_RESOURCE_SQRT_INVERSE = "resource_sqrt_inverse"
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
	
	var raw_multiplier = get_multiplier(state)
	
	var sensitivity = generator.get_modifier_sensitivity(
		id,
		state
	)
	
	return 1.0 + (
		raw_multiplier - 1.0
	) * sensitivity


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
	
		if source_upgrade_id == "thermic_mass":
			scaling_multiplier = (
			state.realm_effects.thermal_mass_multiplier
		)
	
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
	
		var threshold = 100.0
	
		if resource_amount <= threshold:
			return 1.0
	
		var excess = sqrt(resource_amount) - sqrt(threshold)
	
		var scaling_multiplier = multiplier

		if source_upgrade_id == "ashen_contamination":
			scaling_multiplier /= (
			state.realm_effects.ashen_contamination_multiplier
		)
	
		return 1.0 / (
			1.0 + scaling_multiplier * excess
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
