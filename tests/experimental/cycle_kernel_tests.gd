extends RefCounted

const Fixtures = preload("res://tests/experimental/cycle_kernel_fixtures.gd")
const Kernel = preload("res://tests/experimental/exact_flow_kernel.gd")
const Packet = preload("res://tests/experimental/exact_flow_packet.gd")
const View = preload("res://tests/experimental/exact_flow_view.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const Oracle = preload("res://tests/experimental/transaction_tests.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
class UnknownRng extends RandomNumberGenerator:
	var diagnostic: bool = false

var failures: Array[String] = []
var cases: Array[Dictionary] = []


static func context(label: String) -> Dictionary:
	var simulation := Simulation.new(Fixtures.make_state(label))
	simulation.state.simulation_statistics = ResourceStatistics.new()
	var journal: RefCounted = Events.new()
	journal.attach(simulation)
	return {"simulation": simulation, "journal": journal}


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func run_all() -> Dictionary:
	_differential("forge_competing", 2000)
	_differential("forge_competing", 10000)
	_differential("real_completion", 100)
	for label: String in Fixtures.DIAGNOSTICS:
		_differential(label, 200 if label == "completion_heavy" else 100)
	if not FileAccess.file_exists("res://tests/experimental/cycle_progression.json"):
		check(false, "Required reached cycle fixtures missing; run fixture builder")
	else:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/cycle_progression.json"))
		if not manifest["failures"].is_empty():
			check(false, "Required reached fixture construction failed")
		else:
			for label: String in ["reached_manual_active", "reached_manual_near", "reached_repeated"]:
				_differential(label, 2000)
	_reentry()
	_probability_edges()
	_probe_parity()
	_unsupported()
	return {"failures": failures, "cases": cases}


func _differential(label: String, ticks: int) -> void:
	var candidate: Dictionary = context(label)
	var control: Dictionary = context(label)
	var oracle: RefCounted = Oracle.new()
	var initial: PackedByteArray = oracle.fingerprint(candidate["simulation"], candidate["journal"])
	var packet: RefCounted = Packet.new()
	check(packet.build(candidate["simulation"], candidate["journal"]), label + ": build rejected " + packet.error)
	check(initial == oracle.fingerprint(candidate["simulation"], candidate["journal"]), label + ": build mutated state")
	packet = null
	var initial_rng: int = candidate["simulation"].state.gameplay_rng.state
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	kernel.detailed_trace = true
	kernel.run(ticks, true)
	var compared: int = 0
	var completion_ticks: Array[int] = []
	var purchases: Array[Dictionary] = []
	var automatic_ticks: Array[int] = []
	for tick: int in range(ticks):
		var mark: int = control["journal"].events.size()
		var log_mark: int = control["simulation"].state.gameplay_log.events.size()
		control["simulation"].update(STEP, true)
		if View.capture(control["simulation"], control["journal"], true) != kernel.trace[tick]:
			check(false, label + ": first mismatch tick " + str(tick + 1))
			break
		for index: int in range(mark, control["journal"].events.size()):
			if control["journal"].events[index]["event"] in ["normal", "critical"]:
				completion_ticks.append(tick + 1)
		for index: int in range(log_mark, control["simulation"].state.gameplay_log.events.size()):
			var event: Dictionary = control["simulation"].state.gameplay_log.events[index]
			if event["event"] == "automatic_upgrade_applied" and event["details"]["upgrade_id"] == "after_auto_start":
				automatic_ticks.append(tick + 1)
			if event["category"] == "purchase":
				purchases.append({"tick": tick + 1, "event": event})
		compared += 1
	check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), label + ": complete graph differs")
	check(oracle.failures.is_empty(), label + ": graph oracle failed")
	check(kernel.counters["kernel_ticks"] > 0 and kernel.counters["reasons"].is_empty(), label + ": no supported execution")
	if label in ["real_completion", "critical", "auto", "completion_purchase", "level_dependency", "ash_heavy", "completion_heavy", "reached_manual_near"]:
		check(not completion_ticks.is_empty(), label + ": completion not exercised")
	if label == "real_completion":
		check(candidate["simulation"].state.resource_statistics.get_total_produced(ResourceIds.CRYSTALLIZED_FLAME) == 1.0, "Real first Forge reward missing")
	if label in ["completion_purchase", "auto_competing"]:
		check(not purchases.is_empty() and int(purchases[0]["tick"]) == int(completion_ticks[0]), "Completion and funded autobuy were not on the same tick")
	if label == "auto_competing":
		check(purchases.size() >= 2 and purchases[0]["event"]["source"] == "autobuyer" and purchases[1]["event"]["source"] == "upgrade_autobuyer", "Cycle/buyer competition order missing")
	if label == "cycle_upgrade":
		check(not purchases.is_empty() and kernel.counters["structural_invalidations"] > 0, "Cycle speed purchase did not reconstruct")
	if label == "auto_header":
		check(automatic_ticks == [2] and kernel.counters["cycle_invalidations"] > 0, "Auto-start level requirement missed next header")
	if label == "mode_events":
		check(candidate["simulation"].state.gameplay_rng.state == initial_rng, "Wrong-mode event consumed RNG")
	if label == "critical":
		check(candidate["simulation"].state.gameplay_rng.state != initial_rng, "Critical RNG was not exercised")
	if label == "level_dependency":
		check(kernel.counters["structural_invalidations"] > 0, "Completion level loss did not invalidate")
	if label == "completion_heavy":
		check(completion_ticks.size() > 10, "Completion stress did not repeatedly craft")
		check(kernel.counters["builds"] < completion_ticks.size() / 2, "Completion-only progress rebuilt on every craft")
	if label in ["empty", "idle", "auto_disabled", "auto_locked", "paused", "zero_speed", "auto_empty", "auto_unfunded", "auto_paused", "paused_operating"]:
		check(completion_ticks.is_empty(), label + ": unexpectedly completed")
	if label == "partial":
		check(candidate["simulation"].state.simulation_statistics.get_total_consumed(ResourceIds.MATTER) > 0.0 and not candidate["simulation"].state.get_generator("infernal_forge").operating, "Partial cycle did not consume and stop")
	cases.append({"label": label, "ticks": ticks, "compared_ticks": compared, "completion_ticks": completion_ticks, "purchases": purchases, "automatic_ticks": automatic_ticks, "signals": candidate["journal"].events, "counters": kernel.counters.duplicate(true)})


