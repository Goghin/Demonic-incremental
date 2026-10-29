extends RefCounted

const Fixtures = preload("res://tests/experimental/consumer_fixtures.gd")
const Kernel = preload("res://tests/experimental/exact_flow_kernel.gd")
const Packet = preload("res://tests/experimental/exact_flow_packet.gd")
const View = preload("res://tests/experimental/exact_flow_view.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const Oracle = preload("res://tests/experimental/transaction_tests.gd")
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
	for label: String in Fixtures.REACHED:
		_differential(label, 2000)
	_differential("consumer_50000", 10000)
	for label: String in Fixtures.DIAGNOSTIC:
		_differential(label, 100)
	for label: String in ["mid", "forge_competing"]:
		_differential(label, 100)
	_reserve_edges()
	_repeated_transitions()
	_reentry()
	return {"cases": cases, "failures": failures}


func _differential(label: String, ticks: int) -> void:
	var candidate: Dictionary = context(label)
	var control: Dictionary = context(label)
	var oracle: RefCounted = Oracle.new()
	var original: PackedByteArray = oracle.fingerprint(candidate["simulation"], candidate["journal"])
	var packet: RefCounted = Packet.new()
	packet.build(candidate["simulation"], candidate["journal"])
	check(original == oracle.fingerprint(candidate["simulation"], candidate["journal"]), label + ": build wrote live state")
	packet = null
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	kernel.collect_flow_counters = true
	check(kernel.run(ticks, true), label + ": failed run")
	var naive_matter_draw: float = 0.0
	if label == "multi_dynamic":
		var generator: Generator = control["simulation"].state.get_generator("diagnostic_consumer")
		naive_matter_draw = generator.get_input_consumption_per_second(generator.get_active_inputs()[1], control["simulation"].state) * STEP
	var mite_operating_ticks: int = 0
	var compared: int = 0
	for tick: int in range(ticks):
		control["simulation"].update(STEP, true)
		if control["simulation"].state.get_generator("lava_mite_colony").operating:
			mite_operating_ticks += 1
		if tick == 0 and label.begins_with("multi_"):
			var state: GameState = control["simulation"].state
			var generator: Generator = state.get_generator("diagnostic_consumer")
			if label == "multi_dynamic":
				check(state.simulation_statistics.get_total_consumed(ResourceIds.MATTER) != naive_matter_draw, "Dynamic input probe did not distinguish sequential consumption from a shared snapshot")
			if label in ["multi_partial", "multi_tiny"]:
				check(not generator.operating and state.simulation_statistics.get_total_consumed(ResourceIds.MATTER) > 0.0, "Partial operation witness missing")
			if label == "multi_exact":
				check(generator.operating and state.get_resource_amount(ResourceIds.MATTER) == 0.0, "Exact-boundary exhaustion witness missing")
			if label == "multi_replenished":
				check(generator.operating and state.simulation_statistics.get_total_produced(ResourceIds.MATTER) > 0.0 and state.simulation_statistics.get_total_consumed(ResourceIds.MATTER) > 0.0, "Earlier output was not consumed in the same tick")
		if View.capture(control["simulation"], control["journal"]) != kernel.trace[tick]:
			check(false, label + ": first divergent tick " + str(tick + 1))
			break
		compared += 1
	check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), label + ": full graph differs")
	check(oracle.failures.is_empty(), label + ": oracle failed")
	check(kernel.counters["kernel_ticks"] > 0, label + ": no kernel execution")
	if label == "mite_entry":
		check(int(kernel.flow_counts.get("controller_transitions", 0)) > 0, "No throttle entry observed")
	if label == "mite_recovery":
		check(int(kernel.flow_counts.get("controller_transitions", 0)) > 0, "No throttle recovery observed")
	if label in ["multi_partial", "multi_tiny"]:
		check(int(kernel.flow_counts.get("partial_operations", 0)) > 0, label + ": no partial duration")
	if label in ["multi_partial", "multi_tiny", "multi_exact"]:
		check(int(kernel.flow_counts.get("input_exhaustions", 0)) > 0, label + ": no exact exhaustion event")
	if label in ["consumer_20000", "consumer_50000"]:
		check(mite_operating_ticks > 0, label + ": reached colony never operated")
	cases.append({"mite_operating_ticks": mite_operating_ticks, "label": label, "ticks": ticks, "compared_ticks": compared, "counters": kernel.counters.duplicate(true), "flows": kernel.flow_counts.duplicate(true)})


