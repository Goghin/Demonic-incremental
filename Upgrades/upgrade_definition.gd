class_name UpgradeDefinition
extends RefCounted


var id: String
var display_name: String
var description: String
var cost_resource_id: String
var cost: float
var cost_multiplier: float
var max_level: int
var effects: Array[UpgradeEffect]
var requirements: Array[Requirement]
var automatic: bool
var exclusivity_group: String
var upgrade_group_id: String
var generator_id: String
var technology_id: String


func _init(
	upgrade_id: String,
	upgrade_name: String,
	upgrade_description: String,
	upgrade_cost_resource_id: String,
	upgrade_cost: float,
	upgrade_effects: Array[UpgradeEffect],
	upgrade_requirements: Array[Requirement] = [],
	upgrade_automatic: bool = false,
	upgrade_exclusivity_group: String = "",
	upgrade_ui_group_id: String = "",
	upgrade_max_level: int = 1,
	upgrade_cost_multiplier: float = 1.0,
	upgrade_generator_id: String = "",
	upgrade_technology_id: String = ""
	) -> void:
	
	id = upgrade_id
	display_name = upgrade_name
	description = upgrade_description
	cost_resource_id = upgrade_cost_resource_id
	cost = upgrade_cost
	effects = upgrade_effects
	requirements = upgrade_requirements
	automatic = upgrade_automatic
	exclusivity_group = upgrade_exclusivity_group
	upgrade_group_id = upgrade_ui_group_id
	max_level = upgrade_max_level
	cost_multiplier = upgrade_cost_multiplier
	generator_id = upgrade_generator_id
	technology_id = upgrade_technology_id
