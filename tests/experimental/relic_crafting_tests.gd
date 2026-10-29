extends RefCounted

const Fixtures = preload("res://tests/experimental/relic_crafting_fixtures.gd")
const Kernel = preload("res://tests/experimental/exact_flow_kernel.gd")
const Packet = preload("res://tests/experimental/exact_flow_packet.gd")
const Previous = preload("res://tests/experimental/baselines/exact_flow_182e562_kernel.gd")
const View = preload("res://tests/experimental/exact_flow_view.gd")
const Oracle = preload("res://tests/experimental/transaction_tests.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var failures: Array[String] = []
var cases: Array[Dictionary] = []

class UnknownRng extends RandomNumberGenerator:
	pass


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
	var focused: String = OS.get_environment("CRAFT_TEST_LABEL")
	if focused == "boundaries":
		_boundaries()
		_external_callback()
		_equipment_locks()
		_startup_and_aliases()
		_instrumentation()
		_unsupported()
		return {"cases": cases, "failures": failures}
	if focused != "":
		_differential(focused, 3000 if focused.begins_with("auto_") else 2000)
		return {"cases": cases, "failures": failures}
	for label: String in Fixtures.DIAGNOSTICS:
		_differential(label, 3000 if label.begins_with("auto_") else (2000 if label in ["forge_standard", "critical_standard", "forge_greater", "critical_greater", "essence", "nexum"] else 1000))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/relic_crafting_progression.json"))
	check(data["failures"].is_empty() and data["completed_crafts"] >= 2, "Earned fixture policy failed")
	for label: String in data["snapshots"]:
		_differential("earned_craft_" + label, 2000)
	_boundaries()
	_external_callback()
	_equipment_locks()
	_startup_and_aliases()
	_instrumentation()
	_unsupported()
	return {"cases": cases, "failures": failures}


func run_regression() -> Dictionary:
	# Fast representative group; run_all retains the full long differential
	# matrix separately. Neither mode relaxes any equality assertion.
	for scenario: Array in [["critical_greater", 2000], ["auto_standard", 3000], ["forge_together", 100], ["earned_craft_near_completion", 20]]:
		_differential(scenario[0], scenario[1])
	_boundaries()
	_external_callback()
	_equipment_locks()
	_startup_and_aliases()
	_instrumentation()
	_unsupported()
	return {"cases": cases, "failures": failures}


func _differential(label: String, ticks: int) -> void:
	print("CRAFT_DIFFERENTIAL ", label, " ", ticks)
	var candidate: Dictionary = context(label)
	var control: Dictionary = context(label)
	var previous: Dictionary = context(label)
	var oracle: RefCounted = Oracle.new()
	var before: PackedByteArray = oracle.fingerprint(candidate["simulation"], candidate["journal"])
	var packet: RefCounted = Packet.new()
	check(packet.build(candidate["simulation"], candidate["journal"]), label + ": admission " + packet.error)
	check(before == oracle.fingerprint(candidate["simulation"], candidate["journal"]), label + ": build mutated graph")
	packet = null
	var initial_ids: Array = candidate["simulation"].state.relic_manager.inventory.map(func(entry: Dictionary) -> String: return str(entry["instance_id"]))
	var runner: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	runner.detailed_trace = true
	runner.run(ticks, true)
	var old: RefCounted = Previous.new(previous["simulation"], previous["journal"])
	old.detailed_trace = true
	old.run(ticks, true)
	var compared: int = 0
	for tick: int in range(ticks):
		control["simulation"].update(STEP, true)
		var expected: PackedByteArray = View.capture(control["simulation"], control["journal"], true)
		if runner.trace[tick] != expected or old.trace[tick] != expected:
			check(false, label + ": first divergent tick " + str(tick + 1))
			break
		compared += 1
	check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), label + ": full graph differs")
	check(oracle.failures.is_empty(), label + ": original graph capture failed")
	check(runner.counters["kernel_ticks"] > 0 and runner.counters["reasons"].is_empty(), label + ": no supported execution")
	var rewards: Array[Dictionary] = []
	for entry: Dictionary in candidate["simulation"].state.relic_manager.inventory:
		if entry.get("instance_id", "") not in initial_ids and entry.has("generated_definition"):
			rewards.append(entry.duplicate(true))
	if label in ["forge_standard", "critical_standard", "forge_greater", "critical_greater", "auto_standard", "full_inventory", "forge_together", "separate_rng"]:
		check(not rewards.is_empty(), label + ": no native random reward")
	if label.begins_with("critical_"):
		check(not rewards.is_empty() and rewards[0].get("critical_craft", false), label + ": critical witness failed")
	if label == "critical_greater":
		check(rewards[0].has("secondary_stat") and rewards[0].has("additional_secondary_stats"), "Promoted Rare must retain both rolled bonuses")
	if label == "forge_standard":
		check(not rewards.is_empty() and not rewards[0].get("critical_craft", false), "Noncritical witness failed")
	if label == "auto_standard":
		check(rewards.size() >= 3, "Repeated native auto crafts missing")
	if label == "automation":
		check(candidate["simulation"].state.get_generator("atomic_friction").level > 10 and candidate["simulation"].state.get_upgrade("atomic_friction_optimization").level > 0, "Native generator/upgrade purchases during crafting missing")
	if label == "full_inventory":
		check(candidate["simulation"].state.relic_manager.get_inventory_slot_count() > 24, "Native inventory growth missing")
	if label == "stack_overflow":
		check(candidate["simulation"].state.relic_manager.get_stackable_item_quantity("relic_shard") == 1002, "Native stack merge/split missing")
	if label in ["forge_together", "separate_rng"]:
		var events: Array = candidate["journal"].events
		var first_forge: int = -1
		var first_relic: int = -1
		for index: int in range(events.size()):
			if events[index]["event"] in ["normal", "critical"] and first_forge < 0:
				first_forge = index
			if events[index]["event"] == "relic" and first_relic < 0:
				first_relic = index
		check(first_forge >= 0 and first_relic > first_forge, "Forge/Crucible completion order missing")
	var sequences: Array[bool] = []
	for field: String in ["gameplay_rng", "crafting_rng"]:
		var a: RandomNumberGenerator = candidate["simulation"].state.gameplay_rng if field == "gameplay_rng" else candidate["simulation"].state.relic_manager._gameplay_rng
		var b: RandomNumberGenerator = control["simulation"].state.gameplay_rng if field == "gameplay_rng" else control["simulation"].state.relic_manager._gameplay_rng
		var left := RandomNumberGenerator.new()
		var right := RandomNumberGenerator.new()
		left.seed = a.seed
		left.state = a.state
		right.seed = b.seed
		right.state = b.state
		var equal: bool = true
		for draw: int in range(128):
			equal = equal and left.randi() == right.randi()
		check(equal, label + ": follow-on RNG sequence differs: " + field)
		sequences.append(equal)
	cases.append({"label": label, "ticks": ticks, "compared_ticks": compared, "rewards": rewards, "counters": runner.counters.duplicate(true), "follow_on_rng_parity": sequences})


