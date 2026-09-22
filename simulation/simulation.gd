class_name Simulation
extends RefCounted


# Holds the current game state.
var state: GameState


func _init(game_state: GameState) -> void:
	state = game_state


# Advance the simulation by the amount of time given by delta.
#
# Continuous generators operate normally.
# Cycle-based generators only operate while a cycle is active.
func update(delta: float) -> void:
	
	update_automatic_upgrades()
	
	for generator in state.generators.values():
		if not generator.unlocked:
			continue
		
		if generator.definition.cycle_based:
			update_cycle_generator(
				generator,
				delta
			)
			continue
		
		# Normal continuous generator.
		if not generator.operating:
			if generator.can_start_operating(state):
				generator.operating = true
			else:
				continue

		if not generator.can_continue_operating(
			state,
			delta
		):
			generator.operating = false
			continue

		consume_inputs(
			generator,
			delta
		)

		produce_outputs(
			generator,
			delta
		)
	
	apply_environmental_effects(delta)


func apply_environmental_effects(delta: float) -> void:
	apply_matter_decay(delta)
	apply_heat_leak(delta)
# Process one simulation step for a cycle-based generator.
#
# A cycle only progresses when all required inputs are available.
# Inputs and normal outputs operate exactly like they do for
# continuous generators while the cycle is active.
func update_cycle_generator(
	generator: Generator,
	delta: float
	) -> void:
	
	if not generator.cycle_active:
		return
	
	if not generator.operating:
		if generator.can_start_operating(state):
			generator.operating = true
		else:
			return
	
	if not generator.can_continue_operating(
		state,
		delta
	):
		generator.operating = false
		return
	
	# Consume any inputs used during the cycle.
	consume_inputs(
		generator,
		delta
	)
	
	# Produce any normal outputs generated during the cycle.
	produce_outputs(
		generator,
		delta
	)
	
	# Advance cycle progress.
	generator.cycle_progress += delta
	
	if generator.cycle_progress >= generator.definition.cycle_duration:
		generator.cycle_progress = generator.definition.cycle_duration
		complete_cycle(generator)


# Complete an active cycle.
#
# Completion outputs are produced here, after the cycle has
# successfully reached its duration.
func complete_cycle(generator: Generator) -> void:
	for output in generator.definition.completion_outputs:
		var amount = (
			output.amount_per_second
			* generator.level
		)
		
		for modifier in generator.modifiers:
			if modifier.applies_to(
				ModifierTypes.PRODUCTION,
				output.resource_id
			):
				amount = modifier.apply(
					amount,
					state,
					generator
				)
		
		var current_amount = state.get_resource_amount(
			output.resource_id
		)
		
		state.set_resource_amount(
			output.resource_id,
			current_amount + amount
		)
		
		# Creating Crystallized Flame consumes all accumulated Heat.
		if output.resource_id == ResourceIds.CRYSTALIZED_FLAME:
			state.set_resource_amount(
				ResourceIds.HEAT,
				0.0
			)
	
	generator.cycle_active = false
	generator.operating = false
	generator.cycle_progress = 0.0


# Consume the inputs required for the current simulation step.
func consume_inputs(
	generator: Generator,
	delta: float
	) -> void:
	
	for input in generator.definition.inputs:
		var input_amount = state.get_resource_amount(
			input.resource_id
		)
		
		var input_per_second = (
			generator.get_input_consumption_per_second(
				input,
				state
			)
		)
		
		var required_input = (
			input_per_second
			* delta
		)
		
		state.set_resource_amount(
			input.resource_id,
			input_amount - required_input
		)


# Produce outputs for the current simulation step.
func produce_outputs(
	generator: Generator,
	delta: float
	) -> void:
	
	var production_outputs = generator.get_production_per_second(
		state
	)
	
	for output in production_outputs:
		var production = (
			output.amount_per_second
			* delta
		)
		
		if output.discrete:
			var progress = generator.get_production_progress(
				output.resource_id
			)
			
			progress += production
			
			var whole_units = floor(progress)
			
			if whole_units > 0:
				var current_amount = state.get_resource_amount(
					output.resource_id
				)
				
				state.set_resource_amount(
					output.resource_id,
					current_amount + whole_units
				)
				
				progress -= whole_units
			
			generator.set_production_progress(
				output.resource_id,
				progress
			)
		else:
			var current_amount = state.get_resource_amount(
				output.resource_id
			)
			
			state.set_resource_amount(
				output.resource_id,
				current_amount + production
			)


