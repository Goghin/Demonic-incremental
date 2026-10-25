class_name GeneratorDefinition
extends RefCounted


var id: String
var display_name: String

var base_cost: float
var cost_multiplier: float
var cost_resource_id: String

var cycle_based: bool

var operation_modes: Array[GeneratorOperationMode]

var illustration_path: String

# Optional independent level progression for machines whose levels are upgraded
# separately from their operating cycles.
var starting_level: int = 0
var scale_rates_with_level: bool = true
var level_upgrade_enabled: bool = false
var level_upgrade_resource_id: String = ""
var level_upgrade_base_cost: float = 0.0
var level_upgrade_cost_multiplier: float = 1.0
var level_upgrade_max_level: int = 0
var level_critical_chance_bonus: float = 0.0
var level_critical_chance_cap: float = 1.0


func _init(
	generator_id: String,
	generator_name: String,
	generator_base_cost: float,
	generator_cost_multiplier: float,
	generator_cost_resource_id: String,
	generator_cycle_based: bool = false,
	generator_illustration_path: String = "",
	generator_operation_modes: Array[GeneratorOperationMode] = []
	) -> void:
	
	id = generator_id
	display_name = generator_name
	
	base_cost = generator_base_cost
	cost_multiplier = generator_cost_multiplier
	cost_resource_id = generator_cost_resource_id
	
	cycle_based = generator_cycle_based
	
	illustration_path = generator_illustration_path
	
	operation_modes = generator_operation_modes
	
	assert(
		not operation_modes.is_empty(),
		"GeneratorDefinition '%s' must have at least one operation mode." % id
	)