func _boundaries() -> void:
	var candidate: Dictionary = context("starved")
	var control: Dictionary = context("starved")
	var runner: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	var oracle: RefCounted = Oracle.new()
	for action: String in ["starve", "recover", "pause", "unpause", "reload", "finish", "recipe", "level", "move_leftover", "autorestart", "disable", "finish_again", "refill", "recovery", "reenter"]:
		for item: Dictionary in [candidate, control]:
			var state: GameState = item["simulation"].state
			var simulation: Simulation = item["simulation"]
			var generator: Generator = state.get_generator(Fixtures.ID)
			match action:
				"recover": state.set_resource_amount(ResourceIds.MATTER, 500.0)
				"pause": simulation.toggle_generator_pause(Fixtures.ID)
				"unpause": simulation.toggle_generator_pause(Fixtures.ID)
				"reload":
					var save := SaveManager.new()
					check(save.dictionary_to_state(state, save.state_to_dictionary(state), SaveManager.SAVE_VERSION), "Active craft reload failed")
					simulation.rebuild_upgrade_effects()
				"finish", "finish_again":
					if generator.cycle_active:
						generator.cycle_progress = generator.get_cycle_duration() - 0.000001
				"recipe":
					check(generator.set_operation_mode("forge_relic"), "Recipe mode locked after completion")
					Fixtures.ingredient(state, "relic_shard", 20)
					check(simulation.buy_generator(Fixtures.ID, "crafting_boundary"), "Recipe startup failed")
					check(generator.cycle_critical_chance_snapshot == 0.05, "Native critical snapshot missing")
				"level":
					state.set_resource_amount(ResourceIds.MATTER, 500.0)
					check(simulation.buy_generator_level(Fixtures.ID, "crafting_boundary"), "Native active level purchase failed")
					check(generator.cycle_critical_chance_snapshot == 0.05, "Active level purchase changed snapshot")
					check(not generator.set_operation_mode("normal"), "Native mode lock bypassed")
					check(not state.relic_manager.equip_relic(Fixtures.ID, str(state.relic_manager.inventory[0]["instance_id"]), state), "Native Crucible equipment rejection bypassed")
				"move_leftover":
					check(state.relic_manager.move_machine_entry_to_inventory(Fixtures.ID, 0), "Native active ingredient return failed")
					check(generator.cycle_critical_chance_snapshot == 0.05, "Ingredient transfer changed active snapshot")
				"autorestart":
					Fixtures.enable_auto(state)
					generator.cycle_progress = generator.get_cycle_duration() - 0.000001
				"disable": generator.auto_run_cycles = false
				"refill":
					Fixtures.ingredient(state, "relic_shard", 10)
					state.set_resource_amount(ResourceIds.MATTER, 0.0)
					Fixtures.enable_auto(state)
				"recovery": state.set_resource_amount(ResourceIds.MATTER, 100.0)
		for tick: int in range(3):
			runner.run(1)
			control["simulation"].update(STEP, true)
			check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), "Boundary full graph differs: " + action)
	check(oracle.failures.is_empty(), "Boundary graph capture failed")
	check(runner.counters["reasons"].is_empty(), "Boundary unexpectedly fell back")
	cases.append({"boundary_graph_ticks": 45, "counters": runner.counters.duplicate(true)})


