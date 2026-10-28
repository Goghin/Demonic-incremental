extends SceneTree

const Fixtures = preload("res://tests/experimental/ordered_flow_fixtures.gd")
const Batch = preload("res://tests/experimental/ordered_flow_batch.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const Existing = preload("res://tests/experimental/core_investigation_runner.gd")
const Oracle = preload("res://tests/experimental/transaction_tests.gd")
const Metrics = preload("res://tests/experimental/adaptive_metrics.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rows: Array[Dictionary] = []
	var output_tick: int = Fixtures.first_output_tick()
	if output_tick <= 0:
		failures.append("No integer-output witness")
	for label: String in ["early", "early_event", "mid", "forge_competing"]:
		for interval: int in [2, 5, 10]:
			for total: int in [interval, 600]:
				for repeat: int in range(4):
					var contexts: Dictionary = {}
					var order: Array[String] = ["exact", "existing", "batch"]
					if repeat % 2 == 1:
						order.reverse()
					for kind: String in order:
						var prefix: int = output_tick - 1 if label == "early_event" else 0
						var simulation := Simulation.new(Fixtures.make_state("early" if label == "early_event" else label, prefix))
						simulation.state.simulation_statistics = ResourceStatistics.new()
						var journal: RefCounted = Events.new()
						journal.attach(simulation)
						var runner: RefCounted = null
						if kind == "existing":
							runner = Existing.new(simulation)
							runner.overrides = {"short_exact_seconds": 0.0}
						elif kind == "batch":
							runner = Batch.new(simulation, journal)
						var started: int = Time.get_ticks_usec()
						if kind == "exact":
							for tick: int in range(total):
								simulation.update(TimeManager.OFFLINE_MAX_GAME_STEP, true)
						elif kind == "existing":
							runner.run(float(total) * TimeManager.OFFLINE_MAX_GAME_STEP)
							if runner.counters.get("strict_failure", "") != "":
								failures.append("Existing simulator strict failure")
						else:
							for offset: int in range(0, total, interval):
								if not runner.advance(mini(interval, total - offset)):
									failures.append("Candidate lifecycle/restoration failed")
						var wall_usec: int = Time.get_ticks_usec() - started
						contexts[kind] = {"simulation": simulation, "journal": journal}
						rows.append({"label": label, "interval_ticks": interval, "total_ticks": total, "repeat": repeat, "warmup": repeat == 0, "kind": kind, "wall_usec": wall_usec, "counters": runner.counters.duplicate(true) if runner != null else {}})
					var oracle: RefCounted = Oracle.new()
					var exact: Dictionary = contexts["exact"]
					for kind: String in ["existing", "batch"]:
						var candidate: Dictionary = contexts[kind]
						var full: bool = oracle.fingerprint(exact["simulation"], exact["journal"]) == oracle.fingerprint(candidate["simulation"], candidate["journal"])
						var numeric: Dictionary = Metrics.compare(Metrics.numeric(exact["simulation"].state), Metrics.numeric(candidate["simulation"].state), 1e-8, 1e-4)
						var discrete: bool = Metrics.discrete(exact["simulation"].state) == Metrics.discrete(candidate["simulation"].state)
						var rng: bool = exact["simulation"].state.gameplay_rng.state == candidate["simulation"].state.gameplay_rng.state
						if kind == "batch" and (not full or not discrete or not rng or float(numeric["normalized"]) > 1.0):
							failures.append("Benchmark parity failure: " + label + "/" + kind)
						var matched: bool = true
						if kind == "existing":
							# The pre-existing runner clips its final tick to duration
							# minus accumulated elapsed, instead of constant STEP.
							# Preserve that baseline and validate it against its actual
							# authoritative schedule. Keep nominal-grid errors visible.
							var scheduled := Simulation.new(Fixtures.make_state("early" if label == "early_event" else label, output_tick - 1 if label == "early_event" else 0))
							scheduled.state.simulation_statistics = ResourceStatistics.new()
							var scheduled_journal: RefCounted = Events.new()
							scheduled_journal.attach(scheduled)
							scheduled.prepare_offline()
							var elapsed: float = 0.0
							var duration: float = float(total) * TimeManager.OFFLINE_MAX_GAME_STEP
							for tick: int in range(total):
								var delta: float = minf(TimeManager.OFFLINE_MAX_GAME_STEP, duration - elapsed)
								elapsed = minf(duration, elapsed + delta)
								scheduled.state.set_lava_mite_dormancy_penalty(0.0)
								scheduled.update(delta, true)
							matched = oracle.fingerprint(scheduled, scheduled_journal) == oracle.fingerprint(candidate["simulation"], candidate["journal"])
							if not matched:
								failures.append("Existing schedule-matched binary parity failed")
						for row: Dictionary in rows:
							if row["label"] == label and row["interval_ticks"] == interval and row["total_ticks"] == total and row["repeat"] == repeat and row["kind"] == kind:
								row.merge({"schedule_matched_full_parity": matched, "full_binary_parity": full, "discrete_parity": discrete, "rng_parity": rng, "numeric_error": numeric})
					if not oracle.failures.is_empty():
						failures.append_array(oracle.failures)
	var result: Dictionary = {"base_commit": "e6657d0c4296b3550eb2c6207984ec258866a130", "engine": Engine.get_version_info(), "platform": OS.get_name(), "cpu": OS.get_processor_name(), "first_matter_output_tick": output_tick, "runs": rows, "failures": failures}
	var output := FileAccess.open("res://tests/experimental/ordered_flow_benchmark_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t") + "\n")
	output.close()
	for failure: String in failures:
		push_error(failure)
	print("ORDERED_FLOW_BENCHMARK failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)
