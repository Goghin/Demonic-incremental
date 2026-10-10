class_name Simulation
extends RefCounted

signal generator_unlocked(generator_id: String)
signal crystallization_completed(crystals_created: float)

# Holds the current game state.
var state: GameState

# Optional profiling counters. Disabled during normal gameplay.
var profiling_enabled: bool = false
var profile_totals_usec: Dictionary = {}
var profile_call_counts: Dictionary = {}


func _init(game_state: GameState) -> void:
	state = game_state


func reset_profile() -> void:
	profile_totals_usec.clear()
	profile_call_counts.clear()


func get_profile_report() -> Dictionary:
	return {
		"totals_usec": profile_totals_usec.duplicate(),
		"call_counts": profile_call_counts.duplicate()
	}


func _record_profile_time(section: String, start_usec: int) -> void:
	var elapsed_usec = Time.get_ticks_usec() - start_usec
	profile_totals_usec[section] = (
		int(profile_totals_usec.get(section, 0))
		+ elapsed_usec
	)
	profile_call_counts[section] = (
		int(profile_call_counts.get(section, 0))
		+ 1
	)


# Advance the simulation by the amount of time given by delta.
#
# Continuous generators operate normally.
# Cycle-based generators only operate while a cycle is active.

func update(delta: float, offline_mode: bool = false) -> void:
	#if not state.realm_stabilized:
		#return
	
	var profile_start_usec: int = 0
	var profile_subphase_start_usec: int = 0
	if profiling_enabled:
		profile_start_usec = Time.get_ticks_usec()
	update_automatic_upgrades()
	if profiling_enabled:
		_record_profile_time("automatic_upgrades", profile_start_usec)
	
	# This upgrade multiplier is unchanged during generator processing, so
	# calculate it once per simulation step instead of once per Heat output.
	var heat_upgrade_multiplier: float = (
		state.eternal_flame_upgrade_manager.get_effective_multiplier(
			"eternal_furnace",
			state.eternal_flame_state
		)
	)
	
	if profiling_enabled:
		profile_start_usec = Time.get_ticks_usec()
	for generator in state.generators.values():
		if not generator.unlocked:
			continue
		
		if generator.definition.cycle_based:
			var cycle_start_usec: int = 0
			if profiling_enabled:
				cycle_start_usec = Time.get_ticks_usec()
			update_cycle_generator(
				generator,
				delta,
				offline_mode,
				heat_upgrade_multiplier
			)
			if profiling_enabled:
				_record_profile_time("cycle_generator_processing", cycle_start_usec)
			continue
		
		# Normal continuous generator.
		if not generator.operating:
			var start_check_usec: int = 0
			if profiling_enabled:
				start_check_usec = Time.get_ticks_usec()
			var can_start: bool = generator.can_start_operating(
				state,
				offline_mode
			)
			if profiling_enabled:
				_record_profile_time("generator_start_checks", start_check_usec)
			if can_start:
				generator.operating = true
			else:
				continue
		
		var operating_delta = delta
		if offline_mode:
			var duration_check_usec: int = 0
			if profiling_enabled:
				duration_check_usec = Time.get_ticks_usec()
			operating_delta = _get_available_operating_delta(
				generator,
				delta
			)
			if profiling_enabled:
				_record_profile_time("available_operating_duration", duration_check_usec)
			if operating_delta <= 0.0:
				generator.operating = false
				continue
		else:
			var continue_check_usec: int = 0
			if profiling_enabled:
				continue_check_usec = Time.get_ticks_usec()
			var can_continue: bool = generator.can_continue_operating(
				state,
				delta
			)
			if profiling_enabled:
				_record_profile_time("generator_continue_checks", continue_check_usec)
			if not can_continue:
				generator.operating = false
				continue
		
		if profiling_enabled:
			profile_subphase_start_usec = Time.get_ticks_usec()
		consume_inputs(
			generator,
			operating_delta
		)
		if profiling_enabled:
			_record_profile_time("input_consumption", profile_subphase_start_usec)
		
		if profiling_enabled:
			profile_subphase_start_usec = Time.get_ticks_usec()
		produce_outputs(
			generator,
			operating_delta,
			heat_upgrade_multiplier
		)
		if profiling_enabled:
			_record_profile_time("output_production", profile_subphase_start_usec)
		
		if offline_mode and operating_delta < delta - 0.000001:
			generator.operating = false
	if profiling_enabled:
		_record_profile_time("generator_processing", profile_start_usec)
	
	if profiling_enabled:
		profile_start_usec = Time.get_ticks_usec()
	apply_environmental_effects(delta)
	if profiling_enabled:
		_record_profile_time("environmental_effects", profile_start_usec)
	
	if profiling_enabled:
		profile_start_usec = Time.get_ticks_usec()
	state.generator_automation_manager.update(
		delta,
		self
	)
	if profiling_enabled:
		_record_profile_time("generator_automation", profile_start_usec)
	
	if profiling_enabled:
		profile_start_usec = Time.get_ticks_usec()
	state.upgrade_automation_manager.update(
		delta,
		self
	)
	if profiling_enabled:
		_record_profile_time("upgrade_automation", profile_start_usec)

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
	delta: float,
	offline_mode: bool = false,
	heat_upgrade_multiplier: float = -1.0
	) -> void:
	
	if not generator.cycle_active:
		return
	
	if not generator.operating:
		if generator.can_start_operating(
			state,
			offline_mode
		):
			generator.operating = true
		else:
			return
	
	if offline_mode:
		var cycle_duration = generator.get_cycle_duration()
		var remaining_cycle_time = max(
			cycle_duration - generator.cycle_progress,
			0.0
		)
		var requested_delta = min(
			delta,
			remaining_cycle_time
		)
		var operating_delta = _get_available_operating_delta(
			generator,
			requested_delta
		)
		
		if operating_delta <= 0.0:
			generator.operating = false
			return
		
		consume_inputs(
			generator,
			operating_delta
		)
		produce_outputs(
			generator,
			operating_delta,
			heat_upgrade_multiplier
		)
		generator.cycle_progress += operating_delta
		
		if generator.cycle_progress >= cycle_duration - 0.000001:
			generator.cycle_progress = cycle_duration
			complete_cycle(generator)
		elif operating_delta < requested_delta - 0.000001:
			generator.operating = false
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
	
	var cycle_duration = generator.get_cycle_duration()

	if generator.cycle_progress >= cycle_duration:
		generator.cycle_progress = cycle_duration
		complete_cycle(generator)


