extends RefCounted

const Fixtures = preload("res://tests/experimental/essence_nexum_fixtures.gd")
const Kernel = preload("res://tests/experimental/exact_flow_kernel.gd")
const Packet = preload("res://tests/experimental/exact_flow_packet.gd")
const Previous = preload("res://tests/experimental/baselines/exact_flow_0a008c0_kernel.gd")
const View = preload("res://tests/experimental/exact_flow_view.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const Oracle = preload("res://tests/experimental/transaction_tests.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
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
	for label: String in Fixtures.DIAGNOSTICS:
		if OS.get_environment("RESOURCE_TEST_LABEL") != "" and label != OS.get_environment("RESOURCE_TEST_LABEL"):
			continue
		_differential(label, 2000 if label in ["mixed_resources", "essence_feedback", "feedback_stress"] else 100)
	if OS.get_environment("RESOURCE_TEST_LABEL") != "":
		return {"cases": cases, "failures": failures}
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/essence_nexum_progression.json"))
	check(manifest["failures"].is_empty(), "Reached fixture construction incomplete")
	for label: String in manifest["snapshots"]:
		_differential("earned_" + label, 2000)
	_reentry()
	_cycle_resources()
	return {"cases": cases, "failures": failures}


func _differential(label: String, ticks: int) -> void:
	print("RESOURCE_DIFFERENTIAL ", label, " ", ticks)
	var candidate: Dictionary = context(label)
	var control: Dictionary = context(label)
	var prior: Dictionary = context(label)
	var oracle: RefCounted = Oracle.new()
	var initial: PackedByteArray = oracle.fingerprint(candidate["simulation"], candidate["journal"])
	var packet: RefCounted = Packet.new()
	check(packet.build(candidate["simulation"], candidate["journal"]), label + ": build rejected " + packet.error)
	check(initial == oracle.fingerprint(candidate["simulation"], candidate["journal"]), label + ": construction mutated state")
	packet = null
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	kernel.detailed_trace = true
	kernel.collect_flow_counters = true
	kernel.run(ticks, true)
	var previous: RefCounted = Previous.new(prior["simulation"], prior["journal"])
	previous.detailed_trace = true
	previous.run(ticks, true)
	var initially_discovered: Dictionary = control["simulation"].state.discovered_resources.duplicate()
	var naive_draw: float = 0.0
	if label == "sequential_feedback":
		var probe: Generator = control["simulation"].state.get_generator("ordered_resource_probe")
		naive_draw = probe.get_input_consumption_per_second(probe.get_active_inputs()[1], control["simulation"].state) * STEP
	var compared: int = 0
	for tick: int in range(ticks):
		control["simulation"].update(STEP, true)
		var reference: PackedByteArray = View.capture(control["simulation"], control["journal"], true)
		if kernel.trace[tick] != reference or previous.trace[tick] != reference:
			check(false, label + ": first different tick " + str(tick + 1))
			break
		if tick == 0:
			if label == "compression_exact":
				check(control["simulation"].state.get_resource_amount(ResourceIds.ESSENCE) == 0.0 and control["simulation"].state.get_generator("thermal_compressor").operating, "Exact first-tick boundary missing")
			if label == "sequential_feedback":
				check(control["simulation"].state.simulation_statistics.get_total_consumed(ResourceIds.NEXUM) != naive_draw, "Sequential Essence draw did not affect later input")
		compared += 1
	check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), label + ": full graph differs")
	check(oracle.failures.is_empty(), label + ": oracle failed")
	check(kernel.counters["kernel_ticks"] > 0 and kernel.counters["reasons"].is_empty(), label + ": no kernel execution")
	var state: GameState = candidate["simulation"].state
	var statistics: ResourceStatistics = state.simulation_statistics
	if label in ["compression_phase", "compression_low_ash"]:
		check(statistics.get_total_produced(ResourceIds.NEXUM) > 0.0, "Nexum integer output not crossed")
		check(not initially_discovered.get(ResourceIds.NEXUM, false) and state.is_resource_discovered(ResourceIds.NEXUM), "Nexum discovery not exercised")
	if label == "essence_only":
		check(not initially_discovered.get(ResourceIds.ESSENCE, false) and state.is_resource_discovered(ResourceIds.ESSENCE), "Essence discovery not exercised")
	if label == "transfer_no_input":
		check(statistics.get_total_produced(ResourceIds.MATTER) == 0.0 and not state.get_generator("thermal_compressor")._production_modifier_cache.has(ResourceIds.MATTER), "Empty transfer input did not preserve native zero-output/cache behavior")
	if label == "compression_empty":
		check(statistics.get_total_consumed(ResourceIds.ESSENCE) == 0.0, "Empty compressor consumed")
	if label in ["compression_partial", "compression_exact", "expansion_partial"]:
		check(not state.get_generator("thermal_compressor").operating and (statistics.get_total_consumed(ResourceIds.ESSENCE) > 0.0 or statistics.get_total_consumed(ResourceIds.NEXUM) > 0.0), "Exhaustion not exercised: " + label)
	if label in ["expansion", "expansion_partial", "transfer_modifiers"]:
		check(statistics.get_total_produced(ResourceIds.MATTER) == statistics.get_total_consumed(ResourceIds.NEXUM), "Native transfer quantities differ")
		check(not state.get_generator("thermal_compressor")._production_modifier_cache.has(ResourceIds.MATTER), "Transfer populated ordinary production cache")
	if label == "essence_threshold":
		check(state.get_upgrade("essence_influence").level > 0 and kernel.counters["event_ticks"] > 0, "Essence automatic threshold not crossed")
	if label == "essence_feedback":
		check(statistics.get_total_produced(ResourceIds.ESSENCE) > 0.0 and state.get_upgrade("essence_influence").level > 0, "Native Essence feedback not exercised")
	if label == "automation_resources":
		check(kernel.counters["structural_invalidations"] > 0 and state.get_upgrade("essence_retention").level > 0, "Essence upgrade purchase not exercised")
	if label == "forge_resources":
		check(statistics.get_total_produced(ResourceIds.CRYSTALLIZED_FLAME) > 0.0, "Forge completion alongside resources missing")
	cases.append({"label": label, "ticks": ticks, "compared_ticks": compared, "counters": kernel.counters.duplicate(true), "flows": kernel.flow_counts.duplicate(true), "initial_discovery": initially_discovered, "final_discovery": state.discovered_resources.duplicate(), "produced": {"essence": statistics.get_total_produced(ResourceIds.ESSENCE), "nexum": statistics.get_total_produced(ResourceIds.NEXUM)}, "consumed": {"essence": statistics.get_total_consumed(ResourceIds.ESSENCE), "nexum": statistics.get_total_consumed(ResourceIds.NEXUM)}})


