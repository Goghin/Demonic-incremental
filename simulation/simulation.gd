class_name Simulation
extends RefCounted

signal generator_unlocked(generator_id: String)
signal crystallization_completed(crystals_created: float)
signal critical_crystallization_completed(crystals_created: float)
signal generator_level_reduced(generator_id: String, previous_level: int, new_level: int)

const GAMEPLAY_SNAPSHOT_INTERVAL: float = 30.0
var _gameplay_snapshot_elapsed: float = 0.0
var _gameplay_was_offline: bool = false
var _gameplay_snapshot_realm_run_index: int = -1

# Holds the current game state.
var state: GameState

# Optional profiling counters. Disabled during normal gameplay.
var profiling_enabled: bool = false
var profile_totals_usec: Dictionary = {}
var profile_call_counts: Dictionary = {}

# Optional benchmark-only event trace used to locate timestep-dependent progression.
var diagnostics_enabled: bool = false
var diagnostic_time_seconds: float = 0.0
var diagnostic_events: Array[Dictionary] = []


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


func _record_diagnostic_event(
	event_type: String,
	event_id: String,
	level: int,
	source: String
) -> void:
	if not diagnostics_enabled:
		return
	diagnostic_events.append({
		"time": diagnostic_time_seconds,
		"type": event_type,
		"id": event_id,
		"level": level,
		"source": source
	})


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
	state.track_gameplay_interval_statistics = not offline_mode
	if _gameplay_snapshot_realm_run_index != state.gameplay_realm_run_index:
		_gameplay_snapshot_elapsed = 0.0
		_gameplay_snapshot_realm_run_index = state.gameplay_realm_run_index
		state.take_gameplay_interval_statistics()

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

		_update_lava_mite_throttle_state(generator)
		
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
		
		var operation_mode = generator.get_operation_mode()
		var resource_transfer_mode: bool = (
			operation_mode != null
			and operation_mode.is_resource_transfer
		)
		var operating_delta = delta
		if offline_mode or resource_transfer_mode:
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
		
		if (offline_mode or resource_transfer_mode) and operating_delta < delta - 0.000001:
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

	# Keep periodic economy snapshots out of offline catch-up processing.
	# Offline simulation can advance by hours in a single call and should not
	# flood the log with hundreds of historical snapshots.
	if not offline_mode:
		if _gameplay_was_offline:
			# Start a clean measurement interval after offline catch-up.
			_gameplay_snapshot_elapsed = 0.0
			state.take_gameplay_interval_statistics()
		_gameplay_was_offline = false
		_gameplay_snapshot_elapsed += delta
		if _gameplay_snapshot_elapsed >= GAMEPLAY_SNAPSHOT_INTERVAL:
			_gameplay_snapshot_elapsed = fmod(
				_gameplay_snapshot_elapsed,
				GAMEPLAY_SNAPSHOT_INTERVAL
			)
			_record_gameplay_economy_snapshot()
	elif not _gameplay_was_offline:
		# Offline gains are reflected in resource balances, but are not mixed
		# into a snapshot labelled as a 30-second active-play interval.
		_gameplay_snapshot_elapsed = 0.0
		state.take_gameplay_interval_statistics()
		_gameplay_was_offline = true


func _record_gameplay_economy_snapshot() -> void:
	if state.gameplay_log == null:
		return

	var resources_snapshot: Dictionary = {}
	for resource_id in state.resources:
		var resource_state = state.resources[resource_id]
		resources_snapshot[resource_id] = {
			"name": resource_state.definition.display_name,
			"amount": state.get_resource_amount(resource_id)
		}

	var generators_snapshot: Dictionary = {}
	for generator_id in state.generators:
		var generator = state.generators[generator_id]
		if not generator.unlocked:
			continue
		generators_snapshot[generator_id] = {
			"level": generator.level,
			"operating": generator.operating,
			"cycle_active": generator.cycle_active
		}

	state.gameplay_log.record_event(
		"economy",
		"economy_snapshot",
		{
			"interval_seconds": GAMEPLAY_SNAPSHOT_INTERVAL,
			"realm_run_index": state.gameplay_realm_run_index,
			"resources": resources_snapshot,
			"interval_statistics": state.take_gameplay_interval_statistics(),
			"heat_leak_per_second": state.get_heat_leak_per_second(),
			"matter_decay_per_second": state.get_matter_decay_per_second(),
			"total_overflow_this_prestige": state.total_overflow_this_prestige,
			"crystallized_flame": state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME),
			"realm_layout_id": state.realm_layout_id,
			"generators": generators_snapshot
		},
		"periodic"
	)


