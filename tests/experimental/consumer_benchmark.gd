extends SceneTree

const Tests = preload("res://tests/experimental/consumer_tests.gd")
const Fixtures = preload("res://tests/experimental/consumer_fixtures.gd")
const Kernel = preload("res://tests/experimental/exact_flow_kernel.gd")
const Packet = preload("res://tests/experimental/exact_flow_packet.gd")
const Previous = preload("res://tests/experimental/baselines/exact_flow_43b3897_kernel.gd")
const PreviousPacket = preload("res://tests/experimental/baselines/exact_flow_43b3897_packet.gd")
const Adaptive = preload("res://tests/experimental/core_investigation_runner.gd")
const Oracle = preload("res://tests/experimental/transaction_tests.gd")
const Metrics = preload("res://tests/experimental/adaptive_metrics.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rows: Array[Dictionary] = []
	var observations: Array[Dictionary] = []
	var scenarios: Array[Array] = [["early", 2000], ["early", 36000], ["mid", 2000], ["forge_competing", 2000], ["consumer_9500", 2000], ["consumer_20000", 2000], ["consumer_50000", 2000], ["consumer_50000", 10000], ["mite_entry", 2000], ["mite_recovery", 2000], ["multi_dynamic", 2000], ["multi_partial", 2000]]
	if OS.get_environment("CONSUMER_BENCH_QUICK") == "1":
		scenarios = [["early", 2000], ["consumer_20000", 2000], ["consumer_50000", 2000]]
	for scenario: Array in scenarios:
		var label: String = scenario[0]
		var ticks: int = scenario[1]
		for repeat: int in range(4):
			var methods: Array[String] = ["exact", "previous", "previous_isolated", "isolated", "extended", "adaptive"]
			if repeat % 2 == 1:
				methods.reverse()
			var contexts: Dictionary = {}
			var results: Array[Dictionary] = []
			for kind: String in methods:
				var context: Dictionary = Tests.context(label)
				contexts[kind] = context
				var simulation: Simulation = context["simulation"]
				var runner: RefCounted = null
				var packet: RefCounted = null
				var isolated: bool = kind in ["isolated", "previous_isolated"]
				var build_usec: int = 0
				var packet_bytes: int = 0
				var kernel_ticks: int = 0
				var fallback_ticks: int = 0
				var rebuilds: int = 0
				if isolated:
					var before: int = OS.get_static_memory_usage()
					var started: int = Time.get_ticks_usec()
					packet = Packet.new() if kind == "isolated" else PreviousPacket.new()
					if not packet.build(simulation, context["journal"]):
						packet = null
					build_usec = Time.get_ticks_usec() - started
					packet_bytes = OS.get_static_memory_usage() - before
				elif kind == "extended":
					runner = Kernel.new(simulation, context["journal"])
				elif kind == "previous":
					runner = Previous.new(simulation, context["journal"])
				elif kind == "adaptive":
					runner = Adaptive.new(simulation)
					runner.overrides = {"short_exact_seconds": 0.0}
				var omitted_build_usec: int = 0
				var started: int = Time.get_ticks_usec()
				if isolated:
					for tick: int in range(ticks):
						if packet != null and packet.event_due():
							packet = null
							simulation.update(STEP, true)
							fallback_ticks += 1
							var rebuild_started: int = Time.get_ticks_usec()
							packet = Packet.new() if kind == "isolated" else PreviousPacket.new()
							if not packet.build(simulation, context["journal"]):
								packet = null
							omitted_build_usec += Time.get_ticks_usec() - rebuild_started
							rebuilds += 1
						elif packet == null:
							simulation.update(STEP, true)
							fallback_ticks += 1
						else:
							packet.step()
							kernel_ticks += 1
				elif kind == "exact":
					for tick: int in range(ticks):
						simulation.update(STEP, true)
				elif kind == "adaptive":
					runner.run(float(ticks) * STEP)
					if runner.counters.get("strict_failure", "") != "":
						failures.append("Adaptive strict failure")
				else:
					runner.run(ticks)
				var wall_usec: int = Time.get_ticks_usec() - started - omitted_build_usec
				results.append({"label": label, "ticks": ticks, "kind": kind, "repeat": repeat, "warmup": repeat == 0, "wall_usec": wall_usec, "packet_build_usec": build_usec, "packet_retained_allocation_estimate_bytes": packet_bytes, "kernel_ticks": int(runner.counters.get("kernel_ticks", 0)) if runner != null else kernel_ticks, "fallback_ticks": int(runner.counters.get("fallback_ticks", 0)) if runner != null else fallback_ticks, "isolated_rebuilds": rebuilds, "counters": runner.counters.duplicate(true) if runner != null else {}})
			var oracle: RefCounted = Oracle.new()
			for result: Dictionary in results:
				var candidate: Dictionary = contexts[result["kind"]]
				result["binary_parity"] = oracle.fingerprint(contexts["exact"]["simulation"], contexts["exact"]["journal"]) == oracle.fingerprint(candidate["simulation"], candidate["journal"])
				result["numeric_error"] = Metrics.compare(Metrics.numeric(contexts["exact"]["simulation"].state), Metrics.numeric(candidate["simulation"].state), 1e-8, 1e-4)
				result["discrete_parity"] = Metrics.discrete(contexts["exact"]["simulation"].state) == Metrics.discrete(candidate["simulation"].state)
				result["rng_parity"] = contexts["exact"]["simulation"].state.gameplay_rng.state == candidate["simulation"].state.gameplay_rng.state
				if result["kind"] != "adaptive" and not result["binary_parity"]:
					failures.append("Benchmark binary mismatch: " + label + "/" + str(ticks) + "/" + result["kind"])
				rows.append(result)
			failures.append_array(oracle.failures)
		# Diagnostic clocks/counters run only AFTER throughput samples, untimed.
		var measured: Dictionary = Tests.context(label)
		var initial_blockers: Dictionary = _blockers(measured["simulation"].state)
		var diagnostic: RefCounted = Kernel.new(measured["simulation"], measured["journal"])
		diagnostic.collect_flow_counters = true
		diagnostic.measure_phases = true
		diagnostic.run(ticks)
		observations.append({"label": label, "ticks": ticks, "intrusive_untimed": true, "counters": diagnostic.counters.duplicate(true), "flows": diagnostic.flow_counts.duplicate(true), "initial_blockers": initial_blockers, "final_blockers": _blockers(measured["simulation"].state)})
		print("CONSUMER_BENCH_SCENARIO ", label, " ", ticks)
	var output := FileAccess.open("res://tests/experimental/consumer_benchmark_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine": Engine.get_version_info(), "cpu": OS.get_processor_name(), "runs": rows, "observations": observations, "failures": failures}, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("CONSUMER_BENCHMARK failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)


func _blockers(state: GameState) -> Dictionary:
	# Independent blocker inventory; the runtime guard returns its FIRST reason.
	var enabled: Array[String] = []
	for manager: Variant in [state.generator_automation_manager, state.upgrade_automation_manager]:
		for id: String in manager.automation_states:
			if bool(manager.automation_states[id]["enabled"]):
				enabled.append(id)
	var cycles: Array[String] = []
	var essence: Array[String] = []
	for generator: Generator in state.generators.values():
		if generator.cycle_active or generator.auto_run_cycles:
			cycles.append(generator.definition.id)
		for modifier: Modifier in generator.modifiers:
			if modifier.dynamic and modifier.dynamic_resource_id == ResourceIds.ESSENCE:
				essence.append(generator.definition.id)
	return {"enabled_automation": enabled, "active_or_auto_cycles": cycles, "essence_modifiers": essence, "relic_inventory_entries": state.relic_manager.inventory.size()}
