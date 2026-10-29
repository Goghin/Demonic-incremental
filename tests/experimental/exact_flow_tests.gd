extends RefCounted

const Fixtures = preload("res://tests/experimental/ordered_flow_fixtures.gd")
const Kernel = preload("res://tests/experimental/exact_flow_kernel.gd")
const Packet = preload("res://tests/experimental/exact_flow_packet.gd")
const View = preload("res://tests/experimental/exact_flow_view.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const Oracle = preload("res://tests/experimental/transaction_tests.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var failures: Array[String] = []
var results: Array[Dictionary] = []

class UnknownAutomation extends GeneratorAutomationManager:
	pass


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func context(label: String, prefix: int = 0) -> Dictionary:
	var simulation := Simulation.new(Fixtures.make_state(label, prefix))
	var journal: RefCounted = Events.new()
	journal.attach(simulation)
	return {"simulation": simulation, "journal": journal}


func run_all() -> Dictionary:
	for ticks: int in [1, 10, 100, 2000]:
		_differential("early", ticks)
	for label: String in Fixtures.TARGETS:
		_differential(label, 30)
	_differential("early", 100, 68)
	_differential("mid", 600)
	_differential("forge_competing", 100)
	_invalidation()
	_dynamic_sensitivity()
	_boundaries()
	_rng_fallback()
	_automatic_event()
	_transaction()
	return {"failures": failures, "cases": results}


func _differential(label: String, ticks: int, prefix: int = 0) -> void:
	var candidate: Dictionary = context(label, prefix)
	var control: Dictionary = context(label, prefix)
	var oracle: RefCounted = Oracle.new()
	var before: PackedByteArray = oracle.fingerprint(candidate["simulation"], candidate["journal"])
	var packet: RefCounted = Packet.new()
	packet.build(candidate["simulation"], candidate["journal"])
	check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == before, "Packet construction mutated authoritative state")
	packet = null
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	check(kernel.run(ticks, true), "Kernel run failed")
	var compared: int = 0
	for tick: int in range(ticks):
		control["simulation"].update(STEP, true)
		if View.capture(control["simulation"], control["journal"]) != kernel.trace[tick]:
			check(false, label + ": first tick-view mismatch at tick " + str(tick + 1))
			break
		compared += 1
	check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), label + ": complete final graph differs")
	check(oracle.failures.is_empty(), "Original snapshot failed")
	if label in ["early", "mid"]:
		check(kernel.counters["kernel_ticks"] > 0, "Supported representative fixture never entered the kernel: " + label)
	if label == "forge_competing":
		check(kernel.counters["kernel_ticks"] > 0 and kernel.counters["reasons"].is_empty(), "Supported Forge fixture did not execute")
	results.append({"label": label, "prefix": prefix, "ticks": ticks, "compared_ticks": compared, "counters": kernel.counters.duplicate(true)})


func _invalidation() -> void:
	var changes: Array[String] = ["none", "level", "pause", "modifier", "modifier_target", "sensitivity", "threshold", "phase", "resource_object", "output_unlock", "upgrade", "mode", "relic", "automation", "mite"]
	for change: String in changes:
		var candidate: Dictionary = context("early")
		var control: Dictionary = context("early")
		var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
		var oracle: RefCounted = Oracle.new()
		kernel.run(1)
		control["simulation"].update(STEP, true)
		for item: Dictionary in [candidate, control]:
			var state: GameState = item["simulation"].state
			var generator: Generator = state.get_generator("atomic_friction")
			match change:
				"level": generator.level += 1
				"pause": item["simulation"].toggle_generator_pause(generator.definition.id)
				"modifier": generator.modifiers[0].multiplier *= 1.125
				"modifier_target": generator._production_modifier_cache[ResourceIds.HEAT][0].target_id = ResourceIds.ASH
				"sensitivity": generator.modifier_sensitivities.append(ModifierSensitivity.new(generator.modifiers[0].id, 0.5))
				"threshold":
					state.heat_leak_scaling += 1.0
					state.realm_effects.heat_leak_threshold += 0.5
				"phase":
					for source: Generator in state.generators.values():
						for output: GeneratorIO in source.get_active_outputs():
							if output.discrete:
								source.production_progress = {output.resource_id: 0.999999999999}
				"resource_object":
					var replacement := ResourceState.new(state.resources[ResourceIds.HEAT].definition)
					replacement.amount = state.resources[ResourceIds.HEAT].amount
					state.resources[ResourceIds.HEAT] = replacement
				"output_unlock": generator.get_active_outputs()[0].unlocked = false
				"upgrade":
					state.set_resource_amount(ResourceIds.HEAT, 100000000.0)
					for upgrade: Upgrade in state.upgrades.values():
						if not upgrade.definition.automatic and item["simulation"].can_buy_upgrade(upgrade.definition.id):
							item["simulation"].buy_upgrade(upgrade.definition.id)
							break
				"mode": generator.operation_mode_id = "intensified_friction"
				"relic": state.relic_manager.add_stackable_item("relic_shard", 1)
				"automation": preload("res://tests/experimental/autobuyer_fixtures.gd").enable(state, "atomic_friction")
				"mite": state.get_generator("lava_mite_colony").level = 1
		check(kernel.run(10), "Reentry failed: " + change)
		for tick: int in range(10):
			control["simulation"].update(STEP, true)
		check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), "Stale packet after " + change)
		if change in ["mode", "relic"]:
			check(kernel.counters["fallback_ticks"] == 10, "Unsupported reentry did not fall back: " + change)
		if change in ["mite", "automation"]:
			check(kernel.counters["kernel_ticks"] > 1 and kernel.counters["reasons"].is_empty(), "Supported reentry did not use the expanded kernel contract: " + change)
		results.append({"invalidation": change, "counters": kernel.counters.duplicate(true)})


