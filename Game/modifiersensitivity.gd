class_name ModifierSensitivity
extends RefCounted


const DYNAMIC_NONE = ""
const DYNAMIC_RESOURCE_SQRT_INVERSE = "resource_sqrt_inverse"

var modifier_id: String
var multiplier: float
var source_upgrade_id: String

var dynamic: bool = false
var dynamic_formula: String = ""
var dynamic_resource_id: String = ""


func _init(
	sensitivity_modifier_id: String,
	sensitivity_multiplier: float,
	sensitivity_source_upgrade_id: String = ""
) -> void:
	modifier_id = sensitivity_modifier_id
	multiplier = sensitivity_multiplier
	source_upgrade_id = sensitivity_source_upgrade_id


func get_effective_multiplier(
	state: GameState
	) -> float:
	
	if not dynamic:
		return multiplier
	
	if dynamic_formula == DYNAMIC_RESOURCE_SQRT_INVERSE:
		var resource_amount = state.get_resource_amount(
			dynamic_resource_id
		)
		
		if resource_amount <= 0.0:
			return 1.0
		
		return 1.0 / (
			1.0
			+ multiplier * sqrt(resource_amount)
		)
	
	return multiplier