func _reentry() -> void:
	var candidate: Dictionary = context("mixed_resources")
	var control: Dictionary = context("mixed_resources")
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	kernel.detailed_trace = true
	var oracle: RefCounted = Oracle.new()
	for change: String in ["empty", "recover", "expansion", "tiny", "nexum_refill", "compression", "level", "modifier", "threshold", "fallback", "resume", "pause", "unpause"]:
		for item: Dictionary in [candidate, control]:
			var state: GameState = item["simulation"].state
			var compressor: Generator = state.get_generator("thermal_compressor")
			match change:
				"empty": state.set_resource_amount(ResourceIds.ESSENCE, 0.0)
				"recover":
					state.set_resource_amount(ResourceIds.ESSENCE, 100.0)
					state.set_resource_amount(ResourceIds.MATTER, 10000.0)
				"expansion": check(compressor.set_operation_mode("expansion"), "Expansion change rejected")
				"tiny": state.set_resource_amount(ResourceIds.NEXUM, 1e-20)
				"nexum_refill": state.set_resource_amount(ResourceIds.NEXUM, 1.0)
				"compression": check(compressor.set_operation_mode("compression"), "Compression change rejected")
				"level":
					state.set_resource_amount(ResourceIds.HEAT, compressor.get_cost(state) * 2.0)
					check(item["simulation"].buy_generator("thermal_compressor", "resource_probe"), "Generator purchase rejected")
				"modifier":
					compressor.modifiers.append(Modifier.new(ModifierTypes.PRODUCTION, ResourceIds.NEXUM, 1.125))
					compressor.invalidate_production_modifier_cache()
				"threshold": state.set_resource_amount(ResourceIds.ASH, 100.000000001)
				"fallback": state.prestige_planning = true
				"resume": state.prestige_planning = false
				"pause": compressor.manually_paused = true
				"unpause": compressor.manually_paused = false
		var consumed_essence: float = candidate["simulation"].state.simulation_statistics.get_total_consumed(ResourceIds.ESSENCE)
		var consumed_nexum: float = candidate["simulation"].state.simulation_statistics.get_total_consumed(ResourceIds.NEXUM)
		# Full identity-aware graph after EACH tick in boundary probes.
		for tick: int in range(5):
			kernel.run(1)
			control["simulation"].update(STEP, true)
			check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), "Boundary full graph differs: " + change)
		if change == "recover":
			check(candidate["simulation"].state.simulation_statistics.get_total_consumed(ResourceIds.ESSENCE) > consumed_essence, "Essence-funded operation did not recover")
		if change == "nexum_refill":
			check(candidate["simulation"].state.simulation_statistics.get_total_consumed(ResourceIds.NEXUM) > consumed_nexum, "Expansion did not recover after Nexum refill")
	check(kernel.counters["reasons"].get("instrumentation_or_prestige", 0) == 5 and kernel.counters["kernel_ticks"] > 0, "Explicit unsupported boundary/resumption missing")
	check(oracle.failures.is_empty(), "Boundary oracle failed")
	cases.append({"reentry_ticks": 65, "counters": kernel.counters.duplicate(true)})


func _cycle_resources() -> void:
	var candidate: Dictionary = context("forge_resources")
	var control: Dictionary = context("forge_resources")
	for item: Dictionary in [candidate, control]:
		var forge: Generator = item["simulation"].state.get_generator("infernal_forge")
		forge.get_operation_mode().inputs.append(GeneratorIO.new(ResourceIds.ESSENCE, 1.0))
		forge.get_operation_mode().inputs.append(GeneratorIO.new(ResourceIds.NEXUM, 0.2))
		forge.get_operation_mode().completion_outputs.append(GeneratorIO.new(ResourceIds.ESSENCE, 0.25))
		forge.get_operation_mode().completion_outputs.append(GeneratorIO.new(ResourceIds.NEXUM, 0.5))
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	var oracle: RefCounted = Oracle.new()
	for tick: int in range(10):
		kernel.run(1)
		control["simulation"].update(STEP, true)
		check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), "Native cycle resource rewards differ")
	check(candidate["simulation"].state.simulation_statistics.get_total_produced(ResourceIds.NEXUM) > 0.0, "Cycle Nexum reward not exercised")
	check(kernel.counters["reasons"].is_empty() and kernel.counters["kernel_ticks"] > 0 and oracle.failures.is_empty(), "Cycle resources fell back")
