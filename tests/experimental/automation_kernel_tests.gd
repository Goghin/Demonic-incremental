extends RefCounted

const Fixtures = preload("res://tests/experimental/automation_kernel_fixtures.gd")
const Kernel = preload("res://tests/experimental/exact_flow_kernel.gd")
const Packet = preload("res://tests/experimental/exact_flow_packet.gd")
const View = preload("res://tests/experimental/exact_flow_view.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const Oracle = preload("res://tests/experimental/transaction_tests.gd")
const Activity = preload("res://tests/experimental/automation_kernel_activity.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var failures: Array[String] = []
var cases: Array[Dictionary] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


static func context(label: String) -> Dictionary:
	var simulation := Simulation.new(Fixtures.make_state(label))
	simulation.state.simulation_statistics = ResourceStatistics.new()
	var journal: RefCounted = Events.new()
	journal.attach(simulation)
	return {"simulation": simulation, "journal": journal}


func run_all() -> Dictionary:
	for label: String in ["mid", "reached_entry", "reached_settled"]:
		_differential(label, 2000)
	_differential("mid", 10000)
	_differential("reached_settled", 10000)
	_differential("forge_competing", 2000)
	for label: String in Fixtures.DIAGNOSTICS:
		_differential(label, 1200 if label in ["initial", "effects", "registry"] else 120)
	_wait_and_reentry()
	_invalidated_packet()
	_activity_parity()
	return {"failures": failures, "cases": cases}


func _differential(label: String, ticks: int) -> void:
	var candidate: Dictionary = context(label)
	var control: Dictionary = context(label)
	var oracle: RefCounted = Oracle.new()
	var before: PackedByteArray = oracle.fingerprint(candidate["simulation"], candidate["journal"])
	var packet: RefCounted = Packet.new()
	packet.build(candidate["simulation"], candidate["journal"])
	check(before == oracle.fingerprint(candidate["simulation"], candidate["journal"]), label + ": construction mutated state")
	packet = null
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	kernel.detailed_trace = true
	check(kernel.run(ticks, true), label + ": failed run")
	var history: Array[Dictionary] = []
	var compared: int = 0
	var old_production: float = 0.0
	if label == "production":
		var generator: Generator = control["simulation"].state.get_generator("atomic_friction")
		old_production = generator.get_production_rate(generator.get_active_outputs()[0], control["simulation"].state) * STEP
	for tick: int in range(ticks):
		var state: GameState = control["simulation"].state
		var mark: int = state.gameplay_log.events.size()
		control["simulation"].update(STEP, true)
		for index: int in range(mark, state.gameplay_log.events.size()):
			history.append({"tick": tick + 1, "event": state.gameplay_log.events[index]})
		if View.capture(control["simulation"], control["journal"], true) != kernel.trace[tick]:
			check(false, label + ": first tick mismatch " + str(tick + 1))
			break
		if tick == 0:
			if label == "production":
				check(state.get_generator("atomic_friction").level == 2 and state.simulation_statistics.get_total_produced(ResourceIds.HEAT) == old_production, "Newly purchased level affected same-tick output")
			if label == "decay":
				check(state.get_generator("atomic_friction").level == 2 and state.simulation_statistics.total_matter_decayed > 0.0, "Decay-funded purchase missing")
		compared += 1
	check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), label + ": complete graph differs")
	check(oracle.failures.is_empty(), label + ": oracle failed")
	var purchases: Array[Dictionary] = []
	for event: Dictionary in history:
		if event["event"]["category"] == "purchase":
			purchases.append(event)
	if label == "forge_competing":
		check(kernel.counters["kernel_ticks"] > 0 and kernel.counters["reasons"].is_empty(), "Forge did not use the native-cycle contract")
	elif label == "unsupported":
		check(kernel.counters["kernel_ticks"] == ticks and kernel.counters["structural_invalidations"] == 1, "Newly supported Essence unlock did not reconstruct on NEXT tick")
	else:
		check(kernel.counters["kernel_ticks"] > 0, label + ": no actual kernel ticks")
	if label in ["reached_entry", "effects", "automatic", "activation", "initial", "production", "decay", "competition", "registry", "cost_refresh", "general", "purchase_heavy", "upgrade_initial"]:
		check(not purchases.is_empty(), label + ": no native purchase exercised")
	if label in ["mid", "reached_settled"]:
		check(purchases.is_empty() and kernel.counters["structural_invalidations"] == 0, label + ": natural waiting caused structural churn")
	if label == "waiting":
		check(purchases.is_empty() and kernel.counters["builds"] == 1 and kernel.counters["structural_invalidations"] == 0, "Failed waiting checks rebuilt packet")
	if label in ["initial", "upgrade_initial"] and not purchases.is_empty():
		check(int(purchases[0]["tick"]) >= (100 if label == "upgrade_initial" else 50), "Initial cooldown bypassed")
	if label == "competition" and not purchases.is_empty():
		check(purchases[0]["event"]["source"] == "autobuyer" and purchases[0]["event"]["details"]["generator_id"] == "atomic_friction", "Generator/registry purchase order changed")
	if label == "registry" and not purchases.is_empty():
		check(purchases[0]["event"]["details"]["upgrade_id"] == "af_first", "Tree order replaced by upgrade registry order")
	if label == "cost_refresh":
		check(purchases.size() >= 2 and purchases[0]["event"]["source"] == "upgrade_autobuyer" and int(purchases[0]["tick"]) == 1 and purchases[1]["event"]["source"] == "autobuyer" and int(purchases[1]["tick"]) == 2, "Waiting cost invalidation/retry order changed")
	if label == "general":
		check(candidate["simulation"].state.get_upgrade("general_paid").level == 1 and candidate["simulation"].state.get_upgrade("excluded_strip").level == 0, "General tree filtering changed")
	if label == "automatic":
		var found: bool = false
		for event: Dictionary in history:
			if event["event"]["event"] == "automatic_upgrade_applied":
				found = int(event["tick"]) == 2
		check(found and kernel.counters["event_ticks"] > 0, "New level did not activate automatic effects at next header")
	if label == "activation":
		check(kernel.counters["structural_invalidations"] > 0 and candidate["simulation"].state.get_generator("atomic_friction").level == 1, "Log witness missed a success without a level increment")
	cases.append({"label": label, "ticks": ticks, "compared_ticks": compared, "counters": kernel.counters.duplicate(true), "purchases": purchases})


