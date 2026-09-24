class_name EternalFlameUpgrade
extends RefCounted


const EFFECT_NONE = ""
const EFFECT_HEAT_PRODUCTION = "heat_production"
const EFFECT_ASSIGNED_FLAME = "assigned_flame"
const EFFECT_UNASSIGNED_FLAME = "unassigned_flame"


var id: String = ""
var display_name: String = ""
var description: String = ""

var effect_type: String = EFFECT_NONE
var effect_per_level: float = 0.0

var level: int = 0
var max_level: int = 1

var base_cost: int = 1
var cost_multiplier: float = 1.0


func _init(
	upgrade_id: String,
	upgrade_display_name: String,
	upgrade_description: String,
	upgrade_effect_type: String,
	upgrade_effect_per_level: float,
	upgrade_max_level: int,
	upgrade_base_cost: int,
	upgrade_cost_multiplier: float
	) -> void:
	
	id = upgrade_id
	display_name = upgrade_display_name
	description = upgrade_description
	
	effect_type = upgrade_effect_type
	effect_per_level = upgrade_effect_per_level
	
	max_level = upgrade_max_level
	base_cost = upgrade_base_cost
	cost_multiplier = upgrade_cost_multiplier


func is_maxed() -> bool:
	return level >= max_level


func get_cost() -> int:
	if is_maxed():
		return 0
	
	return int(
		ceil(
			base_cost
			* pow(
				cost_multiplier,
				level
			)
		)
	)


func get_next_level() -> int:
	return level + 1
