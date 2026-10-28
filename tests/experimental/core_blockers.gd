extends RefCounted

const Boundary = preload("res://tests/experimental/autobuyer_boundary.gd")
const Policy = preload("res://tests/experimental/accuracy_modes.gd")

# Observational enumeration of independent capability restrictions. Presence of
# a nonlinear formula is distinguished from the absence of a valid enclosure.
static func inspect(simulation: Simulation) -> Dictionary:
	var state: GameState = simulation.state
	var blockers: Dictionary = {}
	var context: Dictionary = {}
	var changed: Dictionary = {}
	var consumers: bool = false
	var cycles: bool = false
	for g: Generator in state.generators.values():
		cycles = cycles or g.cycle_active or g.auto_run_cycles
		if not g.unlocked or g.manually_paused or (g.definition.cycle_based and not g.cycle_active and not g.auto_run_cycles) or (g.level <= 0 and not g.cycle_active):
			continue
		consumers = consumers or not g.get_active_inputs().is_empty()
		for input: GeneratorIO in g.get_active_inputs():
			changed[input.resource_id] = true
		for output: GeneratorIO in g.get_active_outputs():
			if output.unlocked:
				changed[output.resource_id] = true
	if state.get_matter_decay_per_second() > 0.0:
		changed[ResourceIds.MATTER] = true
		changed[ResourceIds.HEAT] = true
	if state.get_heat_leak_per_second() > 0.0:
		changed[ResourceIds.HEAT] = true
		_add(context, "environment_active", "heat_leak")
	if state.get_matter_decay_per_second() > 0.0:
		_add(context, "environment_active", "matter_decay_into_heat")
	if Policy.prestige_exposed(state):
		_add(blockers, "prestige_gate", "projected reward exposure")
	for g: Generator in state.generators.values():
		if g.cycle_active or g.auto_run_cycles:
			_add(blockers, "cycle_events", g.definition.id)
		if not g.unlocked or (g.definition.cycle_based and not g.cycle_active and not g.auto_run_cycles):
			continue
		var active: bool = not g.manually_paused and g.level > 0
		if not g.get_active_inputs().is_empty():
			if active:
				consumers = true
				_add(blockers, "input_enclosure", g.definition.id)
			else:
				_add(blockers, "inactive_consumer_guard", g.definition.id)
		if not active:
			continue
		for input: GeneratorIO in g.get_active_inputs():
			var normal: float = g.get_input_consumption_per_second(input, state, false)
			var throttled: float = g.get_input_consumption_per_second(input, state, true)
			if normal != throttled or g.is_throttled:
				_add(blockers, "throttle_controller", g.definition.id + "/" + input.resource_id)
			if state.get_resource_amount(input.resource_id) <= normal * TimeManager.OFFLINE_MAX_GAME_STEP:
				_add(context, "possible_input_starvation", g.definition.id + "/" + input.resource_id)
		for output: GeneratorIO in g.get_active_outputs():
			if output.unlocked and output.discrete:
				_add(blockers, "discrete_output", g.definition.id + "/" + output.resource_id)
		for modifier: Modifier in g.modifiers:
			if not modifier.type in [ModifierTypes.PRODUCTION, ModifierTypes.INPUT_DRAW, ModifierTypes.CYCLE_SPEED] or not modifier.dynamic:
				continue
			if not modifier.operation_mode_ids.is_empty() and not modifier.operation_mode_ids.has(g.operation_mode_id):
				continue
			var relevant: bool = modifier.type == ModifierTypes.CYCLE_SPEED and g.cycle_active
			var io_list: Array[GeneratorIO] = g.get_active_outputs()
			if modifier.type == ModifierTypes.INPUT_DRAW:
				io_list = g.get_active_inputs()
			for io: GeneratorIO in io_list:
				if (modifier.type == ModifierTypes.INPUT_DRAW or io.unlocked) and modifier.applies_to(modifier.type, io.resource_id):
					relevant = true
			if not relevant:
				continue
			if modifier.dynamic_formula == Modifier.DYNAMIC_LAVA_MITE_DORMANCY:
				_add(blockers, "clock_dependency", g.definition.id)
			elif changed.has(modifier.dynamic_resource_id):
				_add(blockers if consumers or cycles else context, "changing_rate_dependency", g.definition.id + "/" + modifier.type + "/" + modifier.dynamic_resource_id)
		for sensitivity: ModifierSensitivity in g.modifier_sensitivities:
			if sensitivity.dynamic and changed.has(sensitivity.dynamic_resource_id) and (sensitivity.operation_mode_ids.is_empty() or sensitivity.operation_mode_ids.has(g.operation_mode_id)):
				_add(blockers if consumers or cycles else context, "changing_sensitivity", g.definition.id + "/" + sensitivity.dynamic_resource_id)
	if consumers and (state.get_heat_leak_per_second() > 0.0 or state.get_matter_decay_per_second() > 0.0):
		_add(blockers, "environmental_enclosure", "consumer box currently requires inactive sinks/conversion")
	for upgrade: Upgrade in state.upgrades.values():
		if not upgrade.definition.automatic or upgrade.is_maxed():
			continue
		var immutable_blocker: bool = false
		for requirement: Requirement in upgrade.definition.requirements:
			if not state.upgrade_system.requirement_met(requirement) and (requirement.type != RequirementTypes.RESOURCE or not changed.has(requirement.target_id)):
				immutable_blocker = true
		if not immutable_blocker:
			_add(blockers, "automatic_event", upgrade.definition.id)
	var proof: Dictionary = Boundary.inspect(simulation)
	if not proof["status"] in ["disabled", "provably_waiting"]:
		_add(blockers, "automation_boundary", str(proof["status"]))
	return {"blockers": blockers, "context": context}


static func _add(target: Dictionary, key: String, detail: String) -> void:
	if not target.has(key):
		target[key] = []
	if not target[key].has(detail):
		target[key].append(detail)