func _external_callback() -> void:
	var candidate: Dictionary = context("forge_standard")
	var control: Dictionary = context("forge_standard")
	var callbacks: Array[Callable] = []
	var calls: Array[Dictionary] = []
	for item: Dictionary in [candidate, control]:
		var state: GameState = item["simulation"].state
		state.get_generator(Fixtures.ID).cycle_progress = 90.0 - 0.000001
		Fixtures.ingredient(state, "relic_shard", 20)
		Fixtures.enable_auto(state)
		var simulation: Simulation = item["simulation"]
		var count: Dictionary = {"count": 0}
		calls.append(count)
		var callback: Callable = func(_name: String, _quantity: int, _critical: bool) -> void:
			count["count"] += 1
			var id: String = str(state.relic_manager.inventory[-1]["instance_id"])
			state.relic_manager.equip_relic("atomic_friction", id, state)
			state.rebuild_relic_modifiers()
			check(simulation.buy_generator_level(Fixtures.ID, "native_craft_callback"), "Native completion-level purchase failed")
		callbacks.append(callback)
		item["simulation"].relic_crafting_completed.connect(callback)
	var runner: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	for tick: int in range(3):
		runner.run(1)
		control["simulation"].update(STEP, true)
		check(View.capture(candidate["simulation"], candidate["journal"], true) == View.capture(control["simulation"], control["journal"], true), "External craft callback order differs")
	for index: int in range(2):
		var item: Dictionary = candidate if index == 0 else control
		check(calls[index]["count"] == 1, "Native crafting callback missing")
		item["simulation"].relic_crafting_completed.disconnect(callbacks[index])
	runner.run(5)
	for tick: int in range(5):
		control["simulation"].update(STEP, true)
	var oracle: RefCounted = Oracle.new()
	check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), "Craft callback reentry graph differs")
	check(oracle.failures.is_empty(), "Craft callback graph failed")
	check(runner.counters["reasons"].get("external_observer", 0) == 3 and runner.counters["kernel_ticks"] == 5, "Native observer fallback/reentry missing")
	cases.append({"callback_ticks": 3, "reentry_ticks": 5, "counters": runner.counters.duplicate(true)})


