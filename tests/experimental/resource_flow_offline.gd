extends "res://tests/experimental/autobuyer_offline.gd"

const FlowBounds = preload("res://tests/experimental/resource_flow_bounds.gd")
var flow_proof: Dictionary = {}
var flow_reasons: Dictionary = {}
var flow_calls: int = 0
var flow_usec: int = 0


func run(seconds: float) -> Dictionary:
	flow_reasons.clear()
	flow_calls = 0
	flow_usec = 0
	var result: Dictionary = super(seconds)
	result["resource_flow"] = {"calls": flow_calls, "usec": flow_usec, "reasons": flow_reasons.duplicate()}
	return result


func guard() -> String:
	if force_exact or preload("res://tests/experimental/accuracy_modes.gd").prestige_exposed(simulation.state):
		return super()
	# Keep the old cheap path for producer-only and proven waiting fixtures.
	var consumers: bool = false
	for g: Generator in simulation.state.generators.values():
		if g.unlocked and not g.definition.cycle_based and not g.get_active_inputs().is_empty():
			consumers = true
			break
	flow_proof = {}
	if consumers and not force_exact:
		var started: int = Time.get_ticks_usec()
		# Include the endpoint reference-map probe, which samples one tick
		# beyond the Euler predictor. Do not cap this by the requested duration.
		flow_proof = FlowBounds.inspect(simulation.state, maximum_step + REFERENCE_STEP)
		flow_calls += 1
		flow_usec += Time.get_ticks_usec() - started
		var reason: String = str(flow_proof["reason"])
		flow_reasons[reason if reason != "" else "proved"] = int(flow_reasons.get(reason if reason != "" else "proved", 0)) + 1
		if reason != "":
			return "flow/" + reason
	return super()


func _consumer_guard(_generator: Generator) -> String:
	return "" if flow_proof.get("reason", "missing_proof") == "" else "resource_consumers"
