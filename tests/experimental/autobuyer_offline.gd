extends "res://tests/experimental/horizon_runner.gd"

const Boundary = preload("res://tests/experimental/autobuyer_boundary.gd")
var event_automation_enabled: bool = true
# Benchmark control only; default skips checks whose zero timer is invariant.
var replay_waiting_upgrade_checks: bool = false
var skipped_upgrade_checks: int = 0
var boundary_calls: int = 0
var boundary_usec: int = 0
var boundary_reasons: Dictionary = {}
var skipped_waiting_checks: int = 0
var cooldown_replay_usec: int = 0
var cooldown_replay_ticks: int = 0
var _proof: Dictionary = {}
var _in_trial: bool = false
var _reference_elapsed: float = 0.0
var _grid_tick: int = 0
var requested_audits: Dictionary = {}


func run(seconds: float) -> Dictionary:
	_grid_tick = 0
	_reference_elapsed = 0.0
	_in_trial = false
	boundary_calls = 0
	boundary_usec = 0
	boundary_reasons.clear()
	skipped_waiting_checks = 0
	skipped_upgrade_checks = 0
	cooldown_replay_usec = 0
	cooldown_replay_ticks = 0
	var result: Dictionary = super(seconds)
	result["automation_boundary"] = {"calls": boundary_calls, "usec": boundary_usec,
		"reasons": boundary_reasons.duplicate(), "skipped_waiting_checks": skipped_waiting_checks,
		"cooldown_replay_usec": cooldown_replay_usec, "cooldown_replay_ticks": cooldown_replay_ticks,
		"skipped_upgrade_checks": skipped_upgrade_checks, "replay_waiting_upgrade_checks": replay_waiting_upgrade_checks}
	return result


func _automation_guard() -> String:
	if not event_automation_enabled:
		return super()
	var start: int = Time.get_ticks_usec()
	_proof = Boundary.inspect(simulation)
	boundary_usec += Time.get_ticks_usec() - start
	boundary_calls += 1
	var status: String = _proof["status"]
	boundary_reasons[status] = int(boundary_reasons.get(status, 0)) + 1
	return "" if status in ["disabled", "provably_waiting"] else "automation_" + status


func _trial_active(active: bool) -> void:
	_in_trial = active


func _advance(delta: float, end: float) -> void:
	if not _in_trial:
		# Match the authoritative grid even after macro-step clock additions.
		var reference_delta: float = minf(REFERENCE_STEP, duration - _reference_elapsed)
		_reference_elapsed = minf(duration, _reference_elapsed + reference_delta)
		super(reference_delta, end)
		_grid_tick += 1
		if requested_audits.has(_grid_tick):
			_sample(_grid_tick)
		return
	# The proof applies to the entire interval. Trial probes must not mutate
	# cooldowns or waiting dictionaries; the restricted checkpoint omits them.
	# Temporarily suppress original managers, then restore flags and indices.
	var saved: Array[Dictionary] = []
	for automation in [simulation.state.generator_automation_manager, simulation.state.upgrade_automation_manager]:
		var flags: Dictionary = {}
		for id in automation.automation_states:
			flags[id] = automation.automation_states[id]["enabled"]
			automation.automation_states[id]["enabled"] = false
		saved.append(flags)
		automation.invalidate_offline_index()
	super(delta, end)
	var managers: Array = [simulation.state.generator_automation_manager, simulation.state.upgrade_automation_manager]
	for index in range(managers.size()):
		for id in saved[index]:
			managers[index].automation_states[id]["enabled"] = saved[index][id]
		managers[index].invalidate_offline_index()
	for id in _proof.get("upper", {}):
		if simulation.state.get_resource_amount(id) > float(_proof["upper"][id]):
			trial_failure_reason = "automation_invariant_violation"


func _commit_interval(ticks: int, _seconds: float) -> void:
	# The boundary guard requires every eligible upgrade timer to be zero.
	# With success-triggered cooldowns and no possible purchase, all waiting
	# state is invariant. Keep only reference-clock accumulation; the optional
	# replay control demonstrates binary parity with actual failed scans.
	_grid_tick += ticks
	var state: GameState = simulation.state
	for id in state.generator_automation_manager.automation_states:
		var entry: Dictionary = state.generator_automation_manager.automation_states[id]
		var generator: Generator = state.get_generator(id)
		if entry["enabled"] and entry["waiting_for_resources"] and state.generator_automation_manager.is_automation_unlocked(id) and generator != null and generator.unlocked:
			skipped_waiting_checks += ticks
	var enabled_upgrade: bool = false
	for id in state.upgrade_automation_manager.automation_states:
		var entry: Dictionary = state.upgrade_automation_manager.automation_states[id]
		if not entry["enabled"]:
			continue
		enabled_upgrade = true
		var generator: Generator = state.get_generator(id)
		if state.upgrade_automation_manager.is_automation_unlocked(id) and (id == UpgradeAutomationManager.GENERAL_TREE_ID or (generator != null and generator.unlocked)) and not replay_waiting_upgrade_checks:
			skipped_upgrade_checks += ticks
	var start: int = Time.get_ticks_usec()
	var events_before: int = state.gameplay_log.events.size()
	var rng_before: int = state.gameplay_rng.state
	for _index in range(ticks):
		var delta: float = minf(REFERENCE_STEP, duration - _reference_elapsed)
		_reference_elapsed = minf(duration, _reference_elapsed + delta)
		if enabled_upgrade and replay_waiting_upgrade_checks:
			state.upgrade_automation_manager.update(delta, simulation, true)
			cooldown_replay_ticks += 1
	cooldown_replay_usec += Time.get_ticks_usec() - start
	if state.gameplay_log.events.size() != events_before or state.gameplay_rng.state != rng_before:
		counters["strict_failure"] = "Unexpected automation commit event; discard this experimental state."
