
class_name Generator
extends RefCounted


var definition: GeneratorDefinition
var level: int = 0
var modifiers: Array[Modifier] = []
var modifier_sensitivities: Array = []
var production_progress: Dictionary = {}
var initial_unlocked: bool = true
var unlocked: bool = true
var manually_paused: bool = false
var operating: bool = false

var cycle_active: bool = false
var cycle_progress: float = 0.0


func _init(generator_definition: GeneratorDefinition) -> void:
	definition = generator_definition
	modifiers = []
	production_progress = {}
	
	for output in definition.outputs:
		if output.discrete:
			production_progress[output.resource_id] = 0.0



func reset() -> void:
	level = 0
	modifiers.clear()
	modifier_sensitivities.clear()
	
	unlocked = initial_unlocked
	manually_paused = false
	operating = false
	
	cycle_active = false
	cycle_progress = 0.0
	
	for resource_id in production_progress:
		production_progress[resource_id] = 0.0
		
		
# Returns the maximum production rate this generator could produce
# while operating at full capacity.
func get_production_per_second(
	state: GameState
	) -> Array[GeneratorRate]:
	
	var production_outputs: Array[GeneratorRate] = []
	
	for output in definition.outputs:
		var production = (
			output.amount_per_second
			* level
		)
		
		if output.resource_id == ResourceIds.MATTER:
			production *= (
			1.0
			+ 0.05 * state.realm_configuration.density
			+ 0.01 * state.get_unassigned_eternal_flames()
		)

		if output.resource_id == ResourceIds.HEAT:
			production *= (
			1.0
			+ 0.05 * state.realm_configuration.intensity
			+ 0.01 * state.get_unassigned_eternal_flames()
		)
			production *= (
				state.eternal_flame_upgrade_manager.get_effective_multiplier(
				"eternal_furnace",
				state.eternal_flame_state
			)
	)
		
		for modifier in modifiers:
			if modifier.applies_to(
				ModifierTypes.PRODUCTION,
				output.resource_id
			):
				production = modifier.apply(
					production,
					state,
					self
				)
		
		production_outputs.append(
			GeneratorRate.new(
				output.resource_id,
				production,
				output.discrete
			)
		)
	
	return production_outputs


func get_cost(state: GameState) -> float:
	var scaling = definition.cost_multiplier
	
	for modifier in modifiers:
		if modifier.applies_to(
			ModifierTypes.COST_SCALING,
			definition.id
		):
			scaling = modifier.apply(
				scaling,
				state,
				self
			)
	
	var cost = definition.base_cost * pow(
		scaling,
		level
	)
	
	for modifier in modifiers:
		if modifier.applies_to(
			ModifierTypes.COST,
			definition.cost_resource_id
		):
			cost = modifier.apply(
				cost,
				state,
				self
			)
	
	return cost


func can_afford(
	current_resource_amount: float,
	state: GameState
	) -> bool:
	
	return current_resource_amount >= get_cost(state)


# Returns the maximum input consumption rate for one level
# of this generator after INPUT_DRAW modifiers.
func get_input_rate(
	input: GeneratorIO,
	state: GameState
	) -> float:
	
	var input_per_second = input.amount_per_second
	
	for modifier in modifiers:
		if modifier.applies_to(
			ModifierTypes.INPUT_DRAW,
			input.resource_id
		):
			input_per_second = modifier.apply(
				input_per_second,
				state,
				self
			)
	
	return input_per_second


# Returns the actual input consumption rate for this generator,
# including its current level and INPUT_DRAW modifiers.
func get_input_consumption_per_second(
	input: GeneratorIO,
	state: GameState
	) -> float:
	
	return (
		get_input_rate(
			input,
			state
		)
		* level
	)


# Determines whether this generator is currently capable of operating.
#
# A generator must:
# - be unlocked
# - have at least one level
# - have an active cycle if it is cycle-based
# - have enough of every input resource for one full second
#   of operation
func can_start_operating(
	state: GameState
	) -> bool:
	
	if not unlocked:
		return false
	
	if level <= 0:
		return false
	
	if manually_paused:
		return false
	
	if definition.cycle_based and not cycle_active:
		return false
	
	for input in definition.inputs:
		var input_amount = state.get_resource_amount(
			input.resource_id
		)
		
		var required_input = get_input_consumption_per_second(
			input,
			state
		)
		
		if input_amount < required_input:
			return false
	
	return true


func can_continue_operating(
	state: GameState,
	delta: float
	) -> bool:
	
	if not operating:
		return false
	
	if manually_paused:
		return false
	
	for input in definition.inputs:
		var input_amount = state.get_resource_amount(
			input.resource_id
		)
		
		var required_input = (
			get_input_consumption_per_second(
				input,
				state
			)
			* delta
		)
		
		if input_amount < required_input:
			return false
	
	return true
	
	
# Returns true when the generator is actually operating right now.
#
# This is intentionally based on can_operate() so the simulation,
# statistics and UI all use the same definition of "operating".
func is_operating() -> bool:
	return operating
	

func get_production_progress(
	resource_id: String
	) -> float:
	
	return production_progress.get(
		resource_id,
		0.0
	)


func set_production_progress(
	resource_id: String,
	progress: float
	) -> void:
	
	production_progress[resource_id] = progress


func get_cycle_progress_percent() -> float:
	if definition.cycle_duration <= 0.0:
		return 0.0
	
	return clamp(
		cycle_progress
		/ definition.cycle_duration
		* 100.0,
		0.0,
		100.0
	)


func get_modifier_sensitivity(
	modifier_id: String
	) -> float:
	
	var sensitivity = 1.0
	
	for modifier_sensitivity in modifier_sensitivities:
		if modifier_sensitivity.modifier_id != modifier_id:
			continue
		
		sensitivity *= modifier_sensitivity.multiplier
	
	return sensitivity


func get_status() -> String:
	
	if not unlocked:
		return "Locked"
	
	if level <= 0:
		return "Inactive"
	
	if manually_paused:
		return "Paused"
	
	if definition.cycle_based:
		if not cycle_active:
			return "Idle"
	
	if operating:
		if definition.cycle_based:
			return "Processing"
		
		return "Operating"
	
	return "Waiting for input"
