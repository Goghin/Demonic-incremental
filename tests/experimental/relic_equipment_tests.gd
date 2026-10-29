extends RefCounted

const Fixtures = preload("res://tests/experimental/relic_equipment_fixtures.gd")
const Kernel = preload("res://tests/experimental/exact_flow_kernel.gd")
const Packet = preload("res://tests/experimental/exact_flow_packet.gd")
const Previous = preload("res://tests/experimental/baselines/exact_flow_eeb85dc_kernel.gd")
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
	var focused: String = OS.get_environment("RELIC_TEST_LABEL")
	if focused != "":
		_differential(focused, 1000 if focused == "forge_auto" else 100)
		return {"cases": cases, "failures": failures}
	for label: String in Fixtures.DIAGNOSTICS:
		_differential(label, 3000 if label == "forge_auto" else (500 if label in ["forge_speed", "forge_sensitivity"] else 100))
	for id: String in Fixtures.Generation.EFFECT_DEFINITIONS:
		_differential("effect/" + id, 100)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/relic_equipment_progression.json"))
	check(manifest["failures"].is_empty(), "Earned fixture construction failed")
	for name: String in manifest["snapshots"]:
		_differential("reached_" + name, 2000)
	_boundaries()
	_native_callback()
	_critical_witness()
	_save_load_boundary()
	_unsupported()
	return {"cases": cases, "failures": failures}


func _differential(label: String, ticks: int) -> void:
	print("RELIC_DIFFERENTIAL ", label, " ", ticks)
	var candidate: Dictionary = context(label)
	var control: Dictionary = context(label)
	var previous: Dictionary = context(label)
	var oracle: RefCounted = Oracle.new()
	var before: PackedByteArray = oracle.fingerprint(candidate["simulation"], candidate["journal"])
	var packet: RefCounted = Packet.new()
	var admitted: bool = packet.build(candidate["simulation"], candidate["journal"])
	check(admitted == (label != "crafting"), label + ": unexpected admission " + packet.error)
	check(before == oracle.fingerprint(candidate["simulation"], candidate["journal"]), label + ": admission mutated state")
	packet = null
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	kernel.detailed_trace = true
	kernel.collect_flow_counters = true
	kernel.run(ticks, true)
	var old: RefCounted = Previous.new(previous["simulation"], previous["journal"])
	old.detailed_trace = true
	old.run(ticks, true)
	var compared: int = 0
	for tick: int in range(ticks):
		control["simulation"].update(STEP, true)
		var expected: PackedByteArray = View.capture(control["simulation"], control["journal"], true)
		if kernel.trace[tick] != expected or old.trace[tick] != expected:
			check(false, label + ": first divergent tick " + str(tick + 1))
			break
		compared += 1
	check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), label + ": complete graph differs")
	check(oracle.failures.is_empty(), label + ": graph capture failed")
	if label == "crafting":
		check(kernel.counters["kernel_ticks"] == 0 and not candidate["simulation"].state.relic_manager.inventory.is_empty(), "Active crafting fallback/reward missing")
	else:
		check(kernel.counters["kernel_ticks"] > 0 and kernel.counters["reasons"].is_empty(), label + ": no admitted execution")
	var completions: int = 0
	for event: Dictionary in candidate["journal"].events:
		if event["event"] in ["normal", "critical"]:
			completions += 1
	if label in ["forge_critical", "forge_completion"]:
		check(completions > 0, "Equipped Forge did not complete")
	if label == "forge_auto":
		check(completions >= 2, "Equipped native auto-run did not repeatedly complete")
	if label == "secondary":
		var entry: Dictionary = candidate["simulation"].state.relic_manager.inventory[0]
		check(entry.has("secondary_stat") and entry.has("additional_secondary_stats"), "Rare native multiple rolls missing")
	cases.append({"label": label, "ticks": ticks, "compared_ticks": compared, "completions": completions, "counters": kernel.counters.duplicate(true), "flows": kernel.flow_counts.duplicate(true)})


