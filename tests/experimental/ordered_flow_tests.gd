extends RefCounted

const Fixtures = preload("res://tests/experimental/ordered_flow_fixtures.gd")
const Batch = preload("res://tests/experimental/ordered_flow_batch.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const Oracle = preload("res://tests/experimental/transaction_tests.gd")
const Metrics = preload("res://tests/experimental/adaptive_metrics.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var failures: Array[String] = []
var rows: Array[Dictionary] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func run_all() -> Dictionary:
	var output_tick: int = Fixtures.first_output_tick()
	check(output_tick > 0, "Early fixture has no real integer Matter output")
	for ticks: int in [2, 5, 10]:
		for prefix: int in [0, maxi(0, output_tick - 1)]:
			_interval("early", ticks, prefix)
		for label: String in Fixtures.TARGETS:
			_interval(label, ticks, 0)
	for label: String in ["mid", "forge_competing"]:
		_interval(label, 10, 0)
	var idle_result: Dictionary = _idle()
	_accumulator_counterexample()
	var drift: Dictionary = _drift(10, 1000)
	return {"failures": failures, "first_matter_output_tick": output_tick, "intervals": rows, "unvalidated_drift": drift, "idle_control": idle_result}


func _context(label: String, prefix: int) -> Dictionary:
	var simulation := Simulation.new(Fixtures.make_state(label, prefix))
	var journal: RefCounted = Events.new()
	journal.attach(simulation)
	return {"simulation": simulation, "journal": journal}


func view(simulation: Simulation, initial_matter_produced: float) -> Dictionary:
	var state: GameState = simulation.state
	var phases: Dictionary = {}
	var feedback: Dictionary = {}
	for generator: Generator in state.generators.values():
		phases[generator.definition.id] = generator.production_progress.duplicate(true)
		for modifier: Modifier in generator.modifiers:
			if modifier.dynamic and modifier.dynamic_resource_id == ResourceIds.MATTER:
				feedback[generator.definition.id + "/" + modifier.id] = modifier.get_effective_multiplier(state, generator)
	return {"numeric": Metrics.numeric(state), "discrete": Metrics.discrete(state), "phases": phases, "feedback": feedback, "matter_units": state.resource_statistics.get_total_produced(ResourceIds.MATTER) - initial_matter_produced, "rng": [state.gameplay_rng.seed, state.gameplay_rng.state]}


func _interval(label: String, ticks: int, prefix: int) -> void:
	var candidate: Dictionary = _context(label, prefix)
	var control: Dictionary = _context(label, prefix)
	var simulation: Simulation = candidate["simulation"]
	var reference: Simulation = control["simulation"]
	var oracle: RefCounted = Oracle.new()
	var before: PackedByteArray = oracle.fingerprint(simulation, candidate["journal"])
	var produced: float = simulation.state.resource_statistics.get_total_produced(ResourceIds.MATTER)
	var initial: Dictionary = view(simulation, produced)
	var batch: RefCounted = Batch.new(simulation, candidate["journal"])
	var plan: Dictionary = batch.evaluate(ticks)
	var output_ticks: Array[int] = []
	for tick: int in range(ticks):
		var previous_units: float = reference.state.resource_statistics.get_total_produced(ResourceIds.MATTER)
		reference.update(STEP, true)
		if reference.state.resource_statistics.get_total_produced(ResourceIds.MATTER) != previous_units:
			output_ticks.append(tick + 1)
	var exact: Dictionary = view(reference, produced)
	var result: Dictionary = {"label": label, "prefix": prefix, "ticks": ticks, "scope": plan["scope"], "exact_matter_units": exact["matter_units"], "exact_output_ticks_within_interval": output_ticks, "actual_matter_feedback_changed": initial["feedback"] != exact["feedback"]}
	if plan["scope"] == "":
		var raw: Dictionary = view(simulation, produced)
		result.merge({"candidate_matter_units": raw["matter_units"], "integer_parity": raw["matter_units"] == exact["matter_units"], "phase_parity": raw["phases"] == exact["phases"], "max_phase_error": phase_error(exact["phases"], raw["phases"]), "discrete_parity": raw["discrete"] == exact["discrete"], "rng_parity": raw["rng"] == exact["rng"], "error": Metrics.compare(exact["numeric"], raw["numeric"], 1e-8, 1e-4), "heat_error": raw["numeric"]["resource/heat"] - exact["numeric"]["resource/heat"], "matter_error": raw["numeric"]["resource/matter"] - exact["numeric"]["resource/matter"], "certificate": plan["certificate"]})
		if label == "early" and prefix > 0:
			check(exact["matter_units"] > 0.0 and initial["feedback"] != exact["feedback"], "Output witness does not exercise changing Matter-held Heat production")
			check(not result["phase_parity"] and float(result["error"]["normalized"]) > 1.0, "Ordered macro counterexample no longer exceeds the existing target")
		check(not batch.certificate.is_empty(), "Nonzero real-flow interval was admitted without a proof")
		check(batch.resolve(), "Rollback failed")
		check(oracle.fingerprint(simulation, candidate["journal"]) == before, "Immediate rollback differs: " + label)
	batch.exact(ticks)
	check(oracle.fingerprint(simulation, candidate["journal"]) == oracle.fingerprint(reference, control["journal"]), "Fallback full-state/event/RNG parity failed: " + label)
	for tick: int in range(20):
		simulation.update(STEP, true)
		reference.update(STEP, true)
	check(oracle.fingerprint(simulation, candidate["journal"]) == oracle.fingerprint(reference, control["journal"]), "Resumed authoritative behavior differs: " + label)
	check(oracle.failures.is_empty(), "Reference fingerprint failure")
	rows.append(result)


func _idle() -> Dictionary:
	var candidate: Dictionary = _context("early", 0)
	var control: Dictionary = _context("early", 0)
	for context: Dictionary in [candidate, control]:
		for generator: Generator in context["simulation"].state.generators.values():
			if not generator.manually_paused:
				context["simulation"].toggle_generator_pause(generator.definition.id)
	var batch: RefCounted = Batch.new(candidate["simulation"], candidate["journal"])
	var oracle: RefCounted = Oracle.new()
	var samples: Array[Dictionary] = []
	for ticks: int in [2, 5, 10]:
		for repeat: int in range(20):
			var before: Dictionary = batch.counters.duplicate(true)
			check(batch.advance(ticks), "Idle control failed")
			samples.append({"ticks": ticks, "capture_usec": batch.counters["capture_usec"] - before["capture_usec"], "candidate_usec": batch.counters["candidate_usec"] - before["candidate_usec"], "commit_usec": batch.counters["commit_usec"] - before["commit_usec"]})
			for tick: int in range(ticks):
				control["simulation"].update(STEP, true)
			check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), "Repeated idle commits differ")
	check(batch.counters["accepted"] == 60, "Idle invariant was not exercised")
	check(not batch.resolve() and batch.evaluate(1)["scope"] != "", "Invalid lifecycle accepted")
	return {"diagnostic_only": true, "counters": batch.counters.duplicate(true), "samples": samples}


