extends "res://tests/experimental/feedback_offline.gd"

const Modes = preload("res://tests/experimental/accuracy_modes.gd")
var monotone_decay_margin: bool = true
var monotone_decay_fraction_limit: float = 0.5
var accuracy_mode: String = "balanced"
var overrides: Dictionary = {}
var diagnostics: bool = false
var segment_seconds: float = 3600.0
var audit_all_accepted: bool = true
var segment_callback: Callable
var segments: Array[Dictionary] = []
var effective_configuration: Dictionary = {}
var _policy_reason: String = ""
var _segment_tick: int = 0
var _segment_start_tick: int = 0
var _segment_start_usec: int = 0
var _counter_start: Dictionary = {}
var _widths: Dictionary = {}
var _adaptive_ticks: int = 0


func guard() -> String:
	if force_exact:
		return _policy_reason
	if Modes.prestige_exposed(simulation.state):
		return "prestige_currency_exposure"
	return super()


func _near_boundary_requires_exact(resource: String, before: float, coarse: float, fine: float) -> bool:
	# This is a contract of the existing Matter power-law sink (exponent >= 2),
	# not a constant-rate forecast. No sources + no consumers implies monotone
	# decay. Its loss/excess ratio decreases as Matter approaches the threshold.
	# If one reference step cannot cross, induction excludes every intervening
	# reference step. Actual predicted crossings still reject in the base loop.
	if not monotone_decay_margin or resource != ResourceIds.MATTER:
		return true
	var state: GameState = simulation.state
	var threshold: float = state.realm_effects.matter_decay_threshold
	if before <= threshold or coarse <= threshold or fine <= threshold or coarse > before or fine > before:
		return true
	for generator in state.generators.values():
		if not generator.unlocked or generator.manually_paused or generator.definition.cycle_based:
			continue
		if generator.level <= 0 and not generator.operating:
			continue
		for output in generator.get_active_outputs():
			if output.unlocked and output.resource_id == resource:
				return true
	# The rate getter depends only on Matter, static realm/upgrade parameters.
	# Query the existing formula at the interval start without setters, peaks,
	# signals or RNG draws. No other gameplay system runs during this query.
	var current: float = state.resources[resource].amount
	state.resources[resource].amount = before
	var loss: float = state.get_matter_decay_per_second() * REFERENCE_STEP
	state.resources[resource].amount = current
	if not is_finite(loss) or loss < 0.0 or loss >= (before - threshold) * monotone_decay_fraction_limit:
		return true
	counters["proven_margin_bypasses"] = int(counters.get("proven_margin_bypasses", 0)) + 1
	return false


func run(seconds: float) -> Dictionary:
	effective_configuration = Modes.configuration(accuracy_mode, overrides)
	if effective_configuration.has("error"):
		return {"strict_failure": effective_configuration["error"], "evaluations": 0}
	for key in effective_configuration:
		if key != "short_exact_seconds":
			set(key, effective_configuration[key])
	var short_limit: float = float(effective_configuration["short_exact_seconds"])
	if not is_finite(short_limit) or short_limit < 0.0 or not is_finite(segment_seconds) or segment_seconds <= 0.0:
		return {"strict_failure": "Invalid experimental horizon configuration.", "evaluations": 0}
	_policy_reason = "precise_mode"
	if not force_exact and seconds <= short_limit:
		force_exact = true
		_policy_reason = "short_duration_exact"
	var audit_ticks: int = maxi(1, floori(audit_interval / REFERENCE_STEP))
	var segment_ticks: int = roundi(segment_seconds / REFERENCE_STEP)
	if diagnostics and (segment_ticks < audit_ticks or segment_ticks % audit_ticks != 0):
		return {"strict_failure": "Diagnostic segments must align with existing audit boundaries.", "evaluations": 0}
	segments.clear()
	_counter_start.clear()
	_widths.clear()
	_adaptive_ticks = 0
	_segment_start_tick = 0
	_segment_tick = segment_ticks
	_segment_start_usec = Time.get_ticks_usec()
	profile_checkpoints = diagnostics
	var result: Dictionary = super(seconds)
	if diagnostics and elapsed > float(_segment_start_tick) * REFERENCE_STEP + 1e-8:
		_record_segment(roundi(elapsed / REFERENCE_STEP))
	result["policy"] = _policy_reason if force_exact else accuracy_mode
	result["configuration"] = effective_configuration.duplicate(true)
	return result