func rub() -> void:
	var amount = 10.0
	
	var current_heat = state.get_resource_amount(
		ResourceIds.HEAT
	)
	
	state.set_resource_amount(
		ResourceIds.HEAT,
		current_heat + amount
	)


func buy_generator(
	generator_id: String
	) -> bool:
	
	var generator = state.get_generator(
		generator_id
	)
	
	if generator == null:
		return false
	
	if not generator.unlocked:
		return false
	
	# A cycle-based generator cannot be purchased again
	# while it is currently processing.
	if generator.definition.cycle_based:
		if generator.cycle_active:
			return false
	
	var cost = generator.get_cost(state)
	
	var current_resource = state.get_resource_amount(
		generator.definition.cost_resource_id
	)
	
	if current_resource < cost:
		return false
	
	state.set_resource_amount(
		generator.definition.cost_resource_id,
		current_resource - cost
	)
	
	generator.level += 1
	
	# Purchasing a level starts a cycle for cycle-based generators.
	if generator.definition.cycle_based:
		generator.cycle_progress = 0.0
		generator.cycle_active = true
	
	return true


func can_buy_generator(
	generator_id: String
	) -> bool:
	
	var generator = state.get_generator(
		generator_id
	)
	
	if generator == null:
		return false
	
	if not generator.unlocked:
		return false
	
	if generator.definition.cycle_based:
		if generator.cycle_active:
			return false
	
	var current_resource = state.get_resource_amount(
		generator.definition.cost_resource_id
	)
	
	return generator.can_afford(
		current_resource,
		state
	)


# -------------------------------------------------------------------
# Upgrades
# -------------------------------------------------------------------

func buy_upgrade(
	upgrade_id: String
	) -> bool:
	
	var upgrade = state.get_upgrade(
		upgrade_id
	)
	
	if upgrade == null:
		return false
	
	# The upgrade has reached its maximum level.
	if upgrade.is_maxed():
		return false
	
	# A levelled upgrade may not switch into an exclusivity
	# group that has already been claimed by another upgrade.
	if not state.upgrade_exclusivity_available(
		upgrade
	):
		return false
	
	if not state.requirements_met(
		upgrade.definition.requirements
	):
		return false
	
	var cost = get_upgrade_cost(
		upgrade
	)
	
	var current_resource = state.get_resource_amount(
		upgrade.definition.cost_resource_id
	)
	
	if current_resource < cost:
		return false
	
	state.set_resource_amount(
		upgrade.definition.cost_resource_id,
		current_resource - cost
	)
	
	upgrade.level += 1
	
	_apply_upgrade_level_effects(
		upgrade
	)
	
	return true


func can_buy_upgrade(
	upgrade_id: String
	) -> bool:
	
	var upgrade = state.get_upgrade(
		upgrade_id
	)
	
	if upgrade == null:
		return false
	
	if upgrade.is_maxed():
		return false
	
	if not state.upgrade_exclusivity_available(
		upgrade
	):
		return false
	
	if not state.requirements_met(
		upgrade.definition.requirements
	):
		return false
	
	var cost = get_upgrade_cost(
		upgrade
	)
	
	var current_resource = state.get_resource_amount(
		upgrade.definition.cost_resource_id
	)
	
	return current_resource >= cost


func get_upgrade_cost(
	upgrade: Upgrade
	) -> float:
	
	var level = upgrade.level
	
	return (
		upgrade.definition.cost
		* pow(
			upgrade.definition.cost_multiplier,
			level
		)
	)


# Apply the effects associated with the upgrade's new level.
#
# For now, an effect is applied once per upgrade level.
# This gives us a simple foundation for levelled upgrades.
# Individual effect scaling can be made more sophisticated later.
func _apply_upgrade_level_effects(
	upgrade: Upgrade
	) -> void:
	
	for effect in upgrade.definition.effects:
		_apply_upgrade_effect(
			effect,
			upgrade.definition.id
		)