func _reentry() -> void:
	var candidate: Dictionary = context("partial")
	var control: Dictionary = context("partial")
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	kernel.detailed_trace = true
	for change: String in ["empty", "fund", "ash_high", "ash_low", "level", "upgrade", "pause", "unpause", "auto_on", "auto_off", "fallback", "resume"]:
		for item: Dictionary in [candidate, control]:
			var state: GameState = item["simulation"].state
			var forge: Generator = state.get_generator("infernal_forge")
			match change:
				"empty": state.set_resource_amount(ResourceIds.MATTER, 0.0)
				"fund": state.set_resource_amount(ResourceIds.MATTER, 10000.0)
				"ash_high": state.set_resource_amount(ResourceIds.ASH, 10000000.0)
				"ash_low": state.set_resource_amount(ResourceIds.ASH, 10.0)
				"level": forge.level += 1
				"upgrade":
					var upgrade: Upgrade = Fixtures.Automation.add_upgrade(state, "cycle_speed_probe", forge.definition.id, 0.0, [], [UpgradeEffect.modifier(forge.definition.id, ModifierTypes.CYCLE_SPEED, 1.5)])
					check(item["simulation"].buy_upgrade(upgrade.definition.id), "Cycle speed upgrade failed")
				"pause": forge.manually_paused = true
				"unpause": forge.manually_paused = false
				"auto_on": Fixtures.enable_auto(state)
				"auto_off": forge.auto_run_cycles = false
				"fallback": forge.get_operation_mode().completion_item_outputs.append({"item_id": "relic_shard", "quantity": 1})
				"resume": forge.get_operation_mode().completion_item_outputs.clear()
		kernel.run(5, true)
		for tick: int in range(5):
			control["simulation"].update(STEP, true)
			check(kernel.trace[tick] == View.capture(control["simulation"], control["journal"], true), "Reentry mismatch " + change)
	check(kernel.counters["fallback_ticks"] == 5 and kernel.counters["reasons"].has("unsupported_cycle_inventory"), "Unsupported recipe/reentry boundary missing")
	cases.append({"reentry": true, "counters": kernel.counters.duplicate(true)})


