extends RefCounted

# ISOLATED EXPERIMENT. Nothing in production preloads or calls this class.
# Step doubling estimates the error of the existing ordered update map. It is
# not a proof of accuracy relative to repeated 0.1 s updates: audit that separately.
const Metrics = preload("res://tests/experimental/adaptive_metrics.gd")
const Checkpoint = preload("res://tests/experimental/continuous_checkpoint.gd")
const REFERENCE_STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP

var maximum_step: float = 60.0
var minimum_step: float = REFERENCE_STEP
var absolute_tolerance: float = 1e-8
var relative_tolerance: float = 1e-4
var event_safety_margin: float = 0.1
var fallback_window_ticks: int = 10
var audit_interval: float = 60.0
var distribute_error_budget: bool = true
var force_exact: bool = false
var allow_environmental_feedback: bool = true
# Diagnostics are optional: per-attempt traces are excluded from throughput runs.
var numerical_retry_max_ticks: int = 0
var trial_failure_reason: String = ""
var trace_attempts: bool = false
var attempts: Array[Dictionary] = []
var profile_checkpoints: bool = false

var counters: Dictionary = {}
var samples: Dictionary = {}
var simulation: Simulation
var manager: TimeManager
var elapsed: float = 0.0
var duration: float = 0.0

func _init(game_simulation: Simulation) -> void:
	simulation = game_simulation
	manager = TimeManager.new(simulation)


# The default guard rejects consumers. The isolated resource-flow subclass
# overrides only that capability after proving an enclosing static-rate box.
# Discrete production and unproved stateful controllers still fall back.
func guard() -> String:
	var state: GameState = simulation.state
	if force_exact:
		return "forced_exact"
	if not allow_environmental_feedback and (state.get_heat_leak_per_second() > 0.0 or state.get_matter_decay_per_second() > 0.0):
		return "environmental_feedback"
	if simulation.profiling_enabled or simulation.diagnostics_enabled:
		return "instrumented_simulation"
	if state.prestige_planning:
		return "prestige_planning"
	var automation_reason: String = _automation_guard()
	if automation_reason != "":
		return automation_reason
	var changing: Dictionary = {}
	for g in state.generators.values():
		if g.cycle_active or g.auto_run_cycles:
			return "cycle_or_auto_run"
		if g.definition.cycle_based:
			continue
		if not g.unlocked:
			continue
		# Throttle flags can change even for paused/level-zero consumers.
		if not g.get_active_inputs().is_empty():
			var consumer_reason: String = _consumer_guard(g)
			if consumer_reason != "":
				return consumer_reason
			for input in g.get_active_inputs():
				changing[input.resource_id] = true
		if g.manually_paused and g.operating:
			return "pause_transition"
		if g.manually_paused or g.level <= 0:
			continue
		if not g.operating or g.is_throttled:
			return "operating_transition"
		for modifier in g.modifiers:
			if modifier.dynamic and modifier.dynamic_formula == Modifier.DYNAMIC_LAVA_MITE_DORMANCY:
				return "time_dependent_modifier"
		for output in g.get_active_outputs():
			if not output.unlocked:
				continue
			if output.discrete:
				return "discrete_production"
			changing[output.resource_id] = true
			if not state.is_resource_discovered(output.resource_id):
				return "discovery_boundary"
	if state.get_heat_leak_per_second() > 0.0:
		changing[ResourceIds.HEAT] = true
	if state.get_matter_decay_per_second() > 0.0:
		changing[ResourceIds.MATTER] = true
		changing[ResourceIds.HEAT] = true
	# Every pending automatic upgrade must have an immutable unmet requirement.
	# Otherwise evaluate exact ticks, including the original ordered application.
	for u in state.upgrades.values():
		if not u.definition.automatic or u.is_maxed():
			continue
		var blocked: bool = false
		for requirement in u.definition.requirements:
			if not state.upgrade_system.requirement_met(requirement):
				if requirement.type != RequirementTypes.RESOURCE or not changing.has(requirement.target_id):
					blocked = true
		if not blocked:
			return "automatic_resource_boundary"
	return ""


func _consumer_guard(_generator: Generator) -> String:
	return "resource_consumers"


func _automation_guard() -> String:
	for automation in [simulation.state.generator_automation_manager, simulation.state.upgrade_automation_manager]:
		for entry in automation.automation_states.values():
			if entry["enabled"]:
				return "enabled_automation"
	return ""


func _commit_interval(_ticks: int, _seconds: float) -> void:
	pass


func _trial_active(_active: bool) -> void:
	pass


# This standalone experiment owns a fresh, scale-one TimeManager context.
# Trials have no clock callbacks; commit the interval clocks with accepted time.
func _sync_clocks() -> void:
	manager.game_time = elapsed
	manager.offline_time = elapsed
	manager.prestige_time = elapsed
	manager.current_offline_duration = elapsed


func _signature() -> String:
	var started: int = Time.get_ticks_usec()
	var result: String = Metrics.discrete(simulation.state, false)
	counters["event_detection_usec"] += Time.get_ticks_usec() - started
	return result


