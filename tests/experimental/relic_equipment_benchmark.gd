extends SceneTree

const Tests = preload("res://tests/experimental/relic_equipment_tests.gd")
const Kernel = Tests.Kernel
const Packet = Tests.Packet
const Previous = Tests.Previous
const Adaptive = preload("res://tests/experimental/core_investigation_runner.gd")
const NativeProbe = preload("res://tests/experimental/cycle_native_probe.gd")
const Events = Tests.Events
const View = Tests.View
const Oracle = Tests.Oracle
const Metrics = preload("res://tests/experimental/adaptive_metrics.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rows: Array[Dictionary] = []
	var observations: Array[Dictionary] = []
	var scenarios: Array[Array] = [["early", 2000], ["early", 36000], ["consumer_50000", 2000], ["consumer_50000", 10000], ["mid", 2000], ["mid", 10000], ["forge_competing", 2000], ["forge_competing", 10000], ["earned_essence", 10000], ["earned_feedback", 10000], ["passive", 2000], ["one", 2000], ["multiple", 2000], ["input_compressor", 2000], ["sensitivity", 2000], ["forge_critical", 2000], ["forge_speed", 2000], ["forge_sensitivity", 2000], ["forge_completion", 2000], ["forge_auto", 3000], ["essence_relics", 2000], ["nexum_relics", 2000], ["relic_heavy", 2000], ["reached_one", 10000], ["reached_multiple", 10000], ["equipment_changes", 2000], ["crafting", 2000]]
	var confirmation: bool = OS.get_environment("RELIC_BENCH_CONFIRM") == "1"
	if confirmation:
		scenarios = [["early", 2000], ["forge_competing", 10000]]
	if OS.get_environment("RELIC_BENCH_QUICK") == "1":
		scenarios = [["one", 100], ["equipment_changes", 100], ["forge_completion", 100]]
	for scenario: Array in scenarios:
		var label: String = scenario[0]
		var ticks: int = scenario[1]
		for repeat: int in range(7 if confirmation else 4):
			var methods: Array[String] = ["exact", "previous", "extended", "adaptive"]
			if label == "equipment_changes":
				# Adaptive reference requires a fresh TimeManager per public interval.
				# Repeated external equipment boundaries are outside that API.
				methods.erase("adaptive")
			if repeat % 2 == 1:
				methods.reverse()
			var contexts: Dictionary = {}
			var results: Array[Dictionary] = []
			for kind: String in methods:
				var item: Dictionary = Tests.context("one" if label == "equipment_changes" else label)
				contexts[kind] = item
				var simulation: Simulation = item["simulation"]
				var runner: RefCounted = null
				if kind == "extended":
					runner = Kernel.new(simulation, item["journal"])
				elif kind == "previous":
					runner = Previous.new(simulation, item["journal"])
				elif kind == "adaptive":
					runner = Adaptive.new(simulation)
					runner.overrides = {"short_exact_seconds": 0.0}
				var started: int = Time.get_ticks_usec()
				if label == "equipment_changes":
					for block: int in range(int(ticks / 20.0)):
						_change_equipment(simulation, block)
						_advance(kind, runner, simulation, 20)
				else:
					_advance(kind, runner, simulation, ticks)
				var elapsed: int = Time.get_ticks_usec() - started
				results.append({"label": label, "ticks": ticks, "kind": kind, "repeat": repeat, "warmup": repeat == 0, "wall_usec": elapsed, "counters": runner.counters.duplicate(true) if runner != null else {}})
			var oracle: RefCounted = Oracle.new()
			var expected: PackedByteArray = oracle.fingerprint(contexts["exact"]["simulation"], contexts["exact"]["journal"])
			for result: Dictionary in results:
				var item: Dictionary = contexts[result["kind"]]
				result["binary_parity"] = expected == oracle.fingerprint(item["simulation"], item["journal"])
				result["numeric_deviation"] = Metrics.compare(Metrics.numeric(contexts["exact"]["simulation"].state), Metrics.numeric(item["simulation"].state), 1e-8, 1e-4)
				result["discrete_parity"] = Metrics.discrete(contexts["exact"]["simulation"].state) == Metrics.discrete(item["simulation"].state)
				result["event_parity"] = var_to_bytes(contexts["exact"]["journal"].events) == var_to_bytes(item["journal"].events)
				result["rng_parity"] = contexts["exact"]["simulation"].state.gameplay_rng.state == item["simulation"].state.gameplay_rng.state
				if result["kind"] != "adaptive" and not result["binary_parity"]:
					failures.append("Benchmark full graph mismatch: " + label + "/" + str(ticks) + "/" + result["kind"])
				rows.append(result)
			failures.append_array(oracle.failures)
		# Intrusive measurements are separate from throughput. No allocation
		# estimate or phase clock is subtracted from public execution timings.
		var item: Dictionary = Tests.context("one" if label == "equipment_changes" else label)
		var before: int = OS.get_static_memory_usage()
		var started: int = Time.get_ticks_usec()
		var packet: RefCounted = Packet.new()
		var admitted: bool = packet.build(item["simulation"], item["journal"])
		var construction_usec: int = Time.get_ticks_usec() - started
		var allocation_estimate: int = OS.get_static_memory_usage() - before
		packet = null
		before = OS.get_static_memory_usage()
		started = Time.get_ticks_usec()
		var previous_packet: RefCounted = preload("res://tests/experimental/baselines/exact_flow_eeb85dc_packet.gd").new()
		var previous_admitted: bool = previous_packet.build(item["simulation"], item["journal"])
		var previous_build_usec: int = Time.get_ticks_usec() - started
		var previous_allocation_estimate: int = OS.get_static_memory_usage() - before
		previous_packet = null
		var runner: RefCounted = Kernel.new(item["simulation"], item["journal"])
		runner.measure_phases = true
		runner.collect_flow_counters = true
		if label == "equipment_changes":
			for block: int in range(int(ticks / 20.0)):
				_change_equipment(item["simulation"], block)
				runner.run(20)
		else:
			runner.run(ticks)
		var native: Dictionary = Tests.context("one" if label == "equipment_changes" else label)
		native["simulation"] = NativeProbe.new(native["simulation"].state)
		native["journal"] = Events.new()
		native["journal"].attach(native["simulation"])
		var initial_rng: int = native["simulation"].state.gameplay_rng.state
		for tick: int in range(ticks):
			if label == "equipment_changes" and tick % 20 == 0:
				_change_equipment(native["simulation"], int(tick / 20.0))
			native["simulation"].update(STEP, true)
		if View.capture(native["simulation"], native["journal"], true) != View.capture(item["simulation"], item["journal"], true):
			failures.append("Instrumentation parity: " + label)
		var critical: int = 0
		var normal: int = 0
		for event: Dictionary in native["journal"].events:
			critical += 1 if event["event"] == "critical" else 0
			normal += 1 if event["event"] == "normal" else 0
		observations.append({"label": label, "ticks": ticks, "intrusive_untimed": true, "admitted": admitted, "previous_admitted": previous_admitted, "previous_packet_build_usec": previous_build_usec, "previous_packet_allocation_estimate_bytes": previous_allocation_estimate, "packet_build_usec": construction_usec, "packet_retained_allocation_estimate_bytes": allocation_estimate, "counters": runner.counters.duplicate(true), "flows": runner.flow_counts.duplicate(true), "external_equipment_boundaries": int(ticks / 20.0) if label == "equipment_changes" else 0, "cycle_activity": native["simulation"].metrics.duplicate(true), "rng_words": _rng_words(native["simulation"].state.gameplay_rng, initial_rng, ticks * 8), "critical_completions": critical, "normal_completions": normal})
		print("RELIC_BENCH_SCENARIO ", label, " ", ticks)
		_write(rows, observations)
	for failure: String in failures:
		push_error(failure)
	print("RELIC_EQUIPMENT_BENCHMARK failures=", failures.size())
	quit(0 if failures.is_empty() else 1)


func _advance(kind: String, runner: RefCounted, simulation: Simulation, ticks: int) -> void:
	if kind == "exact":
		for tick: int in range(ticks):
			simulation.update(STEP, true)
	elif kind == "adaptive":
		runner.run(float(ticks) * STEP)
		if runner.counters.get("strict_failure", "") != "":
			failures.append("Adaptive strict failure")
	else:
		runner.run(ticks)


func _change_equipment(simulation: Simulation, block: int) -> void:
	var state: GameState = simulation.state
	var id: String = str(state.relic_manager.inventory[0]["instance_id"])
	state.relic_manager.unequip_relic("atomic_friction")
	state.relic_manager.unequip_relic("molecular_agitation")
	if block % 3 != 0:
		if not state.relic_manager.equip_relic("atomic_friction" if block % 3 == 1 else "molecular_agitation", id, state):
			failures.append("Native equipment boundary failed")
	state.rebuild_relic_modifiers()


func _rng_words(rng: RandomNumberGenerator, initial: int, limit: int) -> int:
	var replay := RandomNumberGenerator.new()
	replay.seed = rng.seed
	replay.state = initial
	for count: int in range(limit + 1):
		if replay.state == rng.state:
			return count
		replay.randi()
	failures.append("Unable to reconstruct native RNG word count")
	return -1


func _write(rows: Array[Dictionary], observations: Array[Dictionary]) -> void:
	var path: String = "res://tests/experimental/relic_equipment_benchmark_quick.json" if OS.get_environment("RELIC_BENCH_QUICK") == "1" else "res://tests/experimental/relic_equipment_benchmark_results.json"
	if OS.get_environment("RELIC_BENCH_CONFIRM") == "1":
		path = "res://tests/experimental/relic_equipment_benchmark_confirmation_results.json"
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine": Engine.get_version_info(), "cpu": OS.get_processor_name(), "runs": rows, "observations": observations, "failures": failures}, "\t") + "\n")