# In offline mode, return how much of this step the generator can actually
# operate for before one of its input resources is depleted.
func _get_available_operating_delta(
	generator: Generator,
	requested_delta: float
	) -> float:
	
	var operating_delta = requested_delta
	
	for input in generator.get_active_inputs():
		var input_rate = generator.get_input_consumption_per_second(
			input,
			state
		)
		
		if input_rate <= 0.0:
			continue
		
		var available_input = state.get_resource_amount(
			input.resource_id
		)
		
		if available_input <= 0.0:
			return 0.0
		
		operating_delta = min(
			operating_delta,
			available_input / input_rate
		)
	
	return max(
		operating_delta,
		0.0
	)


func complete_cycle(
	generator: Generator
	) -> void:
	
	for output in generator.get_active_completion_outputs():
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
		
		state.record_resource_produced(
			output.resource_id,
			amount
		)
		
		# Creating Crystallized Flame consumes all accumulated Heat.
		# and triggers the realm crystallization visual.
		if output.resource_id == ResourceIds.CRYSTALIZED_FLAME:
			crystallization_completed.emit(amount)
			
			var current_heat = state.get_resource_amount(
				ResourceIds.HEAT
			)
			
			if current_heat > 0.0:
				state.record_resource_lost(
					ResourceIds.HEAT,
					current_heat
				)
				
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
	
	for input in generator.get_active_inputs():
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
		
		var consumed_input = min(
			required_input,
			input_amount
		)
		
		if consumed_input <= 0.0:
			continue
		
		state.set_resource_amount(
			input.resource_id,
			input_amount - consumed_input
		)
		
		state.record_resource_consumed(
			input.resource_id,
			consumed_input
		)