func _advance(delta: float, end: float) -> void:
	simulation.state.set_lava_mite_dormancy_penalty(manager.get_dormancy_penalty(end))
	var started: int = Time.get_ticks_usec()
	simulation.update(delta, true)
	counters["numerical_usec"] += Time.get_ticks_usec() - started
	counters["evaluations"] += 1


func _sample(tick: int) -> void:
	if samples.has(tick):
		return
	var started: int = Time.get_ticks_usec()
	samples[tick] = {"numeric": Metrics.numeric(simulation.state, manager), "discrete": Metrics.discrete(simulation.state),
		"rng": str(simulation.state.gameplay_rng.state)}
	counters["audit_capture_usec"] += Time.get_ticks_usec() - started


func _capture_checkpoint() -> Dictionary:
	var start: int = Time.get_ticks_usec() if profile_checkpoints else 0
	var value: Dictionary = Checkpoint.capture(simulation)
	if profile_checkpoints:
		counters["all_capture_usec"] += Time.get_ticks_usec() - start
		counters["capture_calls"] += 1
	return value


func _restore_checkpoint(value: Dictionary) -> void:
	var start: int = Time.get_ticks_usec() if profile_checkpoints else 0
	Checkpoint.restore(simulation, value)
	if profile_checkpoints:
		counters["all_restore_usec"] += Time.get_ticks_usec() - start
		counters["restore_calls"] += 1


func _near_boundary_requires_exact(_resource: String, _before: float, _coarse: float, _fine: float) -> bool:
	return true


func _completed_interval(_ticks: int, _adaptive: bool) -> void:
	pass


