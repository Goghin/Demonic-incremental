extends "res://tests/experimental/autobuyer_offline.gd"

# Explicit opt-in survey, never installed in throughput benchmarks. Primary
# reasons/tick counts come from the unchanged baseline runner. Secondary
# blockers overlap and are NOT additive coverage estimates.
var blocker_calls: Dictionary = {}


func guard() -> String:
	var reason: String = super()
	if reason == "" or force_exact:
		return reason
	var seen: Dictionary = {}
	var state: GameState = simulation.state
	for g: Generator in state.generators.values():
		if g.cycle_active or g.auto_run_cycles:
			seen["cycle/" + g.definition.id] = true
		if not g.unlocked or g.definition.cycle_based:
			continue
		for input: GeneratorIO in g.get_active_inputs():
			seen["consumer/" + g.definition.id + "/" + input.resource_id] = true
			if state.get_resource_amount(input.resource_id) <= g.get_input_consumption_per_second(input, state) * REFERENCE_STEP:
				seen["exhaustion/" + g.definition.id + "/" + input.resource_id] = true
		for output: GeneratorIO in g.get_active_outputs():
			if output.unlocked and output.discrete and g.level > 0 and not g.manually_paused:
				seen["discrete_output/" + g.definition.id + "/" + output.resource_id] = true
		for modifier: Modifier in g.modifiers:
			if modifier.dynamic and g.level > 0 and not g.manually_paused:
				seen["dynamic/" + modifier.type + "/" + g.definition.id + "/" + modifier.dynamic_resource_id] = true
	if state.get_heat_leak_per_second() > 0.0:
		seen["environment/heat_leak"] = true
	if state.get_matter_decay_per_second() > 0.0:
		seen["environment/matter_decay_to_heat"] = true
	var bound: Dictionary = preload("res://tests/experimental/resource_flow_bounds.gd").inspect(state, maximum_step + REFERENCE_STEP)
	if bound["reason"] != "":
		seen["proof/" + str(bound["reason"])] = true
	for blocker: String in seen:
		blocker_calls[blocker] = int(blocker_calls.get(blocker, 0)) + 1
	return reason