func _boundaries() -> void:
	var candidate: Dictionary = context("one")
	var control: Dictionary = context("one")
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	var oracle: RefCounted = Oracle.new()
	for change: String in ["initial", "bare_equip", "rebuild", "unequip", "move", "slots", "slot_unlock", "upgrade", "mode", "inventory", "craft", "reenter"]:
		for item: Dictionary in [candidate, control]:
			var state: GameState = item["simulation"].state
			match change:
				"bare_equip":
					var id: String = state.relic_manager.add_random_relic_for_tier(3, 0.0, "output_increase")
					check(state.relic_manager.equip_relic("atomic_friction", id, state), "Bare equip failed")
				"rebuild": state.rebuild_relic_modifiers()
				"unequip":
					state.relic_manager.unequip_relic("atomic_friction")
					state.rebuild_relic_modifiers()
				"move":
					check(state.relic_manager.equip_relic("molecular_agitation", str(state.relic_manager.inventory[0]["instance_id"]), state), "Holder move failed")
					state.rebuild_relic_modifiers()
				"slots":
					# Native capacity changes are external boundaries; restore data,
					# not a production mutation/version counter.
					state.eternal_flame_state.set_upgrade_level("attunement_molecular_agitation", 0)
					state.rebuild_relic_modifiers()
				"slot_unlock":
					state.eternal_flame_state.set_upgrade_level("attunement_molecular_agitation", 1)
					state.rebuild_relic_modifiers()
				"upgrade":
					state.set_resource_amount(ResourceIds.HEAT, state.get_generator("atomic_friction").get_cost(state) * 2.0)
					check(item["simulation"].buy_generator("atomic_friction", "equipment_boundary"), "Native generator purchase failed")
				"mode":
					state.get_upgrade("intensified_friction_essence").level = 1
					item["simulation"].rebuild_upgrade_effects()
					check(state.get_generator("atomic_friction").set_operation_mode("intensified_friction"), "Native mode change failed")
				"inventory":
					state.relic_manager.add_stackable_item("relic_shard", 10)
				"craft":
					var crucible: Generator = state.get_generator("relic_shard_extractor")
					crucible.manually_paused = false
					crucible.set_operation_mode("forge_relic")
					state.set_resource_amount(ResourceIds.MATTER, 100.0)
					var entry: Dictionary = state.relic_manager.inventory[-1]
					check(state.relic_manager.move_inventory_entry_to_machine_slot(str(entry["instance_id"]), crucible.definition.id, 0), "Ingredient slot move failed")
					check(item["simulation"].buy_generator(crucible.definition.id, "equipment_boundary"), "Native craft startup failed")
					crucible.cycle_progress = crucible.get_cycle_duration() - 0.000001
		for tick: int in range(3):
			kernel.run(1)
			control["simulation"].update(STEP, true)
			check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), "Boundary graph differs: " + change)
	check(kernel.counters["reasons"].has("unsupported_cycle_contract") and kernel.counters["kernel_ticks"] > 20, "Craft fallback and equipment reentry missing")
	check(oracle.failures.is_empty(), "Boundary graph capture failed")
	cases.append({"boundary_graph_ticks": 36, "counters": kernel.counters.duplicate(true)})


func _native_callback() -> void:
	var candidate: Dictionary = context("forge_completion")
	var control: Dictionary = context("forge_completion")
	var callbacks: Array[Callable] = []
	var mutations: Array[Dictionary] = []
	for item: Dictionary in [candidate, control]:
		var simulation: Simulation = item["simulation"]
		var state: GameState = simulation.state
		var id: String = state.relic_manager.add_random_relic_for_tier(2, 0.0, "output_increase")
		var observed: Dictionary = {"count": 0}
		mutations.append(observed)
		var callback: Callable = func(_amount: float) -> void:
			observed["count"] += 1
			state.relic_manager.equip_relic("atomic_friction", id, state)
			state.rebuild_relic_modifiers()
		callbacks.append(callback)
		simulation.crystallization_completed.connect(callback)
		simulation.critical_crystallization_completed.connect(callback)
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	var oracle: RefCounted = Oracle.new()
	for tick: int in range(3):
		kernel.run(1)
		control["simulation"].update(STEP, true)
		check(View.capture(candidate["simulation"], candidate["journal"], true) == View.capture(control["simulation"], control["journal"], true), "Native callback changed event order")
	for index: int in range(2):
		check(mutations[index]["count"] == 1, "Expected one native equipment mutation callback")
		var item: Dictionary = candidate if index == 0 else control
		item["simulation"].crystallization_completed.disconnect(callbacks[index])
		item["simulation"].critical_crystallization_completed.disconnect(callbacks[index])
	kernel.run(5)
	for tick: int in range(5):
		control["simulation"].update(STEP, true)
	check(kernel.counters["reasons"].get("external_observer", 0) == 3 and kernel.counters["kernel_ticks"] == 5, "Callback boundary/reentry not enforced")
	check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), "Callback reentry full graph differs")
	check(oracle.failures.is_empty(), "Callback graph failed")
	cases.append({"native_callback_ticks": 3, "reentry_ticks": 5, "counters": kernel.counters.duplicate(true)})