func _reserve_edges() -> void:
	for resource_id: String in [ResourceIds.HEAT, ResourceIds.ASH]:
		for offset: float in [-0.000000001, 0.0, 0.000000001]:
			var candidate: Dictionary = context("mite_recovery")
			var control: Dictionary = context("mite_recovery")
			for item: Dictionary in [candidate, control]:
				var state: GameState = item["simulation"].state
				var colony: Generator = state.get_generator("lava_mite_colony")
				if resource_id == ResourceIds.ASH:
					# Below the adaptation join, normal Ash rate is independent
					# of Ash stock. Test reserve equality without solving a curve.
					state.set_resource_amount(ResourceIds.ASH, 1.0)
				for input: GeneratorIO in colony.get_active_inputs():
					if input.resource_id == resource_id:
						var normal_rate: float = colony.get_input_consumption_per_second(input, state, false)
						state.set_resource_amount(resource_id, normal_rate + offset)
			var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
			kernel.run(1)
			control["simulation"].update(STEP, true)
			check(View.capture(control["simulation"], control["journal"]) == View.capture(candidate["simulation"], candidate["journal"]), "Controller reserve-edge parity differs")
			check(candidate["simulation"].state.get_generator("lava_mite_colony").is_throttled == (offset < 0.0), "Normal reserve equality/hysteresis changed for " + resource_id)
			check(kernel.counters["kernel_ticks"] == 1, "Reserve edge used native fallback")
	cases.append({"reserve_edge_checks": 6})


func _repeated_transitions() -> void:
	var candidate: Dictionary = context("mite_entry")
	var control: Dictionary = context("mite_entry")
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	kernel.collect_flow_counters = true
	for index: int in range(40):
		for item: Dictionary in [candidate, control]:
			var state: GameState = item["simulation"].state
			state.set_resource_amount(ResourceIds.HEAT, 600.0 if index % 2 == 0 else 100000000.0)
			state.set_resource_amount(ResourceIds.ASH, 10000.0)
			# TimeManager-like EXTERNAL penalty changes occur only between calls.
			state.set_lava_mite_dormancy_penalty(0.5 if index % 4 >= 2 else 0.0)
		kernel.run(1)
		control["simulation"].update(STEP, true)
		check(View.capture(candidate["simulation"], candidate["journal"]) == View.capture(control["simulation"], control["journal"]), "Repeated controller/penalty transition differs")
	check(int(kernel.flow_counts.get("controller_transitions", 0)) >= 20, "No repeated hysteresis transitions")
	cases.append({"repeated_transitions": 40, "counters": kernel.counters.duplicate(true), "flows": kernel.flow_counts.duplicate(true)})


func _reentry() -> void:
	var candidate: Dictionary = context("multi_dynamic")
	var control: Dictionary = context("multi_dynamic")
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	for boundary: String in ["initial", "reverse", "level", "draw", "zero_level", "resume", "transfer", "ordinary", "unsupported", "reenter"]:
		for item: Dictionary in [candidate, control]:
			var state: GameState = item["simulation"].state
			var generator: Generator = state.get_generator("diagnostic_consumer")
			match boundary:
				"reverse": generator.get_operation_mode().inputs.reverse()
				"level": generator.level = 2
				"draw": generator.get_active_inputs()[0].amount_per_second *= 1.125
				"zero_level":
					generator.level = 0
					generator.operating = false
				"resume": generator.level = 1
				"transfer": generator.get_operation_mode().is_resource_transfer = true
				"ordinary": generator.get_operation_mode().is_resource_transfer = false
				"unsupported": state.prestige_planning = true
				"reenter": state.prestige_planning = false
		kernel.run(5, true)
		for tick: int in range(5):
			control["simulation"].update(STEP, true)
			check(View.capture(control["simulation"], control["journal"]) == kernel.trace[tick], "Consumer reconstruction differs after " + boundary)
	check(kernel.counters["fallback_ticks"] == 5 and kernel.counters["kernel_ticks"] == 45, "Fallback/resumption coverage incorrect")
	cases.append({"reentry": true, "counters": kernel.counters.duplicate(true)})
