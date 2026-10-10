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

var operation_mode_id: String = "normal"

func _init(generator_definition: GeneratorDefinition) -> void:
	definition = generator_definition
	modifiers = []
	production_progress = {}
	
	if not definition.operation_modes.is_empty():
		operation_mode_id = (
			definition.operation_modes[0].id
		)
	
	for output in get_active_outputs():
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

	operation_mode_id = "normal"

	if not definition.operation_modes.is_empty():
		operation_mode_id = (
			definition.operation_modes[0].id
		)

	# Reset operation-mode unlocks and all input/output unlock states.
	for mode in definition.operation_modes:
		mode.unlocked = mode.initially_unlocked
		for input in mode.inputs:
			input.reset()

		for output in mode.outputs:
			output.reset()

		for output in mode.completion_outputs:
			output.reset()

	# Reset production progress.
	for resource_id in production_progress:
		production_progress[resource_id] = 0.0

	
			
func get_operation_mode() -> GeneratorOperationMode:
	
	for mode in definition.operation_modes:
		if mode.id == operation_mode_id:
			return mode
	
	if definition.operation_modes.is_empty():
		return null
	
	return definition.operation_modes[0]	
		
func set_operation_mode(
	mode_id: String
	) -> bool:
	
	if not can_change_operation_mode():
		return false
	
	for mode in definition.operation_modes:
		if mode.id != mode_id:
			continue
		if not mode.unlocked:
			return false
		
		operation_mode_id = mode.id
		_ensure_discrete_production_progress(mode)
		return true
	
	return false

func _ensure_discrete_production_progress(
	mode: GeneratorOperationMode
	) -> void:
	for output in mode.outputs:
		if not output.discrete:
			continue

		if not production_progress.has(output.resource_id):
			production_progress[output.resource_id] = 0.0

func can_change_operation_mode() -> bool:
	
	# Normal generators can change mode at any time.
	if not definition.cycle_based:
		return true
	
	# Cycle generators lock their mode once a cycle has started.
	return not cycle_active
	
# Returns the maximum production rate this generator could produce
# while operating at full capacity.
func get_production_per_second(
	state: GameState
	) -> Array[GeneratorRate]:
	
	var production_outputs: Array[GeneratorRate] = []
	var operation_mode = get_operation_mode()
	
	for output in get_active_outputs():
		if not output.unlocked:
			continue
		
		var production: float = get_production_rate(
			output,
			state,
			operation_mode
		)
		
		production_outputs.append(
			GeneratorRate.new(
				output.resource_id,
				production,
				output.discrete
			)
		)
	
	return production_outputs


# Calculates one output's production rate without allocating a GeneratorRate.
# The simulation uses this directly to avoid creating temporary objects each step.
func get_production_rate(
	output: GeneratorIO,
	state: GameState,
	operation_mode: GeneratorOperationMode = null
	) -> float:
	
	if operation_mode == null:
		operation_mode = get_operation_mode()
	
	var production: float = output.amount_per_second * level
	
	if operation_mode != null:
		production *= operation_mode.production_multiplier
	
	if output.resource_id == ResourceIds.MATTER:
		production *= state.realm_effects.matter_production_multiplier
	
	if output.resource_id == ResourceIds.HEAT:
		production *= state.realm_effects.heat_production_multiplier
		production *= state.eternal_flame_upgrade_manager.get_effective_multiplier(
			"eternal_furnace",
			state.eternal_flame_state
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
	
	return production

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
	
	var cost = definition.base_cost
	
	var operation_mode = get_operation_mode()
	
	if operation_mode != null:
		cost *= operation_mode.activation_cost_multiplier
	
	cost *= state.realm_effects.generator_cost_multiplier
	
	cost *= pow(
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
	var operation_mode = get_operation_mode()
	
	if operation_mode != null:
		input_per_second *= operation_mode.input_multiplier
	
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
	state: GameState,
	allow_partial_inputs: bool = false
	) -> bool:
	
	if not unlocked:
		return false
	
	if level <= 0:
		return false
	
	if manually_paused:
		return false
	
	if definition.cycle_based and not cycle_active:
		return false
	
	for input in get_active_inputs():
		var input_amount = state.get_resource_amount(
			input.resource_id
		)
		
		var required_input = get_input_consumption_per_second(
			input,
			state
		)
		
		if allow_partial_inputs:
			if required_input > 0.0 and input_amount <= 0.0:
				return false
		elif input_amount < required_input:
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
	
	for input in get_active_inputs():
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
	var cycle_duration = get_cycle_duration()
	
	if cycle_duration <= 0.0:
		return 0.0
	
	return clamp(
		cycle_progress
		/ cycle_duration
		* 100.0,
		0.0,
		100.0
	)

func get_modifier_sensitivity(
	modifier_id: String,
	state: GameState
	) -> float:
	
	var sensitivity = 1.0
	
	for modifier_sensitivity in modifier_sensitivities:
		if modifier_sensitivity.modifier_id != modifier_id:
			continue
		
		sensitivity *= (
			modifier_sensitivity.get_effective_multiplier(
				state
			)
		)
	
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


func get_active_inputs() -> Array[GeneratorIO]:
	return get_operation_mode().inputs

func get_active_outputs() -> Array[GeneratorIO]:
	return get_operation_mode().outputs

func get_active_completion_outputs() -> Array[GeneratorIO]:
	return get_operation_mode().completion_outputs

func get_cycle_duration() -> float:
	return get_operation_mode().cycle_duration

func load_operation_mode(
	mode_id: String
	) -> bool:
	
	for mode in definition.operation_modes:
		if mode.id != mode_id:
			continue
		
		operation_mode_id = mode.id
		_ensure_discrete_production_progress(mode)
		return true
	
	return false
