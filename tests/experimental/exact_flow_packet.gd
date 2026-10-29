extends RefCounted

# Internal, synchronous packet. Never retain/use after Kernel.run() returns to an
# external caller. Live objects remain authoritative; only configuration is cached.
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
const PARTIAL_EPSILON: float = 0.000001
const Automation = preload("res://tests/experimental/exact_flow_automation.gd")
const Cycles = preload("res://tests/experimental/exact_flow_cycles.gd")
const Equipment = preload("res://tests/experimental/exact_flow_equipment.gd")
const Controller = preload("res://tests/experimental/exact_flow_controller.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const Observers = preload("res://tests/experimental/exact_flow_observers.gd")
var observer_metrics: Dictionary = {}
var simulation: Simulation
var machines: Array = []
var automatic_candidates: Array[Upgrade] = []
var has_automation: bool = false
var configuration_changed: bool = false
var cycle_heat_multiplier: float = -1.0
var measure_cycle_time: bool = false
var cycle_usec: int = 0
var cycle_invalidations: int = 0
var initialized: bool = false
var _built: bool = false
var error: String = ""
# Optional diagnostics, disabled in throughput measurements.
var measure_flows: bool = false
var flow_counts: Dictionary = {"controller_transitions": 0, "partial_operations": 0, "empty_duration_checks": 0, "input_exhaustions": 0}

class Rate extends RefCounted:
	var prefix: float = 0.0
	var suffix: Array = [] # Floats or original dynamic Modifier references.
	var final_scale: int = 1
	func evaluate(state: GameState, generator: Generator) -> float:
		var result: float = prefix
		for factor: Variant in suffix:
			result *= factor if factor is float else factor.get_effective_multiplier(state, generator)
		return result * final_scale

# Selected only for separate intrusive diagnostics. Normal Rate has no counters
# or per-evaluation measurement branch.
class MeasuredRate extends Rate:
	var evaluations: int = 0
	var dynamic_factors: int = 0
	func evaluate(state: GameState, generator: Generator) -> float:
		evaluations += 1
		return super.evaluate(state, generator)

class Output extends RefCounted:
	var resource_id: String
	var resource: ResourceState
	var discrete: bool
	var rate: Rate
	var cache_initialized: bool = false

class InputOperation extends RefCounted:
	var definition: GeneratorIO
	var resource: ResourceState
	var resource_id: String
	var rate: Rate
	func evaluate(state: GameState, generator: Generator) -> float:
		# Controller-dependent rate selection remains in the production API.
		return rate.evaluate(state, generator) if rate != null else generator.get_input_consumption_per_second(definition, state)

class Machine extends RefCounted:
	var generator: Generator
	var can_start: bool
	var cycle_based: bool
	var native_cycle: bool = false
	var inputs: Array[InputOperation] = []
	var single_input: InputOperation
	var multiple_inputs: bool = false
	var outputs: Array[Output] = []


func build(target: Simulation, journal: RefCounted = null) -> bool:
	if _built:
		error = "packet_is_one_shot"
		return false
	_built = true
	simulation = target
	var state: GameState = target.state
	if target.profiling_enabled or target.diagnostics_enabled or state.prestige_planning:
		error = "instrumentation_or_prestige"
		return false
	if state.get_script() != preload("res://game_state.gd") or target.get_script() != preload("res://simulation/simulation.gd"):
		error = "unknown_simulation_script"
		return false
	if state.gameplay_log == null or state.gameplay_log.get_script() != preload("res://tests/experimental/autobuyer_fixtures.gd").TickLog or state.gameplay_log.clock.is_valid():
		error = "external_logger_or_clock"
		return false
	if state.upgrade_system.get_script() != preload("res://Upgrades/UpgradeSystem.gd") or state.eternal_flame_upgrade_manager.get_script() != preload("res://Game/eternal_flame_upgrade_manager.gd") or state.eternal_flame_state.get_script() != preload("res://Game/eternal_flame_state.gd"):
		error = "unknown_cached_dependency"
		return false
	if state.generator_automation_manager.get_script() != preload("res://Game/GeneratorAutomationManager.gd") or state.upgrade_automation_manager.get_script() != preload("res://Game/UpgradeAutomationManager.gd") or state.realm_effects.get_script() != preload("res://Game/realm_effects.gd"):
		error = "unknown_runtime_dependency"
		return false
	for upgrade: Upgrade in state.upgrades.values():
		if upgrade.get_script() != preload("res://Upgrades/upgrade.gd") or upgrade.definition.get_script() != preload("res://Upgrades/upgrade_definition.gd"):
			error = "unknown_upgrade_contract"
			return false
		for requirement: Requirement in upgrade.definition.requirements:
			if requirement.get_script() != preload("res://Game/requirement.gd"):
				error = "unknown_requirement_contract"
				return false
	error = Observers.rejection(target, journal, observer_metrics)
	if not error.is_empty():
		return false
	has_automation = Automation.enabled(state)
	if has_automation:
		for upgrade: Upgrade in state.upgrades.values():
			for effect: UpgradeEffect in upgrade.definition.effects:
				if effect.get_script() != preload("res://Upgrades/upgrade_effect.gd"):
					error = "unknown_automation_effect_contract"
					return false
	error = Equipment.rejection(state)
	if not error.is_empty():
		return false
	for stats: ResourceStatistics in [state.resource_statistics, state.current_run_statistics, state.simulation_statistics]:
		if stats != null and stats.get_script() != preload("res://Game/resource_statistics.gd"):
			error = "unknown_statistics_script"
			return false
	for resource: ResourceState in state.resources.values():
		if resource.get_script() != preload("res://Resources/resource_state.gd") or not is_finite(resource.amount):
			error = "unsupported_resource"
			return false
	for generator: Generator in state.generators.values():
		if generator.get_script() != preload("res://Generators/generator.gd") or generator.definition.get_script() != preload("res://Generators/generator_definition.gd"):
			error = "unknown_generator_script"
			return false
		if has_automation:
			for mode: GeneratorOperationMode in generator.definition.operation_modes:
				if mode.get_script() != preload("res://Generators/generator_operation_mode.gd"):
					error = "unknown_automation_mode_contract"
					return false
		if (generator.cycle_active or generator.auto_run_cycles) and not generator.definition.cycle_based:
			error = "non_cycle_runtime"
			return false
		var cycle_contract: String = ""
		if generator.definition.cycle_based:
			cycle_contract = Cycles.rejection(generator, state)
			if cycle_contract != "" and (generator.cycle_active or generator.auto_run_cycles):
				error = cycle_contract
				return false
		for modifier: Modifier in generator.modifiers:
			if modifier.get_script() != preload("res://Game/modifier.gd"):
				error = "unknown_modifier"
				return false
			var equipment_error: String = Equipment.modifier_rejection(modifier)
			if not equipment_error.is_empty():
				error = equipment_error
				return false
		for sensitivity: ModifierSensitivity in generator.modifier_sensitivities:
			if sensitivity.get_script() != preload("res://Game/modifiersensitivity.gd"):
				error = "unknown_sensitivity"
				return false
		if not generator.unlocked:
			continue
		var machine := Machine.new()
		machine.generator = generator
		machine.cycle_based = generator.definition.cycle_based
		machine.native_cycle = machine.cycle_based and cycle_contract == ""
		machine.can_start = generator.level > 0 and not generator.manually_paused and not machine.cycle_based
		machines.append(machine)
		if machine.cycle_based or (not machine.can_start and not generator.operating):
			continue
		var mode: GeneratorOperationMode = generator.get_operation_mode()
		if mode == null or mode.get_script() != preload("res://Generators/generator_operation_mode.gd"):
			error = "unknown_operation_mode"
			return false
		var scale: int = generator.level if generator.definition.scale_rates_with_level else 1
		for input: GeneratorIO in mode.inputs:
			if input.get_script() != preload("res://Generators/generator_io.gd") or not state.resources.has(input.resource_id):
				error = "unknown_input_contract"
				return false
			var operation := InputOperation.new()
			operation.definition = input
			operation.resource_id = input.resource_id
			operation.resource = state.resources[input.resource_id]
			if mode.is_resource_transfer:
				# Native input: (raw * mode multiplier), then level. No modifiers.
				operation.rate = Rate.new()
				operation.rate.prefix = input.amount_per_second * mode.input_multiplier
				operation.rate.final_scale = scale
			elif not Controller.needs_native_input_rates(generator):
				operation.rate = _rate(input.amount_per_second * mode.input_multiplier, generator, ModifierTypes.INPUT_DRAW, input.resource_id)
				operation.rate.final_scale = scale
			machine.inputs.append(operation)
		machine.multiple_inputs = machine.inputs.size() > 1
		if machine.inputs.size() == 1:
			machine.single_input = machine.inputs[0]
		for output: GeneratorIO in mode.outputs:
			if output.get_script() != preload("res://Generators/generator_io.gd"):
				error = "unknown_output_script"
				return false
			if not output.unlocked:
				continue
			if not state.resources.has(output.resource_id):
				error = "unsupported_output/" + output.resource_id
				return false
			var operation := Output.new()
			operation.resource_id = output.resource_id
			operation.resource = state.resources[output.resource_id]
			operation.discrete = output.discrete
			if mode.is_resource_transfer:
				# Native output: (first raw input * level) * mode multiplier.
				# In particular expansion does NOT use output.amount_per_second,
				# production_multiplier, realm bonuses or production caches.
				operation.rate = Rate.new()
				operation.rate.prefix = 0.0 if mode.inputs.is_empty() else (mode.inputs[0].amount_per_second * scale * mode.input_multiplier)
				operation.cache_initialized = true
				machine.outputs.append(operation)
				continue
			operation.cache_initialized = generator._production_modifier_cache.has(output.resource_id)
			# Same left-associated sequence as Generator.get_production_rate.
			var coefficient: float = output.amount_per_second * scale
			coefficient *= mode.production_multiplier
			if output.resource_id == ResourceIds.MATTER:
				coefficient *= state.realm_effects.matter_production_multiplier
			if output.resource_id == ResourceIds.HEAT:
				coefficient *= state.realm_effects.heat_production_multiplier
				coefficient *= state.eternal_flame_upgrade_manager.get_effective_multiplier("eternal_furnace", state.eternal_flame_state)
			operation.rate = _rate(coefficient, generator, ModifierTypes.PRODUCTION, output.resource_id)
			machine.outputs.append(operation)
	cycle_heat_multiplier = state.eternal_flame_upgrade_manager.get_effective_multiplier("eternal_furnace", state.eternal_flame_state)
	# Non-resource requirement blockers cannot change during an uninterrupted
	# packet; an eligible automatic action exits BEFORE any writes that tick.
	for upgrade: Upgrade in state.upgrades.values():
		if not upgrade.definition.automatic or upgrade.is_maxed():
			continue
		var blocked: bool = false
		for requirement: Requirement in upgrade.definition.requirements:
			if requirement.type != RequirementTypes.RESOURCE and not state.upgrade_system.requirement_met(requirement):
				blocked = true
		if not blocked:
			automatic_candidates.append(upgrade)
	return error.is_empty()


func _rate(coefficient: float, generator: Generator, kind: String, resource_id: String) -> Rate:
	var result: Rate = MeasuredRate.new() if measure_flows else Rate.new()
	result.prefix = coefficient
	var modifiers: Array = generator.modifiers
	var use_cache: bool = kind == ModifierTypes.PRODUCTION and generator._production_modifier_cache.has(resource_id)
	if use_cache:
		modifiers = generator._production_modifier_cache[resource_id]
	var dynamic_seen: bool = false
	for modifier: Modifier in modifiers:
		if modifier.get_script() != preload("res://Game/modifier.gd"):
			error = "unknown_cached_modifier"
			return result
		var equipment_error: String = Equipment.modifier_rejection(modifier)
		if not equipment_error.is_empty():
			error = equipment_error
			return result
		if not use_cache and not modifier.applies_to(kind, resource_id):
			continue
		var dynamic_factor: bool = modifier.dynamic
		for sensitivity: ModifierSensitivity in generator.modifier_sensitivities:
			if sensitivity.modifier_id == modifier.id and sensitivity.dynamic:
				dynamic_factor = true
		if dynamic_factor:
			dynamic_seen = true
			result.suffix.append(modifier)
			if result is MeasuredRate:
				result.dynamic_factors += 1
		else:
			var factor: float = modifier.get_effective_multiplier(simulation.state, generator)
			if dynamic_seen:
				result.suffix.append(factor)
			else:
				result.prefix *= factor
	return result


func event_due() -> bool:
	if configuration_changed:
		return true
	for upgrade: Upgrade in automatic_candidates:
		if simulation.state.upgrade_system.requirements_met(upgrade.definition.requirements):
			return true
	return false


func step() -> void:
	# Internal only: caller owns the synchronous interval and checked event_due.
	assert(not configuration_changed, "Invalidated packet must be discarded before another step")
	var state: GameState = simulation.state
	var heat_start: float = state.resources[ResourceIds.HEAT].amount
	state.track_gameplay_interval_statistics = false
	if simulation._gameplay_snapshot_realm_run_index != state.gameplay_realm_run_index:
		simulation._gameplay_snapshot_elapsed = 0.0
		simulation._gameplay_snapshot_realm_run_index = state.gameplay_realm_run_index
		state.take_gameplay_interval_statistics()
	if not initialized:
		simulation.update_automatic_upgrades(true) # No eligible action; initialize cache.
		initialized = true
	for machine: Machine in machines:
		var generator: Generator = machine.generator
		if measure_flows:
			var was_throttled: bool = generator.is_throttled
			simulation._update_lava_mite_throttle_state(generator)
			if was_throttled != generator.is_throttled:
				flow_counts["controller_transitions"] += 1
		else:
			simulation._update_lava_mite_throttle_state(generator)
		if machine.cycle_based:
			if machine.native_cycle and (generator.cycle_active or generator.auto_run_cycles):
				var previous_level: int = generator.level
				var cycle_started: int = Time.get_ticks_usec() if measure_cycle_time else 0
				simulation.update_cycle_generator(generator, STEP, true, cycle_heat_multiplier)
				if measure_cycle_time:
					cycle_usec += Time.get_ticks_usec() - cycle_started
				if generator.level != previous_level:
					configuration_changed = true
					cycle_invalidations += 1
			continue
		var duration: float = STEP
		if machine.multiple_inputs:
			# Availability rates all see the same pre-consumption state. The
			# consumption pass MUST reevaluate sequentially after earlier writes.
			if not generator.operating:
				if not machine.can_start or not _can_start(machine, state):
					continue
				generator.operating = true
			duration = _available_duration(machine, state)
			if duration <= 0.0:
				generator.operating = false
				if measure_flows:
					flow_counts["empty_duration_checks"] += 1
				continue
			for input: InputOperation in machine.inputs:
				var amount: float = input.resource.amount
				var consumed: float = min(input.evaluate(state, generator) * duration, amount)
				if consumed > 0.0:
					state.set_resource_amount(input.resource_id, amount - consumed)
					state.record_resource_consumed(input.resource_id, consumed)
					if measure_flows and consumed == amount:
						flow_counts["input_exhaustions"] += 1
		else:
			# Preserve the proven single-input fast path. No resource mutation
			# occurs between startup/availability/consumption, so rate reuse is exact.
			var input: InputOperation = machine.single_input
			var input_rate: float = 0.0
			var rate_known: bool = false
			if not generator.operating:
				if not machine.can_start:
					continue
				if input != null and input.resource.amount <= 0.0:
					input_rate = input.rate.evaluate(state, generator) if input.rate != null else generator.get_input_consumption_per_second(input.definition, state)
					rate_known = true
					if input_rate > 0.0:
						continue
				generator.operating = true
			if input != null:
				if not rate_known:
					input_rate = input.rate.evaluate(state, generator) if input.rate != null else generator.get_input_consumption_per_second(input.definition, state)
				if input_rate > 0.0:
					if input.resource.amount <= 0.0:
						generator.operating = false
						continue
					duration = min(duration, input.resource.amount / input_rate)
				duration = max(duration, 0.0)
			if duration <= 0.0:
				generator.operating = false
				continue
			if input != null:
				var amount: float = input.resource.amount
				var consumed: float = min(input_rate * duration, amount)
				if consumed > 0.0:
					state.set_resource_amount(input.resource_id, amount - consumed)
					state.record_resource_consumed(input.resource_id, consumed)
					if measure_flows and consumed == amount:
						flow_counts["input_exhaustions"] += 1
		for output: Output in machine.outputs:
			if not output.cache_initialized:
				generator.get_production_modifiers(output.resource_id)
				output.cache_initialized = true
			var production: float = output.rate.evaluate(state, generator) * duration
			if output.discrete:
				var progress: float = generator.production_progress.get(output.resource_id, 0.0)
				progress += production
				var whole: float = floor(progress)
				if whole > 0.0:
					state.set_resource_amount(output.resource_id, output.resource.amount + whole)
					state.record_resource_produced(output.resource_id, whole)
					progress -= whole
				generator.production_progress[output.resource_id] = progress
			else:
				state.set_resource_amount(output.resource_id, output.resource.amount + production)
				state.record_resource_produced(output.resource_id, production)
		if duration < STEP - PARTIAL_EPSILON:
			generator.operating = false
			if measure_flows:
				flow_counts["partial_operations"] += 1
	simulation.apply_environmental_effects(STEP, heat_start)
	# All checks and mutations stay native, after environmental accounting.
	# The audited owned log appends on every successful native purchase,
	# including activation without a level increase and upgrades/unlocks.
	var automation_mark: int = Automation.mark(state) if has_automation else 0
	state.generator_automation_manager.update(STEP, simulation, true)
	state.upgrade_automation_manager.update(STEP, simulation, true)
	if has_automation:
		if not observer_metrics.is_empty() and Automation.changed(state, automation_mark):
			observer_metrics["automation_invalidations"] += 1
			if not observer_metrics.has("automation_events"):
				observer_metrics["automation_events"] = {}
			var events: Dictionary = observer_metrics["automation_events"]
			for index: int in range(automation_mark, state.gameplay_log.events.size()):
				var event_name: String = str(state.gameplay_log.events[index]["event"])
				events[event_name] = int(events.get(event_name, 0)) + 1
		configuration_changed = configuration_changed or Automation.changed(state, automation_mark)
	if not simulation._gameplay_was_offline:
		simulation._gameplay_snapshot_elapsed = 0.0
		state.take_gameplay_interval_statistics()
		simulation._gameplay_was_offline = true


func _can_start(machine: Machine, state: GameState) -> bool:
	for input: InputOperation in machine.inputs:
		if input.resource.amount > 0.0:
			continue
		if input.evaluate(state, machine.generator) > 0.0:
			return false
	return true


func _available_duration(machine: Machine, state: GameState) -> float:
	var duration: float = STEP
	for input: InputOperation in machine.inputs:
		var rate: float = input.evaluate(state, machine.generator)
		if rate <= 0.0:
			continue
		if input.resource.amount <= 0.0:
			return 0.0
		duration = min(duration, input.resource.amount / rate)
	return max(duration, 0.0)


func rate_measurements() -> Dictionary:
	# Definition/reference inspection and aggregation only at packet release.
	var result: Dictionary = {"tape_evaluations": 0, "dynamic_modifier_evaluations": 0}
	for machine: Machine in machines:
		for operation: InputOperation in machine.inputs:
			if operation.rate is MeasuredRate:
				result["tape_evaluations"] += operation.rate.evaluations
				result["dynamic_modifier_evaluations"] += operation.rate.evaluations * operation.rate.dynamic_factors
		for operation: Output in machine.outputs:
			if operation.rate is MeasuredRate:
				result["tape_evaluations"] += operation.rate.evaluations
				result["dynamic_modifier_evaluations"] += operation.rate.evaluations * operation.rate.dynamic_factors
	return result