# Produce outputs for the current simulation step.
func produce_outputs(
	generator: Generator,
	delta: float,
	heat_upgrade_multiplier: float = -1.0
	) -> void:
	
	var operation_mode = generator.get_operation_mode()
	
	for output in generator.get_active_outputs():
		if not output.unlocked:
			continue
		
		var production: float = (
			generator.get_production_rate(
				output,
				state,
				operation_mode,
				heat_upgrade_multiplier
			)
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
				
				state.record_resource_produced(
					output.resource_id,
					whole_units
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
			
			state.record_resource_produced(
				output.resource_id,
				production
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
	
	if generator.definition.cycle_based:
		if generator.cycle_active:
			return false
	
	var cost = generator.get_cost(
		state
	)
	
	var current_resource = state.get_resource_amount(
		generator.definition.cost_resource_id
	)
	
	if current_resource < cost:
		return false
	
	state.set_resource_amount(
		generator.definition.cost_resource_id,
		current_resource - cost
	)
	
	state.record_resource_consumed(
		generator.definition.cost_resource_id,
		cost
	)
	
	generator.level += 1
	
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
	
	if upgrade.is_maxed():
		return false
	
	if not state.upgrade_system.upgrade_exclusivity_available(
		upgrade
	):
		return false
	
	if not state.upgrade_system.requirements_met(
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
	
	state.record_resource_consumed(
		upgrade.definition.cost_resource_id,
		cost
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
	
	if not state.upgrade_system.upgrade_exclusivity_available(
		upgrade
	):
		return false
	
	if not state.upgrade_system.requirements_met(
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
			if not generator.unlocked:
				generator.unlocked = true
				generator_unlocked.emit(
					generator.definition.id
				)
				
	elif effect.type == UpgradeEffectTypes.UNLOCK_OUTPUT:
		var generator = state.get_generator(
			effect.target_id
		)
		
		if generator != null:
			for mode in generator.definition.operation_modes:
				for output in mode.outputs:
					if output.resource_id != effect.output_resource_id:
						continue
					
					output.unlocked = true
				
	elif effect.type == UpgradeEffectTypes.UNLOCK_OPERATION_MODE:
		var generator = state.get_generator(
			effect.target_id
		)
		if generator != null:
			for mode in generator.definition.operation_modes:
				if mode.id == effect.operation_mode_id:
					mode.unlocked = true
					break
			
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
	elif effect.type == UpgradeEffectTypes.MODIFY_DORMANCY:
		_apply_dormancy_effect(
			effect
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
		modifier.dynamic_threshold = effect.dynamic_threshold
		modifier.dynamic_exponent = effect.dynamic_exponent
		
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
	
	if effect.sensitivity_dynamic_formula != "":
		sensitivity.dynamic = true
		sensitivity.dynamic_formula = (
			effect.sensitivity_dynamic_formula
		)
		sensitivity.dynamic_resource_id = (
			effect.sensitivity_dynamic_resource_id
		)
	
	generator.modifier_sensitivities.append(
		sensitivity
	)


func rebuild_upgrade_effects() -> void:
	state.reset_lava_mite_dormancy_parameters()
	
	for generator in state.get_generators().values():
		generator.modifiers.clear()
		generator.modifier_sensitivities.clear()
		for mode in generator.definition.operation_modes:
			mode.unlocked = mode.initially_unlocked
	
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
		
		if not state.upgrade_system.requirements_met(
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


func apply_heat_leak(
	delta: float
	) -> void:
	var overflow_rate = state.get_heat_leak_per_second()

	if overflow_rate <= 0.0:
		return

	var heat = state.get_resource_amount(
		ResourceIds.HEAT
	)

	var overflow_amount = min(
		overflow_rate * delta,
		heat
	)

	if overflow_amount <= 0.0:
		return

	state.set_resource_amount(
		ResourceIds.HEAT,
		heat - overflow_amount
	)

	state.record_resource_lost(
		ResourceIds.HEAT,
		overflow_amount
	)

	var crystallized_flames = state.get_resource_amount(
		ResourceIds.CRYSTALIZED_FLAME
	)

	var overflow_multiplier = pow(
		1.25,
		crystallized_flames
	)

	var recorded_overflow = (
		overflow_amount * overflow_multiplier
	)

	state.total_overflow_this_prestige += recorded_overflow

	state.resource_statistics.record_overflow(
		recorded_overflow
	)

	state.current_run_statistics.record_overflow(
		recorded_overflow
	)
	
	if state.simulation_statistics != null:
		state.simulation_statistics.record_overflow(
			recorded_overflow
		)
		
func apply_matter_decay(
	delta: float
	) -> void:
	
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
	
	state.record_resource_lost(
		ResourceIds.MATTER,
		decayed_matter
	)
	
	var heat = state.get_resource_amount(
		ResourceIds.HEAT
	)
	
	state.set_resource_amount(
		ResourceIds.HEAT,
		heat + decayed_matter
	)
	
	state.record_resource_produced(
		ResourceIds.HEAT,
		decayed_matter
	)
	if state.simulation_statistics != null:
		state.simulation_statistics.record_produced(
		ResourceIds.HEAT,
		decayed_matter
	)
func _apply_dormancy_effect(
	effect: UpgradeEffect
	) -> void:
	
	if effect.dormancy_parameter == (
		UpgradeEffect.DORMANCY_DELAY
	):
		state.lava_mite_dormancy_delay += (
			effect.dormancy_value
		)
	
	elif effect.dormancy_parameter == (
		UpgradeEffect.DORMANCY_DURATION
	):
		state.lava_mite_dormancy_duration += (
			effect.dormancy_value
		)
	
	elif effect.dormancy_parameter == (
		UpgradeEffect.DORMANCY_MAX_PENALTY
	):
		state.lava_mite_dormancy_max_penalty = clamp(
			state.lava_mite_dormancy_max_penalty
			+ effect.dormancy_value,
			0.0,
			0.99
		)
