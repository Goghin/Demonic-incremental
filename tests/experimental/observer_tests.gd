extends RefCounted

const Fixtures = preload("res://tests/experimental/observer_fixtures.gd")
const Kernel = preload("res://tests/experimental/exact_flow_kernel.gd")
const Packet = preload("res://tests/experimental/exact_flow_packet.gd")
const View = preload("res://tests/experimental/exact_flow_view.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var failures: Array[String] = []
var cases: Array[Dictionary] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run_all() -> Dictionary:
	for label: String in ["early", "consumer_50000", "mid", "forge_competing", "earned_craft_first_craft", "earned_craft_repeat_craft", "reached_multiple"]:
		for workload: String in ["none", "journal", "readonly", "heavy", "observe", "mixed"]:
			_differential(label, workload, 100)
	for workload: String in ["resource", "upgrade", "automation", "inventory", "register", "remove", "replace"]:
		# Deliberate completion-edge fixture supplements earned progression above.
		_differential("forge_together", workload, 60)
	_differential("earned_craft_first_craft", "readonly", 1000)
	_differential("earned_craft_repeat_craft", "readonly", 2000)
	_differential("consumer_50000", "readonly", 1000)
	_boundaries()
	_flags()
	return {"failures": failures, "cases": cases}

func deferred_case(tree: SceneTree) -> void:
	var native: Dictionary = Fixtures.context("forge_together", "journal")
	var fast: Dictionary = Fixtures.context("forge_together", "journal")
	var left: RefCounted = Fixtures.Sink.new()
	var right: RefCounted = Fixtures.Sink.new()
	native["simulation"].crystallization_completed.connect(left.crystallization_completed, CONNECT_DEFERRED)
	native["simulation"].critical_crystallization_completed.connect(left.critical_crystallization_completed, CONNECT_DEFERRED)
	fast["simulation"].crystallization_completed.connect(right.crystallization_completed, CONNECT_DEFERRED)
	fast["simulation"].critical_crystallization_completed.connect(right.critical_crystallization_completed, CONNECT_DEFERRED)
	var runner: RefCounted = Kernel.new(fast["simulation"], fast["journal"])
	runner.run(1)
	native["simulation"].update(STEP, true)
	check(runner.counters["kernel_ticks"] == 0, "Deferred receiver admitted")
	await tree.process_frame
	check(left.normal + left.critical > 0, "Deferred completion witness absent")
	check(left.snapshot() == right.snapshot(), "Deferred callback parity")
	check(View.capture(native["simulation"], native["journal"], true) == View.capture(fast["simulation"], fast["journal"], true), "Deferred state parity")

func adapter_callback_case() -> void:
	var adapter: Script = preload("res://tests/experimental/offline_kernel_time_manager.gd")
	var legacy: Script = preload("res://tests/experimental/baselines/offline_time_manager_4aa3073.gd")
	var results: Dictionary = {}
	var diagnostics: Dictionary = {}
	for kind: String in ["native", "legacy", "corrected"]:
		var item: Dictionary = Fixtures.context("early", "journal")
		var tm: RefCounted = legacy.new(item["simulation"], item["journal"], true) if kind == "legacy" else adapter.new(item["simulation"], item["journal"], kind == "corrected")
		tm.last_real_timestamp = tm.fixed_now - 1.2
		tm.offline_work_budget_ms = 0.0
		tm.on_tick = _purchase_after_step
		await tm.process_offline_time()
		results[kind] = View.capture(item["simulation"], item["journal"], true)
		diagnostics[kind] = {"counters": tm.counters.duplicate(true), "game_time": tm.game_time, "steps": tm.offline_steps_processed}
	check(results["native"] == results["corrected"], "on_tick mutation retained stale packet")
	check(results["native"] != results["legacy"], "Legacy stale-packet witness did not diverge")
	check(diagnostics["corrected"]["counters"].get("observer_packet_releases", 0) > 0, "on_tick packet releases not recorded")
	check(diagnostics["corrected"]["counters"]["observer_callback_boundaries"] == diagnostics["corrected"]["steps"], "on_tick callback count changed")
	check(diagnostics["native"]["game_time"] == diagnostics["corrected"]["game_time"], "on_tick clock drift")
	var file: FileAccess = FileAccess.open("res://tests/experimental/observer_callback_boundary_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"native_corrected_exact": results["native"] == results["corrected"], "legacy_diverged": results["native"] != results["legacy"], "diagnostics": diagnostics}, "\t"))
	file.close()

func _purchase_after_step(tm: TimeManager) -> void:
	if tm.game_time < STEP * 1.5:
		var generator: Generator = tm.simulation.state.get_generator("atomic_friction")
		tm.simulation.state.set_resource_amount(generator.definition.cost_resource_id, generator.get_cost(tm.simulation.state))
		check(tm.simulation.buy_generator(generator.definition.id, "observer_boundary"), "Boundary purchase did not succeed")

func _differential(label: String, workload: String, ticks: int) -> void:
	var native: Dictionary = Fixtures.context(label, workload)
	var fast: Dictionary = Fixtures.context(label, workload)
	var runner: RefCounted = Kernel.new(fast["simulation"], fast["journal"])
	runner.detailed_trace = true
	check(runner.run(ticks, true), "Run refused")
	for tick: int in range(ticks):
		native["simulation"].update(STEP, true)
		check(View.capture(native["simulation"], native["journal"], true) == runner.trace[tick], "%s/%s tick %d" % [label, workload, tick])
	check(Fixtures.observable(native) == Fixtures.observable(fast), label + "/" + workload + " callback state/order")
	if workload in ["none", "journal", "readonly", "heavy"]:
		check(runner.counters["kernel_ticks"] > 0, label + "/" + workload + " no admission")
	else:
		check(runner.counters["kernel_ticks"] == 0, workload + " external callback admitted")
	if label == "forge_together":
		check(fast["receivers"][-1].acted, workload + " mutation witness not invoked")
		if workload in ["remove", "replace"]:
			check(runner.run(10), "Recovery run failed")
			for tick: int in range(10):
				native["simulation"].update(STEP, true)
			check(runner.counters["kernel_ticks"] > 0, workload + " failed recovery at public boundary")
			check(View.capture(native["simulation"], native["journal"], true) == View.capture(fast["simulation"], fast["journal"], true), workload + " recovery parity")
	cases.append({"label": label, "workload": workload, "ticks": ticks, "counters": runner.counters.duplicate(true)})
	Fixtures.release(native)
	Fixtures.release(fast)

func _boundaries() -> void:
	var item: Dictionary = Fixtures.context("early", "readonly")
	var runner: RefCounted = Kernel.new(item["simulation"], item["journal"])
	runner.run(10)
	var callback: RefCounted = Fixtures.External.new()
	callback.attach(item["simulation"])
	var before: int = runner.counters["kernel_ticks"]
	runner.run(10)
	check(runner.counters["kernel_ticks"] == before, "New registration reused stale admission")
	callback.detach()
	callback.simulation = null
	runner.run(10)
	check(runner.counters["kernel_ticks"] > before, "Removal failed to refresh admission")
	# Save/load creates a fresh state with a fresh callback graph and fresh packet.
	var data: Dictionary = SaveManager.new().state_to_dictionary(item["simulation"].state)
	var restored: GameState = Fixtures.Crafting.Fixtures.Core.from_save(data)
	var simulation := Simulation.new(restored)
	var journal: RefCounted = Fixtures.Events.new()
	journal.attach(simulation)
	check(Kernel.new(simulation, journal).run(10), "Save/load reentry refused")
	var native_restored: GameState = Fixtures.Crafting.Fixtures.Core.from_save(data)
	var native_simulation := Simulation.new(native_restored)
	var native_journal: RefCounted = Fixtures.Events.new()
	native_journal.attach(native_simulation)
	for tick: int in range(10):
		native_simulation.update(STEP, true)
	check(View.capture(simulation, journal, true) == View.capture(native_simulation, native_journal, true), "Save/load reentry parity")
	var instrumented: Dictionary = Fixtures.context("forge_together", "readonly", true)
	var measured: RefCounted = Kernel.new(instrumented["simulation"], instrumented["journal"])
	measured.observer_instrumentation = true
	measured.metered_observers.assign(instrumented["receivers"])
	measured.run(20)
	var control: Dictionary = Fixtures.context("forge_together", "readonly")
	Kernel.new(control["simulation"], control["journal"]).run(20)
	check(View.capture(control["simulation"], control["journal"], true) == View.capture(instrumented["simulation"], instrumented["journal"], true), "Instrumentation changed state")
	check(Fixtures.observable(control) == Fixtures.observable(instrumented), "Instrumentation changed callbacks")
	var calls: int = 0
	for receiver: RefCounted in instrumented["receivers"]:
		calls += receiver.unlocks + receiver.normal + receiver.critical + receiver.relics + receiver.downlevels if receiver.get_script() == Fixtures.Sink else receiver.events.size()
	check(calls == measured.observer_metrics["observer_invocations"], "Invocation metric differs from actual callbacks")
	check(measured.observer_metrics["observer_invocations"] > 0, "Invocation metrics missing")
	check(measured.observer_metrics["observer_checks"] >= 15, "Admission checks missing")
	check(measured.observer_metrics["observer_triggered_invalidations"] == 0, "Read-only observer invalidated packet")

func _flags() -> void:
	# An extra mutable journal could alias an inventory/configuration Array.
	# Its script name alone is not an ownership proof. Only the caller-supplied
	# owned journal keeps the existing contract; extra receivers are scalar-only.
	var aliased: Dictionary = Fixtures.context("early", "journal")
	var extra: RefCounted = Fixtures.Events.new()
	extra.events = aliased["simulation"].state.relic_manager.inventory
	extra.attach(aliased["simulation"])
	var alias_packet: RefCounted = Packet.new()
	check(not alias_packet.build(aliased["simulation"], aliased["journal"]), "Extra journal with aliased gameplay storage admitted")
	for flags: int in [CONNECT_DEFERRED, CONNECT_ONE_SHOT, CONNECT_REFERENCE_COUNTED]:
		var item: Dictionary = Fixtures.context("early", "none")
		var sink: RefCounted = Fixtures.Events.new()
		item["simulation"].crystallization_completed.connect(sink.crystallization_completed, flags)
		var packet: RefCounted = Packet.new()
		check(not packet.build(item["simulation"]) and packet.error == "external_observer", "Nonplain connection admitted")
	var item: Dictionary = Fixtures.context("early", "none")
	var sink: RefCounted = Fixtures.Events.new()
	item["simulation"].crystallization_completed.connect(sink.crystallization_completed.bind(1.0).unbind(1))
	var packet: RefCounted = Packet.new()
	check(not packet.build(item["simulation"]) and packet.error == "external_observer", "Bound/unbound callback admitted")