func _unsupported() -> void:
	for kind: String in ["rng", "event", "transfer", "metadata"]:
		var item: Dictionary = context("forge_standard")
		var state: GameState = item["simulation"].state
		var generator: Generator = state.get_generator(Fixtures.ID)
		match kind:
			"rng": state.relic_manager._gameplay_rng = UnknownRng.new()
			"metadata": generator.get_operation_mode().completion_item_outputs.append({"item_id": Modifier.new(ModifierTypes.PRODUCTION, "", 1.0), "quantity": 1})
			"event":
				var effect := UpgradeEffect.new("diagnostic", Fixtures.ID)
				effect.event_action = "unreviewed_inventory_effect"
				generator.event_effects.append(effect)
			"transfer": generator.get_operation_mode().is_resource_transfer = true
		var oracle: RefCounted = Oracle.new()
		var before: PackedByteArray = oracle.fingerprint(item["simulation"], item["journal"])
		var packet: RefCounted = Packet.new()
		check(not packet.build(item["simulation"], item["journal"]), "Unreviewed crafting state admitted: " + kind)
		check(before == oracle.fingerprint(item["simulation"], item["journal"]), "Rejected crafting build mutated state")
		check(oracle.failures.is_empty(), "Unsupported crafting admission graph failed: " + kind)


func _equipment_locks() -> void:
	var candidate: Dictionary = context("forge_together")
	var control: Dictionary = context("forge_together")
	var slot: RelicSlotControl = preload("res://UI/relic_slot_control.gd").new()
	for item: Dictionary in [candidate, control]:
		slot.state = item["simulation"].state
		slot.slot_kind = "generator"
		for id: String in [Fixtures.ID, "infernal_forge"]:
			slot.generator_id = id
			check(slot._is_generator_equipment_locked(), "Native active slot lock missing: " + id)
			check(slot._get_drag_data(Vector2.ZERO) == null, "Native active equipment drag accepted")
			check(not slot._can_drop_data(Vector2.ZERO, {"type": "reliquary_item"}), "Native active equipment drop accepted")
	var runner: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
	runner.run(1)
	control["simulation"].update(STEP, true)
	for item: Dictionary in [candidate, control]:
		slot.state = item["simulation"].state
		for id: String in [Fixtures.ID, "infernal_forge"]:
			slot.generator_id = id
			check(not slot._is_generator_equipment_locked(), "Native slot lock did not clear after completion")
		var state: GameState = item["simulation"].state
		check(state.relic_manager.equip_relic("infernal_forge", str(state.relic_manager.inventory[-1]["instance_id"]), state), "Native completed Forge did not allow new equipment")
		state.rebuild_relic_modifiers()
	slot.free()
	runner.run(5)
	for tick: int in range(5):
		control["simulation"].update(STEP, true)
	var oracle: RefCounted = Oracle.new()
	check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), "Native lock/equip boundary graph differs")
	check(oracle.failures.is_empty(), "Lock graph capture failed")
	cases.append({"equipment_lock_ticks": 6, "counters": runner.counters.duplicate(true)})


