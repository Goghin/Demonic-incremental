extends SceneTree

const Tests = preload("res://tests/experimental/cycle_kernel_tests.gd")
const Fixtures = preload("res://tests/experimental/consumer_fixtures.gd")
const Kernel = preload("res://tests/experimental/exact_flow_kernel.gd")
const Packet = preload("res://tests/experimental/exact_flow_packet.gd")
const Previous = preload("res://tests/experimental/baselines/exact_flow_b29c599_kernel.gd")
const PreviousPacket = preload("res://tests/experimental/baselines/exact_flow_b29c599_packet.gd")
const Adaptive = preload("res://tests/experimental/core_investigation_runner.gd")
const Oracle = preload("res://tests/experimental/transaction_tests.gd")
const NativeProbe = preload("res://tests/experimental/cycle_native_probe.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const View = preload("res://tests/experimental/exact_flow_view.gd")
const Metrics = preload("res://tests/experimental/adaptive_metrics.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rows: Array[Dictionary] = []
	var observations: Array[Dictionary] = []
	var scenarios: Array[Array] = [["early", 2000], ["early", 36000], ["consumer_50000", 2000], ["consumer_50000", 10000], ["mid", 2000], ["mid", 10000], ["forge_competing", 2000], ["forge_competing", 10000], ["real_completion", 2000], ["reached_manual_active", 2000], ["reached_manual_near", 2000], ["reached_repeated", 10000], ["active", 2000], ["auto", 2000], ["ash_heavy", 2000], ["completion_heavy", 2000]]
	if OS.get_environment("CYCLE_BENCH_QUICK") == "1":
		scenarios = [["early", 2000], ["forge_competing", 2000], ["completion_heavy", 2000]]
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
							if kind == "isolated" and packet.configuration_changed:
								packet = null
								if tick + 1 < ticks:
									var rebuild_started: int = Time.get_ticks_usec()
									packet = Packet.new()
									if not packet.build(simulation, context["journal"]):
										packet = null
									omitted_build_usec += Time.get_ticks_usec() - rebuild_started
									rebuilds += 1
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
		var native: Dictionary = Tests.context(label)
		native["simulation"] = NativeProbe.new(native["simulation"].state)
		native["journal"] = Events.new()
		native["journal"].attach(native["simulation"])
		var initial_rng: int = native["simulation"].state.gameplay_rng.state
		for tick: int in range(ticks):
			native["simulation"].update(STEP, true)
		if View.capture(native["simulation"], native["journal"], true) != View.capture(measured["simulation"], measured["journal"], true):
			failures.append("Instrumentation/final diagnostic parity: " + label)
		observations[-1]["cycle_activity"] = native["simulation"].metrics.duplicate(true)
		observations[-1]["rng_words"] = _rng_words(native["simulation"].state.gameplay_rng, initial_rng, ticks * 8)
		var critical: int = 0
		var normal: int = 0
		for event: Dictionary in native["journal"].events:
			critical += 1 if event["event"] == "critical" else 0
			normal += 1 if event["event"] == "normal" else 0
		observations[-1]["critical_completions"] = critical
		observations[-1]["normal_completions"] = normal
		var profiled: Dictionary = Tests.context(label)
		profiled["simulation"].profiling_enabled = true
		for tick: int in range(ticks):
			profiled["simulation"].update(STEP, true)
		if View.capture(profiled["simulation"], profiled["journal"], true) != View.capture(measured["simulation"], measured["journal"], true):
			failures.append("Native profiler changed gameplay: " + label)
		observations[-1]["native_profile"] = profiled["simulation"].get_profile_report()
		print("CYCLE_BENCH_SCENARIO ", label, " ", ticks)
	var output := FileAccess.open("res://tests/experimental/cycle_kernel_benchmark_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine": Engine.get_version_info(), "cpu": OS.get_processor_name(), "runs": rows, "observations": observations, "failures": failures}, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("CYCLE_KERNEL_BENCHMARK failures=" + str(failures.size()))
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
	return {"automation_is_supported": true, "enabled_automation": enabled, "cycle_contract_supported": true, "active_or_auto_cycles": cycles, "essence_modifiers": essence, "relic_inventory_entries": state.relic_manager.inventory.size()}


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