func _apply_upgrade_effect(
	effect: UpgradeEffect,
	source_upgrade_id: String
	) -> void:
	
	if effect.type == UpgradeEffectTypes.UNLOCK_GENERATOR:
		var generator = state.get_generator(
			effect.target_id
		)
		
		if generator != null:
			generator.unlocked = true
	
	elif effect.type == UpgradeEffectTypes.APPLY_MODIFIER:
		if effect.target_id == "":
			for generator in state.get_generators().values():
				_add_modifier_to_generator(
					generator,
					effect,
					source_upgrade_id
				)
		else:
			var generator = state.get_generator(
				effect.target_id
			)
			
			if generator != null:
				_add_modifier_to_generator(
					generator,
					effect,
					source_upgrade_id
				)
	
	elif effect.type == UpgradeEffectTypes.APPLY_SENSITIVITY:
		if effect.target_id == "":
			for generator in state.get_generators().values():
				_add_modifier_sensitivity_to_generator(
					generator,
					effect,
					source_upgrade_id
				)
		else:
			var generator = state.get_generator(
				effect.target_id
			)
			
			if generator != null:
				_add_modifier_sensitivity_to_generator(
					generator,
					effect,
					source_upgrade_id
				)


func _add_modifier_to_generator(
	generator: Generator,
	effect: UpgradeEffect,
	source_upgrade_id: String
	) -> void:
	
	var modifier = Modifier.new(
		effect.modifier_type,
		effect.modifier_target_id,
		effect.value
	)
	
	modifier.id = effect.modifier_id
	modifier.source_upgrade_id = source_upgrade_id
	
	if effect.dynamic_formula != "":
		modifier.dynamic = true
		modifier.dynamic_formula = effect.dynamic_formula
		modifier.dynamic_resource_id = effect.dynamic_resource_id
		modifier.dynamic_generator_id = effect.dynamic_generator_id
	
	generator.modifiers.append(modifier)


func _add_modifier_sensitivity_to_generator(
	generator: Generator,
	effect: UpgradeEffect,
	source_upgrade_id: String
	) -> void:
	
	var sensitivity = ModifierSensitivity.new(
		effect.sensitivity_modifier_id,
		effect.sensitivity_multiplier,
		source_upgrade_id
	)
	
	generator.modifier_sensitivities.append(
		sensitivity
	)


func rebuild_upgrade_effects() -> void:
	for generator in state.get_generators().values():
		generator.modifiers.clear()
		generator.modifier_sensitivities.clear()
	
	for upgrade in state.upgrades.values():
		if not upgrade.is_purchased():
			continue
		
		# Rebuild every level that the player owns.
		for level in range(upgrade.level):
			for effect in upgrade.definition.effects:
				_apply_upgrade_effect(
					effect,
					upgrade.definition.id
				)


func update_automatic_upgrades() -> void:
	for upgrade in state.upgrades.values():
		if not upgrade.definition.automatic:
			continue
		
		if upgrade.is_maxed():
			continue
		
		if not state.requirements_met(
			upgrade.definition.requirements
		):
			continue
		
		upgrade.level += 1
		
		_apply_upgrade_level_effects(
			upgrade
		)


func toggle_generator_pause(
	generator_id: String
	) -> void:
	
	var generator = state.get_generator(
		generator_id
	)
	
	if generator == null:
		return
	
	generator.manually_paused = (
		not generator.manually_paused
	)
	
	if generator.manually_paused:
		generator.operating = false


func apply_heat_leak(delta: float) -> void:
	var leak_per_second = state.get_heat_leak_per_second()
	
	if leak_per_second <= 0.0:
		return
	
	var heat = state.get_resource_amount(
		ResourceIds.HEAT
	)
	
	var leaked_heat = leak_per_second * delta
	
	state.set_resource_amount(
		ResourceIds.HEAT,
		max(
			heat - leaked_heat,
			0.0
		)
	)

func apply_matter_decay(delta: float) -> void:
	var decay_per_second = state.get_matter_decay_per_second()
	
	if decay_per_second <= 0.0:
		return
	
	var matter = state.get_resource_amount(
		ResourceIds.MATTER
	)
	
	var decayed_matter = min(
		decay_per_second * delta,
		matter
	)
	
	if decayed_matter <= 0.0:
		return
	
	state.set_resource_amount(
		ResourceIds.MATTER,
		matter - decayed_matter
	)
	
	var heat = state.get_resource_amount(
		ResourceIds.HEAT
	)
	
	state.set_resource_amount(
		ResourceIds.HEAT,
		heat + decayed_matter
	)