func _startup_and_aliases() -> void:
	for alias: bool in [false, true]:
		var candidate: Dictionary = context("idle")
		var control: Dictionary = context("idle")
		for item: Dictionary in [candidate, control]:
			var simulation: Simulation = item["simulation"]
			var state: GameState = simulation.state
			var generator: Generator = state.get_generator(Fixtures.ID)
			if alias:
				check(generator.set_operation_mode("recycle_relic"), "Alias recipe mode unavailable")
				var equipped: String = state.relic_manager.get_equipped_relic_id("atomic_friction")
				check(not state.relic_manager.move_inventory_entry_to_machine_slot(equipped, Fixtures.ID, 0), "Native equipped ingredient move unexpectedly accepted")
				var id: String = state.relic_manager.add_random_relic_for_tier(1)
				check(state.relic_manager.move_inventory_entry_to_machine_slot(id, Fixtures.ID, 0), "Native ingredient move failed")
				# Existing low-level APIs allow equip after machine insertion.
				# Preserve its alias semantics; this is not a UI/earned fixture.
				check(state.relic_manager.equip_relic("atomic_friction", id, state), "Native low-level alias setup failed")
				state.rebuild_relic_modifiers()
			else:
				check(generator.set_operation_mode("forge_relic"), "Native recipe mode unavailable")
				Fixtures.ingredient(state, "relic_shard", 10)
			state.set_resource_amount(ResourceIds.MATTER, 0.0)
			var before: PackedByteArray = var_to_bytes(state.relic_manager.get_save_data())
			check(not simulation.buy_generator(Fixtures.ID, "crafting_startup"), "Unaffordable craft started")
			check(before == var_to_bytes(state.relic_manager.get_save_data()), "Failed startup spent ingredients")
			state.set_resource_amount(ResourceIds.MATTER, 100.0)
			check(simulation.buy_generator(Fixtures.ID, "crafting_startup"), "Funded craft did not start")
			check(not simulation.buy_generator(Fixtures.ID, "crafting_startup"), "Active craft started twice")
		var runner: RefCounted = Kernel.new(candidate["simulation"], candidate["journal"])
		runner.detailed_trace = true
		runner.run(1000, true)
		for tick: int in range(1000):
			control["simulation"].update(STEP, true)
			check(runner.trace[tick] == View.capture(control["simulation"], control["journal"], true), "Startup/alias tick differs: " + str(alias))
		for item: Dictionary in [candidate, control]:
			item["simulation"].state.rebuild_relic_modifiers()
		runner.run(5)
		for tick: int in range(5):
			control["simulation"].update(STEP, true)
		var oracle: RefCounted = Oracle.new()
		check(oracle.fingerprint(candidate["simulation"], candidate["journal"]) == oracle.fingerprint(control["simulation"], control["journal"]), "Native startup/alias graph differs")
		check(oracle.failures.is_empty(), "Startup/alias graph capture failed")
		cases.append({"low_level_alias": alias, "startup_tick_comparisons": 1000, "rebuild_ticks": 5, "counters": runner.counters.duplicate(true)})


func _instrumentation() -> void:
	var candidate: Dictionary = context("auto_standard")
	var control: Dictionary = context("auto_standard")
	var original_inventory: Array = candidate["simulation"].state.relic_manager.inventory
	var original_rng: RandomNumberGenerator = candidate["simulation"].state.relic_manager._gameplay_rng
	candidate["simulation"] = preload("res://tests/experimental/crafting_native_probe.gd").new(candidate["simulation"].state)
	candidate["journal"] = Events.new()
	candidate["journal"].attach(candidate["simulation"])
	check(is_same(original_inventory, candidate["simulation"].state.relic_manager.inventory) and is_same(original_rng, candidate["simulation"].state.relic_manager._gameplay_rng), "Probe changed inventory/RNG identity")
	for tick: int in range(3000):
		candidate["simulation"].update(STEP, true)
		control["simulation"].update(STEP, true)
		check(View.capture(candidate["simulation"], candidate["journal"], true) == View.capture(control["simulation"], control["journal"], true), "Inventory profiler changed native gameplay")
	var packet: RefCounted = Packet.new()
	check(not packet.build(candidate["simulation"], candidate["journal"]), "Intrusive profiler admitted")
	cases.append({"instrumentation_tick_comparisons": 3000, "metrics": candidate["simulation"].metrics.duplicate(true), "inventory_timings": candidate["simulation"].state.relic_manager.timings.duplicate(true), "generation_timings": candidate["simulation"].state.relic_manager.generation_manager.timings.duplicate(true)})
