
class_name UpgradeEffect
extends RefCounted


var type: String
var target_id: String

var modifier_type: String
var value: float
var modifier_target_id: String
var modifier_id: String

var dynamic_formula: String
var dynamic_resource_id: String
var dynamic_generator_id: String

var sensitivity_modifier_id: String
var sensitivity_multiplier: float


func _init(
	effect_type: String,
	effect_target_id: String
	) -> void:
	
	type = effect_type
	target_id = effect_target_id


static func unlock_generator(
	generator_id: String
	) -> UpgradeEffect:
	
	return UpgradeEffect.new(
		UpgradeEffectTypes.UNLOCK_GENERATOR,
		generator_id
	)


static func modifier(
	effect_target_id: String,
	effect_modifier_type: String,
	effect_value: float,
	effect_modifier_target_id: String = ""
	) -> UpgradeEffect:
	
	var effect = UpgradeEffect.new(
		UpgradeEffectTypes.APPLY_MODIFIER,
		effect_target_id
	)
	
	effect.set_modifier(
		effect_modifier_type,
		effect_value,
		effect_modifier_target_id
	)
	
	return effect


static func dynamic_resource_modifier(
	effect_target_id: String,
	effect_modifier_type: String,
	effect_value: float,
	effect_resource_id: String,
	effect_dynamic_formula: String,
	effect_modifier_id: String = "",
	effect_modifier_target_id: String = ""
	) -> UpgradeEffect:
	
	var effect = UpgradeEffect.new(
		UpgradeEffectTypes.APPLY_MODIFIER,
		effect_target_id
	)
	
	effect.set_modifier(
		effect_modifier_type,
		effect_value,
		effect_modifier_target_id
	)
	
	effect.set_dynamic_resource(
		effect_dynamic_formula,
		effect_resource_id
	)
	
	effect.set_modifier_id(
		effect_modifier_id
	)
	
	return effect


static func dynamic_generator_modifier(
	effect_target_id: String,
	effect_modifier_type: String,
	effect_value: float,
	effect_generator_id: String,
	effect_dynamic_formula: String,
	effect_modifier_id: String = "",
	effect_modifier_target_id: String = ""
	) -> UpgradeEffect:
	
	var effect = UpgradeEffect.new(
		UpgradeEffectTypes.APPLY_MODIFIER,
		effect_target_id
	)
	
	effect.set_modifier(
		effect_modifier_type,
		effect_value,
		effect_modifier_target_id
	)
	
	effect.set_dynamic_generator(
		effect_dynamic_formula,
		effect_generator_id
	)
	
	effect.set_modifier_id(
		effect_modifier_id
	)
	
	return effect


static func sensitivity(
	effect_target_id: String,
	effect_sensitivity_modifier_id: String,
	effect_sensitivity_multiplier: float
	) -> UpgradeEffect:
	
	var effect = UpgradeEffect.new(
		UpgradeEffectTypes.APPLY_SENSITIVITY,
		effect_target_id
	)
	
	effect.set_modifier_sensitivity(
		effect_sensitivity_modifier_id,
		effect_sensitivity_multiplier
	)
	
	return effect


func set_modifier(
	effect_modifier_type: String,
	effect_value: float,
	effect_modifier_target_id: String = ""
	) -> void:
	
	modifier_type = effect_modifier_type
	value = effect_value
	modifier_target_id = effect_modifier_target_id


func set_dynamic_resource(
	effect_dynamic_formula: String,
	effect_dynamic_resource_id: String
	) -> void:
	
	dynamic_formula = effect_dynamic_formula
	dynamic_resource_id = effect_dynamic_resource_id


func set_dynamic_generator(
	effect_dynamic_formula: String,
	effect_dynamic_generator_id: String
	) -> void:
	
	dynamic_formula = effect_dynamic_formula
	dynamic_generator_id = effect_dynamic_generator_id


func set_modifier_id(
	effect_modifier_id: String
	) -> void:
	
	modifier_id = effect_modifier_id


func set_modifier_sensitivity(
	effect_sensitivity_modifier_id: String,
	effect_sensitivity_multiplier: float
	) -> void:
	
	sensitivity_modifier_id = (
		effect_sensitivity_modifier_id
	)
	
	sensitivity_multiplier = (
		effect_sensitivity_multiplier
	)
