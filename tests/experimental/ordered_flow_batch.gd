extends RefCounted

# Guarded research candidate. One ordered generator-major pass, not n ticks.
# Nonzero flows currently have no equivalence certificate and MUST roll back.
const Transaction = preload("res://tests/experimental/simulation_transaction.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
const PARTIAL_EPSILON: float = 0.000001 # Same flag boundary as Simulation.update.
var simulation: Simulation
var transaction: RefCounted
var pending: bool = false
var _pending_ticks: int = 0
var certificate: String = ""
var counters: Dictionary = {"capture_usec": 0, "candidate_usec": 0, "commit_usec": 0, "rollback_usec": 0, "fallback_usec": 0, "guard_usec": 0, "accepted": 0, "rejected": 0, "ineligible": 0, "batched_ticks": 0, "exact_ticks": 0, "reasons": {}}


func _init(target: Simulation, journal: RefCounted = null) -> void:
	simulation = target
	transaction = Transaction.new(target, journal)


func inspect() -> Dictionary:
	var state: GameState = simulation.state
	if simulation.profiling_enabled or simulation.diagnostics_enabled:
		return {"scope": "instrumented_simulation"}
	for manager: Variant in [state.generator_automation_manager, state.upgrade_automation_manager]:
		for item: Dictionary in manager.automation_states.values():
			if bool(item["enabled"]):
				return {"scope": "enabled_automation"}
	if not state.relic_manager.inventory.is_empty():
		return {"scope": "relic_state"}
	for slots: Variant in state.relic_manager.equipped.values() + state.relic_manager.machine_slots.values():
		if not slots.is_empty():
			return {"scope": "relic_slots"}
	var idle: bool = true
	var changed: Dictionary = {}
	var dependencies: Array[Dictionary] = []
	for generator: Generator in state.generators.values():
		if generator.cycle_active or generator.auto_run_cycles:
			return {"scope": "cycle_or_auto_run"}
		if not generator.unlocked or generator.definition.cycle_based:
			continue
		var active: bool = generator.operating or (generator.level > 0 and not generator.manually_paused)
		if not active:
			continue
		idle = false
		for input: GeneratorIO in generator.get_active_inputs():
			# This milestone's only consuming flow is Heat allocation. Rejects
			# Ash-input throttling and other consumers without naming generators.
			if input.resource_id != ResourceIds.HEAT:
				return {"scope": "unsupported_input/" + input.resource_id}
			changed[input.resource_id] = true
		for output: GeneratorIO in generator.get_active_outputs():
			if not output.unlocked:
				continue
			if output.resource_id not in [ResourceIds.HEAT, ResourceIds.MATTER, ResourceIds.ASH]:
				return {"scope": "unsupported_output/" + output.resource_id}
			changed[output.resource_id] = true
			dependencies.append({"generator": generator.definition.id, "output": output.resource_id, "discrete": output.discrete})
		for modifier: Modifier in generator.modifiers:
			if modifier.dynamic:
				dependencies.append({"generator": generator.definition.id, "formula": modifier.dynamic_formula, "resource": modifier.dynamic_resource_id})
	var environment: bool = state.get_heat_leak_per_second() > 0.0 or state.get_matter_decay_per_second() > 0.0
	if environment:
		idle = false
	for upgrade: Upgrade in state.upgrades.values():
		if upgrade.definition.automatic and not upgrade.is_maxed() and state.upgrade_system.requirements_met(upgrade.definition.requirements):
			idle = false
	return {"scope": "", "idle": idle, "changed": changed, "dependencies": dependencies, "environment": environment}


func evaluate(ticks: int) -> Dictionary:
	if pending or ticks < 2:
		return {"scope": "invalid_interval_or_lifecycle"}
	var started: int = Time.get_ticks_usec()
	var plan: Dictionary = inspect()
	counters["guard_usec"] += Time.get_ticks_usec() - started
	if plan["scope"] != "":
		return plan
	started = Time.get_ticks_usec()
	if not transaction.begin():
		counters["capture_usec"] += Time.get_ticks_usec() - started
		return {"scope": "checkpoint/" + transaction.error}
	counters["capture_usec"] += Time.get_ticks_usec() - started
	pending = true
	_pending_ticks = ticks
	started = Time.get_ticks_usec()
	apply_aggregate(float(ticks) * STEP)
	counters["candidate_usec"] += Time.get_ticks_usec() - started
	# Idle is the only proven invariant map here. Numeric closeness, matching
	# endpoint counts or step doubling are NOT certificates for future floors.
	certificate = "" if bool(plan["idle"]) else "ordered_recurrence_not_certified"
	plan["certificate"] = certificate
	return plan


func resolve() -> bool:
	if not pending:
		return false
	var started: int = Time.get_ticks_usec()
	if certificate.is_empty():
		var committed: bool = transaction.commit()
		counters["commit_usec"] += Time.get_ticks_usec() - started
		if not committed:
			return false
		counters["accepted"] += 1
		counters["batched_ticks"] += _pending_ticks
	else:
		if not transaction.rollback():
			# Keep the active checkpoint and surface failure; never exact-fallback
			# over a failed restoration.
			return false
		counters["rollback_usec"] += Time.get_ticks_usec() - started
		counters["rejected"] += 1
		_reason(certificate)
	pending = false
	return true


func advance(ticks: int) -> bool:
	var plan: Dictionary = evaluate(ticks)
	if plan["scope"] != "":
		if plan["scope"] == "invalid_interval_or_lifecycle":
			return false
		counters["ineligible"] += 1
		_reason(plan["scope"])
	else:
		var accepted: bool = certificate.is_empty()
		if not resolve():
			return false
		if accepted:
			return true
	exact(ticks)
	return true


func exact(ticks: int) -> void:
	var started: int = Time.get_ticks_usec()
	for tick: int in range(ticks):
		simulation.update(STEP, true)
	counters["fallback_usec"] += Time.get_ticks_usec() - started
	counters["exact_ticks"] += ticks


func _reason(reason: String) -> void:
	counters["reasons"][reason] = int(counters["reasons"].get(reason, 0)) + 1


func apply_aggregate(duration: float) -> void:
	# RAW NUMERICAL KERNEL, not a safe admission API. Only evaluate/resolve or
	# advance supplies a transaction. Validation may call it on disposable copies.
	var state: GameState = simulation.state
	var heat_start: float = state.get_resource_amount(ResourceIds.HEAT)
	state.track_gameplay_interval_statistics = false
	if simulation._gameplay_snapshot_realm_run_index != state.gameplay_realm_run_index:
		simulation._gameplay_snapshot_elapsed = 0.0
		simulation._gameplay_snapshot_realm_run_index = state.gameplay_realm_run_index
		state.take_gameplay_interval_statistics()
	simulation.update_automatic_upgrades(true)
	for generator: Generator in state.generators.values():
		if not generator.unlocked:
			continue
		simulation._update_lava_mite_throttle_state(generator)
		if generator.definition.cycle_based:
			continue # Scope check excludes active cycles and auto-run.
		if not generator.operating:
			if not generator.can_start_operating(state, true):
				continue
			generator.operating = true
		var available: float = simulation._get_available_operating_delta(generator, duration)
		if available <= 0.0:
			generator.operating = false
			continue
		simulation.consume_inputs(generator, available)
		simulation.produce_outputs(generator, available)
		if available < duration - PARTIAL_EPSILON:
			generator.operating = false
	simulation.apply_environmental_effects(duration, heat_start)
	# Disabled managers still initialize their structural indexes normally.
	state.generator_automation_manager.update(duration, simulation, true)
	state.upgrade_automation_manager.update(duration, simulation, true)
	if not simulation._gameplay_was_offline:
		simulation._gameplay_snapshot_elapsed = 0.0
		state.take_gameplay_interval_statistics()
		simulation._gameplay_was_offline = true
