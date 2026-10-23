class_name GeneratorOperationMode
extends RefCounted


var id: String
var display_name: String
var description: String

var production_multiplier: float
var input_multiplier: float
var activation_cost_multiplier: float

var cycle_duration: float
var inputs: Array[GeneratorIO]
var outputs: Array[GeneratorIO]
var completion_outputs: Array[GeneratorIO]
# Non-resource inventory rewards granted once when a cycle completes.
var completion_item_outputs: Array[Dictionary]
# Each entry describes one visible machine input slot and its accepted ingredients.
# Supported keys can include item_id, relic, item_type, and quantity.
var crafting_input_requirements: Array[Dictionary]

var initially_unlocked: bool = true
var unlocked: bool = true
var is_resource_transfer: bool = false


func _init(
	mode_id: String,
	mode_display_name: String,
	mode_description: String,
	mode_production_multiplier: float = 1.0,
	mode_input_multiplier: float = 1.0,
	mode_activation_cost_multiplier: float = 1.0,
	mode_cycle_duration: float = 0.0,
	mode_inputs: Array[GeneratorIO] = [],
	mode_outputs: Array[GeneratorIO] = [],
	mode_completion_outputs: Array[GeneratorIO] = [],
	mode_is_resource_transfer: bool = false,
	mode_completion_item_outputs: Array[Dictionary] = [],
	mode_crafting_input_requirements: Array[Dictionary] = []
	) -> void:
	
	id = mode_id
	display_name = mode_display_name
	description = mode_description
	
	production_multiplier = mode_production_multiplier
	input_multiplier = mode_input_multiplier
	activation_cost_multiplier = mode_activation_cost_multiplier
	
	cycle_duration = mode_cycle_duration
	inputs = mode_inputs
	outputs = mode_outputs
	completion_outputs = mode_completion_outputs
	is_resource_transfer = mode_is_resource_transfer
	completion_item_outputs = mode_completion_item_outputs
	crafting_input_requirements = mode_crafting_input_requirements
