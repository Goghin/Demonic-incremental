class_name GeneratorDefinition
extends RefCounted


var id: String
var display_name: String

var inputs: Array[GeneratorIO]
var outputs: Array[GeneratorIO]
var completion_outputs: Array[GeneratorIO]

var base_cost: float
var cost_multiplier: float
var cost_resource_id: String

var cycle_based: bool
var cycle_duration: float

var operation_modes: Array[GeneratorOperationMode]

var illustration_path: String


func _init(
	generator_id: String,
	generator_name: String,
	generator_inputs: Array[GeneratorIO],
	generator_outputs: Array[GeneratorIO],
	generator_base_cost: float,
	generator_cost_multiplier: float,
	generator_cost_resource_id: String,
	generator_cycle_based: bool = false,
	generator_cycle_duration: float = 0.0,
	generator_completion_outputs: Array[GeneratorIO] = [],
	generator_illustration_path: String = "",
	generator_operation_modes: Array[GeneratorOperationMode] = []
) -> void:
	
	id = generator_id
	display_name = generator_name
	inputs = generator_inputs
	outputs = generator_outputs
	completion_outputs = generator_completion_outputs
	base_cost = generator_base_cost
	cost_multiplier = generator_cost_multiplier
	cost_resource_id = generator_cost_resource_id
	cycle_based = generator_cycle_based
	cycle_duration = generator_cycle_duration
	illustration_path = generator_illustration_path
	
	operation_modes = generator_operation_modes
	
	# Every generator must have at least one operation mode.
	# Existing generators receive a neutral default mode.
	if operation_modes.is_empty():
		operation_modes.append(
			GeneratorOperationMode.new(
				"normal",
				"Normal",
				"Operates at standard efficiency.",
				1.0,
				1.0
			)
		)
