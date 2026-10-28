extends SceneTree

const Fixtures = preload("res://tests/experimental/ordered_flow_fixtures.gd")
const Kernel = preload("res://tests/experimental/exact_flow_kernel.gd")
const Packet = preload("res://tests/experimental/exact_flow_packet.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const Existing = preload("res://tests/experimental/core_investigation_runner.gd")
const Oracle = preload("res://tests/experimental/transaction_tests.gd")
const Metrics = preload("res://tests/experimental/adaptive_metrics.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _context(label: String, prefix: int) -> Dictionary:
	var simulation := Simulation.new(Fixtures.make_state("early" if label == "early_event" else label, prefix))
	simulation.state.simulation_statistics = ResourceStatistics.new()
	var journal: RefCounted = Events.new()
	journal.attach(simulation)
	return {"simulation": simulation, "journal": journal}


func _run() -> void:
	var rows: Array[Dictionary] = []
	for label: String in ["early", "early_event", "mid", "forge_competing"]:
		var horizons: Array[int] = [2000]
		if label == "early":
			horizons = [1, 10, 2000, 36000]
		for ticks: int in horizons:
			for repeat: int in range(4):
				var order: Array[String] = ["exact", "isolated", "kernel", "existing"]
				if repeat % 2 == 1:
					order.reverse()
				var contexts: Dictionary = {}
				var run_rows: Array[Dictionary] = []
				for kind: String in order:
					var context: Dictionary = _context(label, 68 if label == "early_event" else 0)
					var simulation: Simulation = context["simulation"]
					var runner: RefCounted = null
					var packet: RefCounted = null
					var packet_bytes: int = 0
					var packet_usec: int = 0
					var omitted_build_usec: int = 0
					var isolated_ticks: int = 0
					var isolated_fallback: int = 0
					if kind == "kernel":
						runner = Kernel.new(simulation, context["journal"])
					elif kind == "existing":
						runner = Existing.new(simulation)
						runner.overrides = {"short_exact_seconds": 0.0}
					elif kind == "isolated":
						var memory_before: int = OS.get_static_memory_usage()
						var build_started: int = Time.get_ticks_usec()
						packet = Packet.new()
						if not packet.build(simulation, context["journal"]):
							packet = null
						packet_usec = Time.get_ticks_usec() - build_started
						packet_bytes = OS.get_static_memory_usage() - memory_before
					var started: int = Time.get_ticks_usec()
					if kind == "exact":
						for tick: int in range(ticks):
							simulation.update(STEP, true)
					elif kind == "isolated":
						var unavailable: bool = packet == null
						for tick: int in range(ticks):
							if packet != null and packet.event_due():
								packet = null
								simulation.update(STEP, true)
								isolated_fallback += 1
								var build_started: int = Time.get_ticks_usec()
								packet = Packet.new()
								if not packet.build(simulation, context["journal"]):
									packet = null
									unavailable = true
								omitted_build_usec += Time.get_ticks_usec() - build_started
							elif unavailable:
								simulation.update(STEP, true)
								isolated_fallback += 1
							else:
								packet.step()
								isolated_ticks += 1
					elif kind == "kernel":
						runner.run(ticks)
					else:
						runner.run(float(ticks) * STEP)
						if runner.counters.get("strict_failure", "") != "":
							failures.append("Existing strict failure")
					var wall_usec: int = Time.get_ticks_usec() - started - omitted_build_usec
					contexts[kind] = context
					run_rows.append({"label": label, "ticks": ticks, "kind": kind, "repeat": repeat, "warmup": repeat == 0, "wall_usec": wall_usec, "packet_build_usec": packet_usec, "packet_heap_delta_bytes": packet_bytes, "kernel_ticks": int(runner.counters.get("kernel_ticks", 0)) if runner != null else isolated_ticks, "fallback_ticks": int(runner.counters.get("fallback_ticks", 0)) if runner != null else isolated_fallback, "counters": runner.counters.duplicate(true) if runner != null else {}})
				var oracle: RefCounted = Oracle.new()
				for row: Dictionary in run_rows:
					var candidate: Dictionary = contexts[row["kind"]]
					row["full_binary_parity"] = oracle.fingerprint(contexts["exact"]["simulation"], contexts["exact"]["journal"]) == oracle.fingerprint(candidate["simulation"], candidate["journal"])
					row["numeric_error"] = Metrics.compare(Metrics.numeric(contexts["exact"]["simulation"].state), Metrics.numeric(candidate["simulation"].state), 1e-8, 1e-4)
					row["discrete_parity"] = Metrics.discrete(contexts["exact"]["simulation"].state) == Metrics.discrete(candidate["simulation"].state)
					row["rng_parity"] = contexts["exact"]["simulation"].state.gameplay_rng.state == candidate["simulation"].state.gameplay_rng.state
					if row["kind"] in ["kernel", "isolated"] and not row["full_binary_parity"]:
						failures.append("Kernel benchmark parity: " + label + "/" + str(ticks) + "/" + row["kind"])
					rows.append(row)
				if not oracle.failures.is_empty():
					failures.append_array(oracle.failures)
	var phase_profiles: Array[Dictionary] = []
	for label: String in ["early", "mid", "forge_competing"]:
		var context: Dictionary = _context(label, 0)
		var measured: RefCounted = Kernel.new(context["simulation"], context["journal"])
		measured.measure_phases = true
		measured.run(2000)
		phase_profiles.append({"label": label, "intrusive": true, "ticks": 2000, "counters": measured.counters.duplicate(true)})
	var output := FileAccess.open("res://tests/experimental/exact_flow_benchmark_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine": Engine.get_version_info(), "cpu": OS.get_processor_name(), "runs": rows, "phase_profiles": phase_profiles, "failures": failures}, "\t") + "\n")
	output.close()
	for failure: String in failures:
		push_error(failure)
	print("EXACT_FLOW_BENCHMARK failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)