func _wait_and_reentry() -> void:
	var candidate: Dictionary = context("waiting")
	var control: Dictionary = context("waiting")
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	kernel.detailed_trace = true
	kernel.run(20)
	for tick: int in range(20):
		control["simulation"].update(STEP, true)
	check(kernel.counters["builds"] == 1 and kernel.counters["structural_invalidations"] == 0, "Waiting interval rebuilt")
	for boundary: String in ["fund", "disable", "enable", "upgrade_wait", "preference", "fallback", "resume"]:
		for item: Dictionary in [candidate, control]:
			var state: GameState = item["simulation"].state
			match boundary:
				"fund": state.set_resource_amount(ResourceIds.HEAT, state.get_generator("atomic_friction").get_cost(state))
				"disable": state.generator_automation_manager.set_enabled("atomic_friction", false)
				"enable": state.generator_automation_manager.set_enabled("atomic_friction", true)
				"upgrade_wait":
					Fixtures.add_upgrade(state, "external_choice", "atomic_friction", 1.0)
					Fixtures.Buyers.enable(state, "atomic_friction", true)
					state.upgrade_automation_manager.automation_states["atomic_friction"]["remaining_cooldown"] = 0.0
				"preference":
					state.get_upgrade("external_choice").definition.exclusivity_group = "choice"
					state.upgrade_automation_manager.set_exclusive_preference("external_choice", true)
					state.set_resource_amount(ResourceIds.HEAT, 2.0)
				"fallback":
					state.prestige_planning = true
					state.get_generator("atomic_friction").manually_paused = false
				"resume": state.prestige_planning = false
		kernel.run(5, true)
		for tick: int in range(5):
			control["simulation"].update(STEP, true)
			check(View.capture(control["simulation"], control["journal"], true) == kernel.trace[tick], "External reentry differs: " + boundary)
	check(kernel.counters["fallback_ticks"] == 5, "Fallback/resumption did not use expected exact ticks")
	cases.append({"reentry": true, "counters": kernel.counters.duplicate(true)})


func _invalidated_packet() -> void:
	var item: Dictionary = context("production")
	var packet: RefCounted = Packet.new()
	check(packet.build(item["simulation"], item["journal"]) and not packet.event_due(), "Direct packet not eligible")
	packet.step()
	check(packet.configuration_changed and packet.event_due(), "Internal invalidation not visible to packet callers")


func _activity_parity() -> void:
	for label: String in ["waiting", "effects", "cost_refresh", "registry", "purchase_heavy", "mid", "reached_entry"]:
		var measured: Dictionary = context(label)
		var control: Dictionary = context(label)
		Activity.install(measured["simulation"].state)
		for tick: int in range(120):
			measured["simulation"].update(STEP, true)
			control["simulation"].update(STEP, true)
			check(View.capture(measured["simulation"], measured["journal"], true) == View.capture(control["simulation"], control["journal"], true), "Native telemetry changed gameplay: " + label)
		var packet: RefCounted = Packet.new()
		check(not packet.build(measured["simulation"], measured["journal"]) and packet.error == "unknown_runtime_dependency", "Diagnostic manager admitted to optimized path")
		cases.append({"activity_parity": label, "ticks": 120, "generator": measured["simulation"].state.generator_automation_manager.get("metrics"), "upgrade": measured["simulation"].state.upgrade_automation_manager.get("metrics")})