func _accumulator_counterexample() -> void:
	# Binary64 boundary probe only, not a gameplay fixture. Multiplication is
	# not repeated rounded addition even when the physical rate is constant.
	var step_amount: float = pow(2.0, -55.0)
	var phase: float = 1.0 - 4.0 * step_amount
	var repeated: float = phase
	for tick: int in range(2):
		repeated += step_amount
	var aggregate: float = phase + 2.0 * step_amount
	check(floorf(repeated) != floorf(aggregate), "Accumulator floor witness no longer distinguishes rounded recurrence")
	# Record the example, without relying on the optimizer's constant folding.
	rows.append({"label": "binary64_accumulator", "ticks": 2, "repeated": repeated, "aggregate": aggregate, "repeated_floor": floorf(repeated), "aggregate_floor": floorf(aggregate), "repeated_binary64_variant": var_to_bytes(repeated).hex_encode(), "aggregate_binary64_variant": var_to_bytes(aggregate).hex_encode(), "integer_parity": floorf(repeated) == floorf(aggregate), "phase_parity": repeated == aggregate})


func _drift(ticks: int, batches: int) -> Dictionary:
	var candidate: Dictionary = _context("early", 0)
	var control: Dictionary = _context("early", 0)
	var raw: RefCounted = Batch.new(candidate["simulation"], candidate["journal"])
	var produced: float = candidate["simulation"].state.resource_statistics.get_total_produced(ResourceIds.MATTER)
	var samples: Array[Dictionary] = []
	for index: int in range(batches):
		# Explicitly UNVALIDATED disposable research copy. Not a forced commit
		# or coverage result from the safe transaction API.
		raw.apply_aggregate(float(ticks) * STEP)
		for tick: int in range(ticks):
			control["simulation"].update(STEP, true)
		if index in [0, 9, 99, 999]:
			var a: Dictionary = view(control["simulation"], produced)
			var b: Dictionary = view(candidate["simulation"], produced)
			samples.append({"batches": index + 1, "integer_parity": a["matter_units"] == b["matter_units"], "phase_parity": a["phases"] == b["phases"], "max_phase_error": phase_error(a["phases"], b["phases"]), "error": Metrics.compare(a["numeric"], b["numeric"], 1e-8, 1e-4), "heat_error": b["numeric"]["resource/heat"] - a["numeric"]["resource/heat"], "matter_error": b["numeric"]["resource/matter"] - a["numeric"]["resource/matter"]})
	var future_difference: int = -1
	for tick: int in range(1, 10001):
		var a_before: float = control["simulation"].state.resource_statistics.get_total_produced(ResourceIds.MATTER)
		var b_before: float = candidate["simulation"].state.resource_statistics.get_total_produced(ResourceIds.MATTER)
		control["simulation"].update(STEP, true)
		candidate["simulation"].update(STEP, true)
		if control["simulation"].state.resource_statistics.get_total_produced(ResourceIds.MATTER) - a_before != candidate["simulation"].state.resource_statistics.get_total_produced(ResourceIds.MATTER) - b_before:
			future_difference = tick
			break
	return {"unvalidated_not_accepted": true, "ticks_per_batch": ticks, "samples": samples, "future_exact_ticks_to_matter_output_difference": future_difference, "future_search_limit": 10000}


func phase_error(reference: Dictionary, candidate: Dictionary) -> float:
	var worst: float = 0.0
	for id: String in reference:
		for resource_id: String in reference[id]:
			worst = maxf(worst, absf(float(reference[id][resource_id]) - float(candidate[id].get(resource_id, 0.0))))
	return worst