func _sample(tick: int) -> void:
	# Optional retained audit density is observational: the timestep controller,
	# its error fields and per-trial discrete/RNG checks are never disabled.
	var audit_ticks: int = maxi(1, floori(audit_interval / REFERENCE_STEP))
	if not audit_all_accepted and tick % audit_ticks != 0 and tick != ceili(duration / REFERENCE_STEP):
		return
	super(tick)
	if samples.has(tick):
		samples[tick]["prestige"] = PrestigeSystem.new().calculate_eternal_flame_gain(simulation.state)


func _completed_interval(ticks: int, adaptive: bool) -> void:
	if not diagnostics:
		return
	if adaptive:
		_adaptive_ticks += ticks
		_widths[ticks] = int(_widths.get(ticks, 0)) + 1
	var now_tick: int = roundi(elapsed / REFERENCE_STEP)
	if now_tick >= _segment_tick:
		_record_segment(now_tick)
		_segment_tick += roundi(segment_seconds / REFERENCE_STEP)


func _record_segment(tick: int) -> void:
	var now: int = Time.get_ticks_usec()
	var snapshot: Dictionary = counters.duplicate(true)
	snapshot["map_operator_usec"] = map_operator_usec
	var delta: Dictionary = {}
	for key in snapshot:
		if snapshot[key] is int:
			delta[key] = int(snapshot[key]) - int(_counter_start.get(key, 0))
		elif snapshot[key] is Dictionary:
			delta[key] = {}
			for reason in snapshot[key]:
				delta[key][reason] = int(snapshot[key][reason]) - int(_counter_start.get(key, {}).get(reason, 0))
	var steps: Array = _widths.keys()
	steps.sort()
	var count: int = 0
	for width in steps:
		count += int(_widths[width])
	var median_ticks: float = 0.0
	if count > 0:
		# Average the two middle ranks, including unequal histogram weights.
		for rank in [(count - 1) >> 1, count >> 1]:
			var cumulative: int = 0
			for width in steps:
				cumulative += int(_widths[width])
				if cumulative > rank:
					median_ticks += float(width) * 0.5
					break
	var state: GameState = simulation.state
	var active: Array[String] = []
	var modifiers: Dictionary = {}
	for generator in state.generators.values():
		if not generator.unlocked or (not generator.operating and not generator.cycle_active):
			continue
		active.append(generator.definition.id)
		var values: Array = []
		for modifier in generator.modifiers:
			values.append({"id": modifier.id, "resource": modifier.dynamic_resource_id,
				"formula": modifier.dynamic_formula, "effective": modifier.get_effective_multiplier(state, generator)})
		modifiers[generator.definition.id] = values
	var automation_count: int = 0
	for automation in [state.generator_automation_manager, state.upgrade_automation_manager]:
		for entry in automation.automation_states.values():
			if entry["enabled"]:
				automation_count += 1
	var wall: float = float(now - _segment_start_usec) / 1e6
	var simulated_seconds: float = minf(duration, float(tick) * REFERENCE_STEP) - minf(duration, float(_segment_start_tick) * REFERENCE_STEP)
	var record: Dictionary = {"from": float(_segment_start_tick) * REFERENCE_STEP,
		"until": minf(duration, float(tick) * REFERENCE_STEP), "wall_seconds": wall,
		"throughput_simulated_seconds_per_second": simulated_seconds / maxf(wall, 1e-9),
		"counters": delta, "adaptive_coverage": minf(1.0, float(_adaptive_ticks) * REFERENCE_STEP / maxf(simulated_seconds, 1e-30)),
		"average_step": float(_adaptive_ticks) * REFERENCE_STEP / maxi(count, 1),
		"median_step": median_ticks * REFERENCE_STEP,
		"maximum_step": float(steps[-1]) * REFERENCE_STEP if not steps.is_empty() else 0.0,
		"rejected_effort_fraction": float(delta.get("rejected_usec", 0)) / maxf(wall * 1e6, 1.0),
		"numeric": Metrics.numeric(state, manager), "active_generators": active,
		"enabled_automation_count": automation_count, "modifiers": modifiers,
		"thresholds": {"heat": state.realm_effects.heat_leak_threshold,
			"matter": state.realm_effects.matter_decay_threshold, "ash": state.get_resource_threshold(ResourceIds.ASH)},
		"retained_samples": samples.size()}
	segments.append(record)
	if segment_callback.is_valid():
		segment_callback.call(record)
	_counter_start = snapshot
	_widths.clear()
	_adaptive_ticks = 0
	_segment_start_tick = tick
	_segment_start_usec = Time.get_ticks_usec()