func _probability_edges() -> void:
	for chance: float in [0.0, 0.5, 1.0]:
		var candidate: Dictionary = context("critical")
		var control: Dictionary = context("critical")
		for item: Dictionary in [candidate, control]:
			item["simulation"].state.get_generator("infernal_forge").event_effects = Fixtures.event_effects(chance, chance)
		var before: int = candidate["simulation"].state.gameplay_rng.state
		var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
		kernel.detailed_trace = true
		kernel.run(2, true)
		for tick: int in range(2):
			control["simulation"].update(STEP, true)
			check(kernel.trace[tick] == View.capture(control["simulation"], control["journal"], true), "Probability edge differs")
		check((candidate["simulation"].state.gameplay_rng.state != before) == (chance == 0.5), "Probability edge draw count changed")


func _probe_parity() -> void:
	var measured: Dictionary = context("completion_heavy")
	var control: Dictionary = context("completion_heavy")
	measured["simulation"] = preload("res://tests/experimental/cycle_native_probe.gd").new(measured["simulation"].state)
	measured["journal"] = Events.new()
	measured["journal"].attach(measured["simulation"])
	for tick: int in range(100):
		measured["simulation"].update(STEP, true)
		control["simulation"].update(STEP, true)
		check(View.capture(measured["simulation"], measured["journal"], true) == View.capture(control["simulation"], control["journal"], true), "Cycle instrumentation changed gameplay")
	var packet: RefCounted = Packet.new()
	check(not packet.build(measured["simulation"], measured["journal"]) and packet.error == "unknown_simulation_script", "Diagnostic cycle script admitted")
	cases.append({"probe_parity_ticks": 100, "metrics": measured["simulation"].metrics.duplicate(true)})


func _unsupported() -> void:
	for kind: String in ["other_cycle", "inventory", "recipe", "missing_resource"]:
		var item: Dictionary = context("active")
		var state: GameState = item["simulation"].state
		var forge: Generator = state.get_generator("infernal_forge")
		match kind:
			"other_cycle": state.get_generator("relic_shard_extractor").cycle_active = true
			"inventory": forge.get_operation_mode().completion_item_outputs.append({"item_id": "relic_shard", "quantity": 1})
			"recipe": forge.get_operation_mode().crafting_input_requirements.append({"item_id": "relic_shard", "quantity": 1})
			"missing_resource": forge.get_operation_mode().completion_outputs.append(GeneratorIO.new("unregistered_probe", 1.0))
		var before: PackedByteArray = Oracle.new().fingerprint(item["simulation"], item["journal"])
		var packet: RefCounted = Packet.new()
		check(not packet.build(item["simulation"], item["journal"]), "Unsupported cycle accepted: " + kind)
		check(before == Oracle.new().fingerprint(item["simulation"], item["journal"]), "Rejected build mutated state")

	var item: Dictionary = context("active")
	var rng := UnknownRng.new()
	rng.seed = item["simulation"].state.gameplay_rng.seed
	rng.state = item["simulation"].state.gameplay_rng.state
	item["simulation"].state.gameplay_rng = rng
	var packet: RefCounted = Packet.new()
	check(not packet.build(item["simulation"], item["journal"]) and packet.error == "unsupported_cycle_rng", "Custom RNG script admitted")