func apply_environmental_effects(delta: float) -> void:
	apply_matter_decay(delta)
	apply_heat_leak(delta)

# Select the Lava Mite Colony's base-input fallback before its operating
# checks. Use a fixed one-second Ash reserve so throttling does not change
# merely because offline simulation uses a larger timestep.
func _update_lava_mite_throttle_state(
	generator: Generator
	) -> void:
	if generator.definition.id != "lava_mite_colony":
		generator.is_throttled = false
		return

	if generator.is_throttled:
		if _has_normal_lava_mite_input_reserve(generator):
			generator.is_throttled = false
		return

	if _normal_lava_mite_inputs_exceed_available_resources(generator):
		generator.is_throttled = true


# Recovery hysteresis: require one full second of normal-rate inputs
# before leaving throttled mode.
func _has_normal_lava_mite_input_reserve(
	generator: Generator
	) -> bool:
	for input in generator.get_active_inputs():
		var normal_rate := generator.get_input_consumption_per_second(
			input,
			state,
			false
		)
		if state.get_resource_amount(input.resource_id) < normal_rate:
			return false
	return true


func _normal_lava_mite_inputs_exceed_available_resources(
	generator: Generator
	) -> bool:
	for input in generator.get_active_inputs():
		var normal_rate := generator.get_input_consumption_per_second(
			input,
			state,
			false
		)
		var throttled_rate := generator.get_input_consumption_per_second(
			input,
			state,
			true
		)
		if normal_rate <= throttled_rate:
			continue

		# Match the one-second reserve used when recovering from
		# throttling. The threshold must not depend on simulation step size.
		var required_input := normal_rate
		if required_input > state.get_resource_amount(input.resource_id):
			return true
	return false

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
		var offline_cycle_duration = generator.get_cycle_duration()
		var remaining_cycle_time = max(
			offline_cycle_duration - generator.cycle_progress,
			0.0
		)
		var cycle_speed_multiplier := _get_cycle_speed_multiplier(generator)
		var time_to_complete := delta
		if cycle_speed_multiplier > 0.0:
			time_to_complete = remaining_cycle_time / cycle_speed_multiplier
		var requested_delta = min(
			delta,
			time_to_complete
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
		generator.cycle_progress += _get_cycle_progress_delta(generator, operating_delta)
		
		if generator.cycle_progress >= offline_cycle_duration - 0.000001:
			generator.cycle_progress = offline_cycle_duration
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
	generator.cycle_progress += _get_cycle_progress_delta(generator, delta)
	
	var cycle_duration = generator.get_cycle_duration()

	if generator.cycle_progress >= cycle_duration:
		generator.cycle_progress = cycle_duration
		complete_cycle(generator)


# In offline mode, return how much of this step the generator can actually
# operate for before one of its input resources is depleted.
func _get_cycle_speed_multiplier(generator: Generator) -> float:
	var cycle_speed_multiplier: float = 1.0

	for modifier in generator.modifiers:
		if not modifier.applies_to(ModifierTypes.CYCLE_SPEED):
			continue

		cycle_speed_multiplier *= modifier.get_effective_multiplier(
			state,
			generator
		)

	return maxf(cycle_speed_multiplier, 0.0)


func _get_cycle_progress_delta(generator: Generator, elapsed_delta: float) -> float:
	return elapsed_delta * _get_cycle_speed_multiplier(generator)


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
	var triggered_events: Dictionary = _resolve_cycle_completion_events(generator)
	
	for output in generator.get_active_completion_outputs():
		if not output.unlocked:
			continue
		var amount: float = output.amount_per_second * generator.level
		
		for modifier in generator.modifiers:
			if modifier.applies_to(ModifierTypes.PRODUCTION, output.resource_id):
				amount = modifier.apply(amount, state, generator)
		
		for effect in generator.event_effects:
			if not _event_effect_applies_to_mode(effect, generator):
				continue
			if effect.event_trigger != UpgradeEffectTypes.EVENT_CYCLE_COMPLETED or effect.event_action != UpgradeEffectTypes.EVENT_ACTION_MULTIPLY_COMPLETION_OUTPUT:
				continue
			if effect.event_resource_id != "" and effect.event_resource_id != output.resource_id:
				continue
			if effect.event_condition_id != "" and not triggered_events.get(effect.event_condition_id, false):
				continue
			var source_upgrade_id := _event_effect_source_id(effect)
			var source_upgrade: Upgrade = state.get_upgrade(source_upgrade_id)
			var effect_level: int = source_upgrade.level if source_upgrade != null else 1
			amount *= 1.0 + effect.event_value * effect_level
		
		var current_amount := state.get_resource_amount(output.resource_id)
		state.set_resource_amount(output.resource_id, current_amount + amount)
		state.record_resource_produced(output.resource_id, amount)
		
		if output.resource_id == ResourceIds.CRYSTALLIZED_FLAME:
			if triggered_events.get("forge_critical", false):
				critical_crystallization_completed.emit(amount)
			else:
				crystallization_completed.emit(amount)
			var current_heat := state.get_resource_amount(ResourceIds.HEAT)
			if current_heat > 0.0:
				state.record_resource_lost(ResourceIds.HEAT, current_heat)
				state.set_resource_amount(ResourceIds.HEAT, 0.0)
	
	_apply_cycle_completion_consequences(generator, triggered_events)
	generator.cycle_active = false
	generator.operating = false
	generator.cycle_progress = 0.0


func _event_effect_source_id(effect: UpgradeEffect) -> String:
	return effect.event_source_upgrade_id


func _event_effect_applies_to_mode(effect: UpgradeEffect, generator: Generator) -> bool:
	# An empty mode list preserves the default behavior: apply in every mode.
	return (
		effect.operation_mode_ids.is_empty()
		or effect.operation_mode_ids.has(generator.operation_mode_id)
	)


func _resolve_cycle_completion_events(generator: Generator) -> Dictionary:
	var triggered_events: Dictionary = {"cycle_completed": true}
	for effect in generator.event_effects:
		if not _event_effect_applies_to_mode(effect, generator):
			continue
		if effect.event_trigger != UpgradeEffectTypes.EVENT_CYCLE_COMPLETED or effect.event_action != UpgradeEffectTypes.EVENT_ACTION_TRIGGER:
			continue
		var source_upgrade_id := _event_effect_source_id(effect)
		var source_upgrade: Upgrade = state.get_upgrade(source_upgrade_id)
		var effect_level: int = source_upgrade.level if source_upgrade != null else 1
		var chance := clampf(effect.event_chance * effect_level, 0.0, 1.0)
		if chance >= 1.0 or (chance > 0.0 and randf() < chance):
			triggered_events[effect.event_id] = true
	return triggered_events


func _apply_cycle_completion_consequences(generator: Generator, triggered_events: Dictionary) -> void:
	var consequences: Array[UpgradeEffect] = []
	for effect in generator.event_effects:
		if not _event_effect_applies_to_mode(effect, generator):
			continue
		if effect.event_trigger == UpgradeEffectTypes.EVENT_CYCLE_COMPLETED and effect.event_action == UpgradeEffectTypes.EVENT_ACTION_DECREASE_GENERATOR_LEVEL:
			consequences.append(effect)
	consequences.sort_custom(
		func(a: UpgradeEffect, b: UpgradeEffect) -> bool:
			return a.event_order < b.event_order
	)
	for effect in consequences:
		if effect.event_condition_id != "" and not triggered_events.get(effect.event_condition_id, false):
			continue
		var source_upgrade_id := _event_effect_source_id(effect)
		var source_upgrade: Upgrade = state.get_upgrade(source_upgrade_id)
		var effect_level: int = source_upgrade.level if source_upgrade != null else 1
		var chance := clampf(effect.event_chance * effect_level, 0.0, 1.0)
		if chance >= 1.0 or (chance > 0.0 and randf() < chance):
			var previous_level: int = generator.level
			generator.level = maxi(generator.level - maxi(roundi(effect.event_value), 1), 0)
			if generator.level < previous_level and generator.definition.id == "infernal_forge":
				generator_level_reduced.emit(
					generator.definition.id,
					previous_level,
					generator.level
				)


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
	generator_id: String,
	source: String = "manual"
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
	var previous_level: int = generator.level
	
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
	_record_diagnostic_event(
		"generator_purchase",
		generator_id,
		generator.level,
		source
	)
	
	if generator.definition.cycle_based:
		generator.cycle_progress = 0.0
		generator.cycle_active = true

	state.gameplay_log.record_event(
		"purchase",
		"generator_level_purchased",
		{
			"generator_id": generator_id,
			"generator_name": generator.definition.display_name,
			"old_level": previous_level,
			"new_level": generator.level,
			"cost_resource_id": generator.definition.cost_resource_id,
			"cost": cost
		},
		source
	)
	
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
	upgrade_id: String,
	source: String = "manual"
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
	var previous_level: int = upgrade.level
	
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
	_record_diagnostic_event(
		"upgrade_purchase",
		upgrade_id,
		upgrade.level,
		source
	)
	_apply_upgrade_level_effects(
		upgrade
	)
	if state.is_threshold_upgrade(upgrade_id):
		state.rebuild_realm_effects()

	# Upgrade effects can update existing cost modifiers in place.
	# Invalidate automation's cached costs so they refresh before use.
	if state.generator_automation_manager != null:
		state.generator_automation_manager.invalidate_waiting_costs()

	state.gameplay_log.record_event(
		"purchase",
		"upgrade_purchased",
		{
			"upgrade_id": upgrade_id,
			"upgrade_name": upgrade.definition.display_name,
			"generator_id": upgrade.definition.generator_id,
			"old_level": previous_level,
			"new_level": upgrade.level,
			"cost_resource_id": upgrade.definition.cost_resource_id,
			"cost": cost
		},
		source
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
				_record_diagnostic_event(
					"generator_unlock",
					generator.definition.id,
					generator.level,
					source_upgrade_id
				)
				state.gameplay_log.record_event(
					"unlock",
					"generator_unlocked",
					{
						"generator_id": generator.definition.id,
						"generator_name": generator.definition.display_name
					},
					"upgrade_effect"
				)
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
	elif effect.type == UpgradeEffectTypes.REGISTER_EVENT_EFFECT:
		var generator = state.get_generator(effect.target_id)
		if generator != null and not generator.event_effects.has(effect):
			effect.event_source_upgrade_id = source_upgrade_id
			generator.event_effects.append(effect)
		
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
	modifier.operation_mode_ids = effect.operation_mode_ids.duplicate()
	modifier.source_upgrade_id = source_upgrade_id
	
	if effect.dynamic_formula != "":
		modifier.dynamic = true
		modifier.dynamic_formula = effect.dynamic_formula
		modifier.dynamic_resource_id = effect.dynamic_resource_id
		modifier.dynamic_generator_id = effect.dynamic_generator_id
		modifier.dynamic_threshold = effect.dynamic_threshold
		modifier.dynamic_exponent = effect.dynamic_exponent
		modifier.dynamic_realm_effect_id = effect.dynamic_realm_effect_id
		modifier.dynamic_realm_effect_is_divisor = effect.dynamic_realm_effect_is_divisor
		
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
	sensitivity.operation_mode_ids = effect.operation_mode_ids.duplicate()
	
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
		
		var previous_level: int = upgrade.level
		upgrade.level += 1
		_record_diagnostic_event(
			"automatic_upgrade",
			upgrade.definition.id,
			upgrade.level,
			"automatic"
		)
		
		_apply_upgrade_level_effects(
			upgrade
		)
		state.gameplay_log.record_event(
			"upgrade",
			"automatic_upgrade_applied",
			{
				"upgrade_id": upgrade.definition.id,
				"upgrade_name": upgrade.definition.display_name,
				"old_level": previous_level,
				"new_level": upgrade.level
			},
			"automatic"
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

	# Temporarily disabled for benchmarking: repeated warnings can dominate
	# runtime when requested Heat loss exceeds the available Heat.
	# if overflow_rate > 0.0:
	# 	var heat_before_leak: float = state.get_resource_amount(
	# 		ResourceIds.HEAT
	# 	)
	# 	var effective_threshold: float = state.realm_effects.heat_leak_threshold
	#
	# 	if overflow_rate * delta >= heat_before_leak:
	# 		push_warning(
	# 			"EXTREME HEAT LEAK | Heat: %.3f | Threshold: %.3f | Rate/s: %.3f | Delta: %.4f | Requested loss: %.3f"
	# 			% [
	# 				heat_before_leak,
	# 				effective_threshold,
	# 				overflow_rate,
	# 				delta,
	# 				overflow_rate * delta
	# 			]
	# 		)

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
		ResourceIds.CRYSTALLIZED_FLAME
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
