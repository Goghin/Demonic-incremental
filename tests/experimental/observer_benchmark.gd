extends SceneTree

const Fixtures = preload("res://tests/experimental/observer_fixtures.gd")
const Kernel = preload("res://tests/experimental/exact_flow_kernel.gd")
const Previous = preload("res://tests/experimental/baselines/exact_flow_4aa3073_kernel.gd")
const Historical = preload("res://tests/experimental/baselines/exact_flow_182e562_kernel.gd")
const View = preload("res://tests/experimental/exact_flow_view.gd")
const Adapter = preload("res://tests/experimental/offline_kernel_time_manager.gd")
const NativeClock = preload("res://tests/experimental/offline_native_time_manager.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var failures: Array[String] = []
var rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("OBSERVER_BENCH_OFFLINE_CONFIRM") == "1":
		var retained: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/observer_benchmark_results.json"))
		assert(retained["failures"].is_empty() and retained["engine"]["hash"] == Engine.get_version_info()["hash"] and retained["cpu"] == OS.get_processor_name())
		rows.assign(retained["runs"])
		await _offline(true)
		_export()
		quit(0 if failures.is_empty() else 1)
		return
	var matrix: Array[Array] = []
	for label: String in ["early", "consumer_50000", "mid", "forge_competing", "earned_craft_first_craft", "earned_craft_repeat_craft", "reached_multiple", "earned_feedback"]:
		for workload: String in ["journal", "readonly"]:
			matrix.append([label, workload, 2000])
	matrix.append_array([["early", "none", 2000], ["early", "journal", 36000], ["early", "none", 36000], ["forge_together", "heavy", 2000]])
	for workload: String in ["observe", "resource", "upgrade", "automation", "inventory", "register", "remove", "replace", "mixed"]:
		matrix.append(["forge_together", workload, 1000])
	if OS.get_environment("OBSERVER_BENCH_QUICK") == "1":
		matrix = [["early", "journal", 2000], ["forge_together", "readonly", 1000], ["forge_together", "mixed", 100]]
	for scenario: Array in matrix:
		for repeat: int in range(6):
			var methods: Array[String] = ["native", "previous", "optimized", "instrumented"]
			if scenario[0] == "early" and scenario[1] in ["none", "journal"]:
				methods.append("historical")
			if repeat % 2 == 1:
				methods.reverse()
			var contexts: Dictionary = {}
			var run_rows: Array[Dictionary] = []
			for kind: String in methods:
				var instrument: bool = kind == "instrumented"
				var item: Dictionary = Fixtures.context(scenario[0], scenario[1], instrument)
				contexts[kind] = item
				var runner: RefCounted = null
				if kind != "native":
					if kind == "historical":
						runner = Historical.new(item["simulation"], item["journal"])
					else:
						runner = Previous.new(item["simulation"], item["journal"]) if kind == "previous" else Kernel.new(item["simulation"], item["journal"])
				if instrument:
					runner.observer_instrumentation = true
					runner.metered_observers.assign(item["receivers"])
				var started: int = Time.get_ticks_usec()
				if kind == "native":
					for tick: int in range(scenario[2]):
						item["simulation"].update(STEP, true)
				else:
					runner.run(scenario[2])
				var elapsed: int = Time.get_ticks_usec() - started
				run_rows.append({"label": scenario[0], "workload": scenario[1], "ticks": scenario[2], "repeat": repeat, "warmup": repeat == 0, "kind": kind, "wall_usec": elapsed, "counters": runner.counters.duplicate(true) if runner != null else {}, "observer_metrics": runner.observer_metrics.duplicate(true) if instrument else {}})
			var expected: PackedByteArray = View.capture(contexts["native"]["simulation"], contexts["native"]["journal"], true)
			var expected_events: PackedByteArray = Fixtures.observable(contexts["native"])
			for row: Dictionary in run_rows:
				var item: Dictionary = contexts[row["kind"]]
				row["exact_parity"] = expected == View.capture(item["simulation"], item["journal"], true) and expected_events == Fixtures.observable(item)
				if not row["exact_parity"]:
					failures.append(str(scenario) + "/" + row["kind"])
				if row["kind"] == "instrumented" and row["observer_metrics"]["observer_invocations"] != Fixtures.invocations(item):
					failures.append("Invocation metric mismatch: " + str(scenario))
				rows.append(row)
				Fixtures.release(item)
		print("Observer bench complete: ", scenario)
		_export()
	if OS.get_environment("OBSERVER_BENCH_QUICK") != "1":
		await _offline()
		_logger()
	_export()
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _clock(tm: TimeManager) -> PackedByteArray:
	return var_to_bytes([tm.session_time, tm.active_time, tm.offline_time, tm.game_time, tm.prestige_time, tm.last_real_timestamp, tm.current_offline_duration, tm.dormancy_recovery_remaining, tm.offline_simulation_active, tm.simulation_tick, tm.simulation_total_ticks, tm.simulation_statistics.to_dictionary()])

func _offline(matched_dispatch: bool = false) -> void:
	# Existing experimental subclass retains the authoritative coordinator and
	# its yields, dormancy, partial steps and finalization; production is untouched.
	var repeats: Array[int] = [0, 1, 2, 3]
	var completed: Dictionary = {}
	if matched_dispatch:
		for row: Dictionary in rows:
			if row["label"] == "offline_matched_dispatch" and int(row["repeat"]) >= 0:
				var index: int = int(row["repeat"])
				completed[index] = int(completed.get(index, 0)) + 1
		if not completed.is_empty():
			# Interrupted confirmations resume whole completed pairs only. Retain
			# a new-process warmup; do not replace or select earlier measurements.
			repeats.push_front(-1)
	for repeat: int in repeats:
		if int(completed.get(repeat, 0)) == 3:
			continue
		var expected: Array = []
		var methods: Array[String] = ["native", "previous", "optimized"]
		if repeat % 2 == 1:
			methods.reverse()
		var items: Dictionary = {}
		var run_rows: Array[Dictionary] = []
		for kind: String in methods:
			var item: Dictionary = Fixtures.context("earned_craft_repeat_craft", "readonly")
			var tm: RefCounted = NativeClock.new(item["simulation"], item["journal"]) if kind == "native" and not matched_dispatch else Adapter.new(item["simulation"], item["journal"], kind != "native")
			if kind == "previous":
				tm.packet_script = preload("res://tests/experimental/baselines/exact_flow_4aa3073_packet.gd")
			tm.last_real_timestamp = tm.fixed_now - 3600.0
			tm.offline_work_budget_ms = 0.0
			var started: int = Time.get_ticks_usec()
			await tm.process_offline_time()
			var elapsed: int = Time.get_ticks_usec() - started
			items[kind] = [item, tm]
			run_rows.append({"label": "offline_matched_dispatch" if matched_dispatch else "offline_one_hour", "workload": "readonly", "kind": kind, "repeat": repeat, "warmup": repeat <= 0, "ticks": tm.offline_steps_processed, "wall_usec": elapsed, "counters": tm.counters.duplicate(true), "observer_metrics": {}})
		var reference: Dictionary = items["native"][0]
		expected = [View.capture(reference["simulation"], reference["journal"], true), Fixtures.observable(reference), _clock(items["native"][1])]
		for row: Dictionary in run_rows:
			var item: Dictionary = items[row["kind"]][0]
			row["exact_parity"] = expected == [View.capture(item["simulation"], item["journal"], true), Fixtures.observable(item), _clock(items[row["kind"]][1])]
			if not row["exact_parity"]:
				failures.append("Offline mismatch: " + row["kind"])
			rows.append(row)
			Fixtures.release(item)
		print("Offline observer benchmark repeat ", repeat)
		_export()

func _logger() -> void:
	# Disabled production logging is a separate admission control, not a claim
	# that observer compatibility makes the production client eligible.
	var item: Dictionary = Fixtures.context("early", "readonly")
	var logger := GameplayLog.new()
	logger.enabled = false
	item["simulation"].state.gameplay_log = logger
	var runner: RefCounted = Kernel.new(item["simulation"], item["journal"])
	runner.observer_instrumentation = true
	runner.run(100)
	var native: Dictionary = Fixtures.context("early", "readonly")
	var native_logger := GameplayLog.new()
	native_logger.enabled = false
	native["simulation"].state.gameplay_log = native_logger
	for tick: int in range(100):
		native["simulation"].update(STEP, true)
	var parity: bool = View.capture(native["simulation"], native["journal"], true) == View.capture(item["simulation"], item["journal"], true)
	if not parity:
		failures.append("Disabled logger mismatch")
	rows.append({"label": "disabled_production_logger", "workload": "readonly", "kind": "instrumented", "ticks": 100, "repeat": 0, "warmup": false, "wall_usec": 0, "exact_parity": parity, "counters": runner.counters, "observer_metrics": runner.observer_metrics})
	assert(logger.events.is_empty())

func _export() -> void:
	var output := FileAccess.open("res://tests/experimental/observer_benchmark_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine": Engine.get_version_info(), "cpu": OS.get_processor_name(), "platform": OS.get_name(), "processor_count": OS.get_processor_count(), "debug_build": OS.is_debug_build(), "baseline_commit": "4aa3073602e150714baff4d312cc0e23d85b72d4", "native_step": STEP, "repetitions": "one warmup + five measured, offline one + three", "logging": "in-memory TickLog without external clock; production logger only disabled diagnostic", "runs": rows, "failures": failures}, "\t"))
	output.close()