func _dynamic_sensitivity() -> void:
	var candidate: Dictionary = context("early")
	var control: Dictionary = context("early")
	for item: Dictionary in [candidate, control]:
		var generator: Generator = item["simulation"].state.get_generator("atomic_friction")
		var sensitivity := ModifierSensitivity.new(generator.modifiers[0].id, 0.25)
		sensitivity.dynamic = true
		sensitivity.dynamic_formula = ModifierSensitivity.DYNAMIC_RESOURCE_SQRT_INVERSE
		sensitivity.dynamic_resource_id = ResourceIds.MATTER
		generator.modifier_sensitivities.append(sensitivity)
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	kernel.run(100, true)
	for tick: int in range(100):
		control["simulation"].update(STEP, true)
		check(View.capture(control["simulation"], control["journal"]) == kernel.trace[tick], "Dynamic sensitivity changed a tick")


func _boundaries() -> void:
	var item: Dictionary = context("early")
	var callback: Callable = func(_id: String) -> void: pass
	item["simulation"].generator_unlocked.connect(callback)
	var packet: RefCounted = Packet.new()
	check(not packet.build(item["simulation"], item["journal"]) and packet.error == "external_observer", "External observer accepted")
	item["simulation"].generator_unlocked.disconnect(callback)
	var state: GameState = item["simulation"].state
	var original: GeneratorAutomationManager = state.generator_automation_manager
	state.generator_automation_manager = UnknownAutomation.new(state)
	packet = Packet.new()
	check(not packet.build(item["simulation"], item["journal"]) and packet.error == "unknown_runtime_dependency", "Unknown manager contract accepted")
	state.generator_automation_manager = original
	var kernel: RefCounted = Kernel.new(item["simulation"], item["journal"])
	check(not kernel.run(-1) and kernel.run(0), "Invalid tick lifecycle")


func _rng_fallback() -> void:
	var candidate: Dictionary = {}
	var control: Dictionary = {}
	for item: Dictionary in [candidate, control]:
		var state: GameState = Oracle.new()._rng_state()
		state.simulation_statistics = ResourceStatistics.new()
		for id: String in ["infernal_forge", "relic_shard_extractor"]:
			var generator: Generator = state.get_generator(id)
			generator.cycle_active = true
			generator.operating = false
			generator.cycle_progress = generator.get_cycle_duration() - 0.00000001
			generator.cycle_critical_chance_snapshot = 0.25
		var simulation := Simulation.new(state)
		var journal: RefCounted = Events.new()
		journal.attach(simulation)
		item["simulation"] = simulation
		item["journal"] = journal
	var before_rng: int = candidate["simulation"].state.gameplay_rng.state
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	kernel.run(10, true)
	for tick: int in range(10):
		control["simulation"].update(STEP, true)
		check(kernel.trace[tick] == View.capture(control["simulation"], control["journal"]), "RNG/cycle fallback tick differs")
	check(kernel.counters["kernel_ticks"] == 0, "Crafting was optimized")
	check(candidate["simulation"].state.gameplay_rng.state != before_rng and not candidate["simulation"].state.relic_manager.inventory.is_empty(), "Fallback fixture exercised no random relic reward")
	results.append({"rng_fallback": true, "events": candidate["journal"].events, "counters": kernel.counters.duplicate(true)})


func _automatic_event() -> void:
	var candidate: Dictionary = context("early")
	var control: Dictionary = context("early")
	for item: Dictionary in [candidate, control]:
		var state: GameState = item["simulation"].state
		state.get_upgrade("thermic_mass").level = 0
		item["simulation"].rebuild_upgrade_effects()
		state.set_resource_amount(ResourceIds.MATTER, 0.0)
		for generator: Generator in state.generators.values():
			for output: GeneratorIO in generator.get_active_outputs():
				if output.discrete and output.resource_id == ResourceIds.MATTER:
					generator.production_progress[output.resource_id] = 0.999999999999
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	kernel.run(150, true)
	for tick: int in range(150):
		control["simulation"].update(STEP, true)
		check(kernel.trace[tick] == View.capture(control["simulation"], control["journal"]), "Automatic-event invalidation differs at " + str(tick + 1))
	check(kernel.counters["event_ticks"] > 0 and kernel.counters["kernel_ticks"] > 0, "Automatic action did not exit and rebuild a live packet")
	results.append({"automatic_event": true, "counters": kernel.counters.duplicate(true)})


func _transaction() -> void:
	var candidate: Dictionary = context("early")
	var control: Dictionary = context("early")
	var oracle: RefCounted = Oracle.new()
	var before: PackedByteArray = oracle.fingerprint(candidate["simulation"], candidate["journal"])
	var transaction: RefCounted = preload("res://tests/experimental/simulation_transaction.gd").new(candidate["simulation"], candidate["journal"])
	check(transaction.begin(), "Kernel transaction begin failed")
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	kernel.run(100)
	check(transaction.rollback(), "Kernel transaction rollback failed")
	check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == before, "Kernel transaction leaked state")
	kernel.run(100)
	for tick: int in range(100):
		control["simulation"].update(STEP, true)
	check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), "Kernel continuation after rollback differs")
