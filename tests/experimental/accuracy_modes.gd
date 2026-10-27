extends RefCounted

# Experimental policies only. No player setting or production caller.
const PRESETS: Dictionary = {
	"precise": {"force_exact": true, "relative_tolerance": 0.0, "absolute_tolerance": 1e-8, "maximum_step": 0.1},
	"balanced": {"force_exact": false, "relative_tolerance": 1e-4, "absolute_tolerance": 1e-8, "maximum_step": 60.0},
	"fast": {"force_exact": false, "relative_tolerance": 1e-3, "absolute_tolerance": 1e-8, "maximum_step": 60.0}
}
const COMMON: Dictionary = {"minimum_step": 0.1, "event_safety_margin": 0.1,
	"fallback_window_ticks": 10, "numerical_retry_max_ticks": 1000,
	"distribute_error_budget": true, "audit_interval": 60.0,
	"short_exact_seconds": 600.0,
	"reuse_probe_fields": true, "ensure_statistics_once": true,
	"monotone_decay_margin": true, "monotone_decay_fraction_limit": 0.5}

static func configuration(mode: String, overrides: Dictionary = {}) -> Dictionary:
	if not PRESETS.has(mode):
		return {"error": "Unknown experimental accuracy mode: " + mode}
	var result: Dictionary = COMMON.duplicate(true)
	result.merge(PRESETS[mode], true)
	for key in overrides:
		if not result.has(key):
			return {"error": "Unknown experimental configuration key: " + str(key)}
		var supplied: Variant = overrides[key]
		if result[key] is bool:
			if not supplied is bool:
				return {"error": "Expected a boolean configuration value: " + str(key)}
		else:
			if not (supplied is float or supplied is int) or not is_finite(float(supplied)):
				return {"error": "Expected a finite numeric configuration value: " + str(key)}
			if result[key] is int and float(supplied) != floorf(float(supplied)):
				return {"error": "Expected an integer configuration value: " + str(key)}
			if result[key] is int:
				supplied = int(supplied)
		result[key] = supplied
	if float(result["minimum_step"]) < TimeManager.OFFLINE_MAX_GAME_STEP or float(result["maximum_step"]) < float(result["minimum_step"]) or float(result["absolute_tolerance"]) <= 0.0 or float(result["relative_tolerance"]) < 0.0 or float(result["event_safety_margin"]) < 0.0 or int(result["fallback_window_ticks"]) < 1 or int(result["numerical_retry_max_ticks"]) < 0 or float(result["audit_interval"]) < TimeManager.OFFLINE_MAX_GAME_STEP or float(result["short_exact_seconds"]) < 0.0 or float(result["monotone_decay_fraction_limit"]) <= 0.0 or float(result["monotone_decay_fraction_limit"]) > 0.5:
		return {"error": "Experimental configuration outside supported limits."}
	if mode == "precise" and (not result["force_exact"] or float(result["maximum_step"]) != TimeManager.OFFLINE_MAX_GAME_STEP or float(result["relative_tolerance"]) != 0.0):
		return {"error": "Precise mode cannot approximate the reference simulator."}
	return result


static func prestige_exposed(state: GameState) -> bool:
	# The production reward API does not expose dependency metadata. Use a
	# conservative currency gate instead of guessing distance to a floor boundary
	# or duplicating the reward formula. Even a currently-zero reward is protected.
	if state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME) > 0.0:
		return true
	for generator in state.generators.values():
		if not generator.unlocked or generator.level <= 0 or generator.manually_paused:
			continue
		for output in generator.get_active_outputs():
			if output.unlocked and output.resource_id == ResourceIds.CRYSTALLIZED_FLAME:
				return true
	return false