func run(seconds: float) -> Dictionary:
	elapsed = 0.0
	duration = maxf(seconds, 0.0)
	samples.clear()
	attempts.clear()
	counters = {"evaluations": 0, "accepted": 0, "rejected": 0, "fallback_ticks": 0,
		"proven_margin_bypasses": 0, "fallback_reasons": {}, "rejection_reasons": {}, "rejection_fields": {}, "rejected_usec": 0, "event_detection_usec": 0, "trial_usec": 0, "fallback_usec": 0,
		"all_capture_usec": 0, "all_restore_usec": 0, "capture_calls": 0, "restore_calls": 0, "checkpoint_usec": 0, "numerical_usec": 0, "audit_capture_usec": 0, "initial_checkpoint_bytes": 0, "strict_failure": ""}
	var finite_configuration: bool = true
	for value in [seconds, maximum_step, minimum_step, absolute_tolerance, relative_tolerance, event_safety_margin, audit_interval]:
		finite_configuration = finite_configuration and is_finite(value)
	if not finite_configuration or not is_finite(maximum_step) or maximum_step < REFERENCE_STEP or minimum_step < REFERENCE_STEP or absolute_tolerance <= 0.0 or relative_tolerance < 0.0 or event_safety_margin < 0.0:
		counters["strict_failure"] = "Invalid experimental configuration; no simulation was performed."
		return counters
	if manager.time_scale != 1.0 or manager.stabilization_countdown_active or manager.dormancy_recovery_remaining != 0.0 or manager.game_time != 0.0:
		counters["strict_failure"] = "Unsupported TimeManager context; use a fresh scale-one experimental interval."
		return counters
	if duration <= 0.0:
		return counters
	var total_ticks: int = ceili(duration / REFERENCE_STEP)
	var audit_ticks: int = maxi(1, floori(audit_interval / REFERENCE_STEP))
	var max_ticks: int = maxi(1, floori(maximum_step / REFERENCE_STEP))
	var min_ticks: int = maxi(2, ceili(minimum_step / REFERENCE_STEP))
	var proposal: int = min_ticks
	var tick: int = 0
	var retry_ticks: int = 0
	simulation.state.simulation_statistics = manager.simulation_statistics
	simulation.prepare_offline()
	while tick < total_ticks:
		var completed_ticks: int = 0
		var completed_adaptive: bool = false
		var checkpoint_tick: int = mini(total_ticks, (floori(float(tick) / float(audit_ticks)) + 1) * audit_ticks)
		var start: int = Time.get_ticks_usec()
		var reason: String = guard()
		counters["event_detection_usec"] += Time.get_ticks_usec() - start
		var n: int = mini(mini(proposal, max_ticks), checkpoint_tick - tick)
		if reason != "" or n < min_ticks:
			start = Time.get_ticks_usec()
			var count: int = mini(maxi(maxi(1, fallback_window_ticks), retry_ticks), checkpoint_tick - tick)
			if reason == "" and retry_ticks > 0:
				reason = "numerical_retry_cooldown"
			for _index in range(count):
				var delta: float = minf(REFERENCE_STEP, duration - elapsed)
				if delta > 0.0:
					elapsed = minf(duration, elapsed + delta)
					_sync_clocks()
					_advance(delta, elapsed)
				tick += 1
				counters["fallback_ticks"] += 1
			counters["fallback_reasons"][reason if reason != "" else "minimum_step"] = int(counters["fallback_reasons"].get(reason if reason != "" else "minimum_step", 0)) + count
			counters["fallback_usec"] += Time.get_ticks_usec() - start
			proposal = min_ticks
			completed_ticks = count
		else:
			_trial_active(true)
			start = Time.get_ticks_usec()
			var attempt_start: int = start
			trial_failure_reason = ""
			var saved: Dictionary = _capture_checkpoint()
			counters["checkpoint_usec"] += Time.get_ticks_usec() - start
			if counters["initial_checkpoint_bytes"] == 0:
				counters["initial_checkpoint_bytes"] = var_to_bytes(saved).size()
			var signature: String = _signature()
			var rng: int = simulation.state.gameplay_rng.state
			var h: float = minf(float(n) * REFERENCE_STEP, duration - elapsed)
			start = Time.get_ticks_usec()
			_advance(h, elapsed + h)
			var coarse: Dictionary = Metrics.numeric(simulation.state)
			if _signature() != signature or simulation.state.gameplay_rng.state != rng:
				_trial_active(false)
				counters["strict_failure"] = "Unexpected coarse-trial discrete event; discard this experimental state."
				return counters
			_restore_checkpoint(saved)
			var first: float = float(n >> 1) * REFERENCE_STEP
			_advance(first, elapsed + first)
			_advance(h - first, elapsed + h)
			var fine: Dictionary = Metrics.numeric(simulation.state)
			counters["trial_usec"] += Time.get_ticks_usec() - start
			if _signature() != signature or simulation.state.gameplay_rng.state != rng:
				_trial_active(false)
				counters["strict_failure"] = "Unexpected fine-trial discrete event; discard this experimental state."
				return counters
			_trial_active(false)
			var error: float = 0.0
			var worst_field: String = ""
			var rejection_reason: String = "numerical_error"
			for key in coarse:
				if not fine.has(key):
					fine[key] = 0.0
			for key in fine:
				var a: float = float(coarse.get(key, 0.0))
				var b: float = float(fine[key])
				var budget: float = absolute_tolerance + relative_tolerance * maxf(absf(a), absf(b))
				if distribute_error_budget and not str(key).ends_with("highest_amount"):
					budget *= h / duration
				var value: float = absf(a - b) / maxf(budget, 1e-30) if is_finite(a) and is_finite(b) else INF
				if value > error:
					error = value
					worst_field = str(key)
			# Reject environmental threshold crossings, leaving the crossing on
			# the authoritative grid. Margin is in resource units, not seconds.
			for pair in [[ResourceIds.HEAT, simulation.state.realm_effects.heat_leak_threshold], [ResourceIds.MATTER, simulation.state.realm_effects.matter_decay_threshold]]:
				var before: float = saved["amounts"][pair[0]] - float(pair[1])
				var after: float = fine["resource/" + pair[0]] - float(pair[1])
				if before * after < 0.0 or (absf(after) < event_safety_margin and before != after and _near_boundary_requires_exact(pair[0], float(saved["amounts"][pair[0]]), float(coarse.get("resource/" + pair[0], fine["resource/" + pair[0]])), float(fine["resource/" + pair[0]]))):
					error = INF
					rejection_reason = "environmental_threshold"
			if trial_failure_reason != "":
				error = INF
				rejection_reason = trial_failure_reason
			if trace_attempts:
				attempts.append({"tick": tick, "ticks": n, "error": error, "field": worst_field, "reason": rejection_reason if error > 1.0 else "accepted", "usec": Time.get_ticks_usec() - attempt_start})
			if error <= 1.0:
				elapsed = minf(duration, elapsed + h)
				_sync_clocks()
				tick += n
				counters["accepted"] += 1
				retry_ticks = 0
				_commit_interval(n, h)
				if counters["strict_failure"] != "":
					return counters
				_sample(tick) # Audit every accepted endpoint, plus fixed checkpoints.
				proposal = mini(max_ticks, n * 2) if error < 0.25 else n
				completed_ticks = n
				completed_adaptive = true
			else:
				_restore_checkpoint(saved)
				counters["rejected"] += 1
				counters["rejected_usec"] += Time.get_ticks_usec() - attempt_start
				counters["rejection_reasons"][rejection_reason] = int(counters["rejection_reasons"].get(rejection_reason, 0)) + 1
				counters["rejection_fields"][worst_field] = int(counters["rejection_fields"].get(worst_field, 0)) + 1
				proposal = n >> 1
				if proposal < min_ticks and numerical_retry_max_ticks > 0:
					retry_ticks = mini(numerical_retry_max_ticks, maxi(fallback_window_ticks, retry_ticks * 2))
		if tick == checkpoint_tick:
			_sample(tick)
		if completed_ticks > 0:
			_completed_interval(completed_ticks, completed_adaptive)
	counters["fallback_fraction"] = float(counters["fallback_ticks"]) / float(total_ticks)
	return counters.duplicate(true)
