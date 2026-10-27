extends "res://tests/experimental/adaptive_offline.gd"

# Experimental second-order coarse operator for the *reference map*, not an
# ODE reimplementation. Every slope is measured using Simulation.update(0.1).
# The outer step-doubling controller and all discrete guards remain authoritative.
var map_operator_usec: int = 0


func _init(game_simulation: Simulation) -> void:
	super(game_simulation)
	numerical_retry_max_ticks = 1000


func guard() -> String:
	var reason: String = super()
	if reason != "":
		return reason
	# Commit the normal offline-entry/logging transition on reference ticks.
	# Restricted checkpoints must not restore away that one-time housekeeping.
	if not simulation._gameplay_was_offline or simulation.state.track_gameplay_interval_statistics or simulation._gameplay_snapshot_realm_run_index != simulation.state.gameplay_realm_run_index:
		return "offline_entry_transition"
	return ""


func run(seconds: float) -> Dictionary:
	map_operator_usec = 0
	var result: Dictionary = super(seconds)
	counters["map_operator_usec"] = map_operator_usec
	result["map_operator_usec"] = map_operator_usec
	return result


func _advance(delta: float, end: float) -> void:
	if delta <= REFERENCE_STEP + 1e-12:
		super(delta, end)
		return
	var started: int = Time.get_ticks_usec()
	_map_advance(delta, end)
	map_operator_usec += Time.get_ticks_usec() - started


func _map_advance(delta: float, end: float) -> void:
	var saved: Dictionary = Checkpoint.capture(simulation)
	var initial: Dictionary = Metrics.numeric(simulation.state)
	super._advance(REFERENCE_STEP, end - delta + REFERENCE_STEP)
	var first: Dictionary = Metrics.numeric(simulation.state)
	var ticks: float = delta / REFERENCE_STEP
	var predicted: Dictionary = {}
	for id in simulation.state.resources:
		var key: String = "resource/" + str(id)
		predicted[id] = float(initial[key]) + ticks * (float(first[key]) - float(initial[key]))
		if not is_finite(predicted[id]) or float(predicted[id]) < 0.0:
			trial_failure_reason = "predictor_resource_exhaustion"
			Checkpoint.restore(simulation, saved)
			return
	Checkpoint.restore(simulation, saved)
	for id in predicted:
		simulation.state.resources[id].amount = predicted[id]
	var before_probe: Dictionary = Metrics.numeric(simulation.state)
	super._advance(REFERENCE_STEP, end)
	var endpoint: Dictionary = Metrics.numeric(simulation.state)
	var result: Dictionary = {}
	for key in first:
		var base: float = float(initial.get(key, 0.0))
		var d0: float = float(first[key]) - base
		var d1: float = float(endpoint.get(key, 0.0)) - float(before_probe.get(key, 0.0))
		# For n=1 this is F_0.1 exactly. For n>1, the (n-1) correction
		# matches the n(n-1)/2 term of repeated discrete-map composition.
		result[key] = base + ticks * d0 + (ticks - 1.0) * 0.5 * (d1 - d0)
	for key in result:
		var value: float = float(result[key])
		if not is_finite(value) or (str(key).begins_with("resource/") and value < 0.0):
			trial_failure_reason = "corrector_resource_exhaustion"
			Checkpoint.restore(simulation, saved)
			return
		if (str(key).ends_with("total_produced") or str(key).ends_with("total_consumed") or str(key).ends_with("total_lost") or str(key).ends_with("/overflow") or str(key).ends_with("/decay")) and value < float(initial.get(key, 0.0)):
			trial_failure_reason = "negative_integrated_flow"
			Checkpoint.restore(simulation, saved)
			return
	Checkpoint.restore(simulation, saved)
	for id in simulation.state.resources:
		simulation.state.resources[id].amount = float(result["resource/" + str(id)])
	var objects: Array = [simulation.state.resource_statistics, simulation.state.current_run_statistics, simulation.state.simulation_statistics]
	var prefixes: Array[String] = ["lifetime", "run", "offline"]
	for index in range(objects.size()):
		var stats: ResourceStatistics = objects[index]
		if stats == null:
			continue
		var prefix: String = prefixes[index]
		stats.total_overflow = float(result[prefix + "/overflow"])
		stats.total_matter_decayed = float(result[prefix + "/decay"])
		for id in simulation.state.resources:
			var path: String = prefix + "/" + str(id) + "/"
			for field in ["total_produced", "total_consumed", "total_lost"]:
				if result.has(path + field):
					stats._ensure_resource(id)
					stats.statistics[id][field] = result[path + field]
			var peak_key: String = path + "highest_amount"
			if not first.has(peak_key):
				continue
			var peak: float = maxf(float(initial.get(peak_key, 0.0)), float(first[peak_key]))
			# Preserve reference microstep peaks, rather than recording the
			# fictitious lump production of a long Simulation.update(delta).
			if float(endpoint.get(peak_key, 0.0)) > float(initial.get(peak_key, 0.0)):
				var resource_key: String = "resource/" + str(id)
				var last_increment: float = float(endpoint[resource_key]) - float(before_probe[resource_key])
				peak = maxf(peak, float(endpoint[peak_key]) + float(result[resource_key]) - float(predicted[id]) - last_increment)
			stats._ensure_resource(id)
			stats.statistics[id]["highest_amount"] = peak
	simulation.state.total_overflow_this_prestige = float(result["reward/overflow"])
	simulation.state.total_matter_decayed_this_prestige = float(result["reward/decay"])

	simulation.state.set_lava_mite_dormancy_penalty(manager.get_dormancy_penalty(end))