func _critical_witness() -> void:
	var candidate: Dictionary = context("forge_critical")
	var control: Dictionary = context("forge_critical")
	var state: GameState = candidate["simulation"].state
	var forge: Generator = state.get_generator("infernal_forge")
	check(not state.relic_manager.equip_relic(forge.definition.id, str(state.relic_manager.inventory[-1]["instance_id"]), state), "Native active-cycle equipment lock bypassed")
	var chance: float = candidate["simulation"]._get_effective_event_chance(forge, forge.event_effects.filter(func(effect: UpgradeEffect) -> bool: return effect.event_id == "forge_critical")[0], 0.25)
	check(chance > 0.25, "Native equipped critical effect not registered")
	var chosen: int = -1
	for seed_value: int in range(10000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var draw: float = preload("res://Game/gameplay_random.gd").sample_unit(rng)
		if draw >= 0.25 and draw < chance:
			chosen = seed_value
			break
	check(chosen >= 0, "No strict critical witness seed")
	for item: Dictionary in [candidate, control]:
		item["simulation"].state.gameplay_rng.seed = chosen
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	kernel.run(1)
	control["simulation"].update(STEP, true)
	check(View.capture(candidate["simulation"], candidate["journal"], true) == View.capture(control["simulation"], control["journal"], true), "Equipped critical RNG/order differs")
	check(candidate["journal"].events.any(func(event: Dictionary) -> bool: return event["event"] == "critical"), "Relic critical witness did not crit")
	var without: Dictionary = context("forge_critical")
	without["simulation"].state.relic_manager.unequip_relic("infernal_forge")
	without["simulation"].state.rebuild_relic_modifiers()
	without["simulation"].state.gameplay_rng.seed = chosen
	without["simulation"].update(STEP, true)
	check(without["journal"].events.any(func(event: Dictionary) -> bool: return event["event"] == "normal") and not without["journal"].events.any(func(event: Dictionary) -> bool: return event["event"] == "critical"), "Same native draw without equipped bonus must be ordinary")
	var oracle: RefCounted = Oracle.new()
	check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), "Critical full graph differs")
	check(oracle.failures.is_empty(), "Critical graph capture failed")
	cases.append({"critical_witness_seed": chosen, "native_chance": chance, "outcomes": candidate["journal"].events, "counterfactual_outcomes": without["journal"].events})


func _unsupported() -> void:
	for kind: String in ["modifier", "formula", "recipe_purchase"]:
		var item: Dictionary = context("one")
		var state: GameState = item["simulation"].state
		match kind:
			"modifier", "formula":
				var modifier: Modifier = state.get_generator("atomic_friction").modifiers.filter(func(value: Modifier) -> bool: return value.id.begins_with("relic:"))[0]
				if kind == "modifier":
					modifier.type = "unreviewed_relic_operation"
				else:
					modifier.dynamic = true
					modifier.dynamic_formula = "unreviewed_relic_formula"
			"recipe_purchase":
				Fixtures.Cycles.Automation.Buyers.enable(state, "atomic_friction")
				state.get_generator("atomic_friction").get_operation_mode().crafting_input_requirements.append({"item_type": "relic", "quantity": 1})
		var oracle: RefCounted = Oracle.new()
		var before: PackedByteArray = oracle.fingerprint(item["simulation"], item["journal"])
		var packet: RefCounted = Packet.new()
		check(not packet.build(item["simulation"], item["journal"]), "Unsupported boundary admitted: " + kind)
		check(before == oracle.fingerprint(item["simulation"], item["journal"]), "Rejected equipment admission mutated state")


func _save_load_boundary() -> void:
	var candidate: Dictionary = context("multiple")
	var control: Dictionary = context("multiple")
	var kernel: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	var oracle: RefCounted = Oracle.new()
	for item: Dictionary in [candidate, control]:
		var state: GameState = item["simulation"].state
		var save := SaveManager.new()
		var data: Dictionary = save.state_to_dictionary(state)
		check(save.dictionary_to_state(state, data, SaveManager.SAVE_VERSION), "Native equipment reload failed")
		item["simulation"].rebuild_upgrade_effects()
		state.rebuild_relic_modifiers()
	for tick: int in range(5):
		kernel.run(1)
		control["simulation"].update(STEP, true)
		check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), "Reloaded equipment references differ")
	check(oracle.failures.is_empty(), "Reloaded equipment graph failed")
	cases.append({"save_load_graph_ticks": 5, "counters": kernel.counters.duplicate(true)})
