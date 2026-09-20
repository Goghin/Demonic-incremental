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
	generator_completion_outputs: Array[GeneratorIO] = []
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
