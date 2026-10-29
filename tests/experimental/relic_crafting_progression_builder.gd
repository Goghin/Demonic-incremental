extends SceneTree

const Core = preload("res://tests/experimental/core_fixtures.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var state: GameState
var simulation: Simulation
var actions: Array[Dictionary] = []
var snapshots: Dictionary = {}
var failures: Array[String] = []
var tick: int = 0
var crafting_started: bool = false
var completed_crafts: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_early_access()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/automation_progression.json"))
	state = Core.from_save(source["snapshots"]["settled"])
	simulation = Simulation.new(state)
	for id: String in ["reliquary", "attunement_molecular_agitation", "attunement_lava_mite_colony"]:
		var cost: float = state.eternal_flame_upgrade_manager.get_upgrade_cost(id, state.eternal_flame_state)
		if not state.eternal_flame_upgrade_manager.purchase(id, state.eternal_flame_state, state.realm_configuration):
			failures.append("Native permanent purchase failed: " + id)
		state.rebuild_realm_effects()
		if id == "reliquary":
			state.relic_manager.ensure_starter_relic()
		state.rebuild_relic_modifiers()
		actions.append({"tick": tick, "action": "permanent_purchase", "id": id, "cost": cost})
	var starter: String = str(state.relic_manager.inventory[0]["instance_id"])
	if not state.relic_manager.equip_relic("atomic_friction", starter, state):
		failures.append("Native starter equip failed")
	state.rebuild_relic_modifiers()
	actions.append({"tick": 0, "action": "equip", "id": starter, "generator": "atomic_friction"})
	snapshots["accessible"] = SaveManager.new().state_to_dictionary(state)
	var crucible: Generator = state.get_generator("relic_shard_extractor")
	for index: int in range(180000):
		tick = index + 1
		simulation.update(STEP, true)
		if index % 10 == 0:
			_act()
		if crucible.cycle_active:
			if crucible.operation_mode_id == "normal" and crucible.cycle_progress >= 10.0 and not snapshots.has("extraction_active"):
				snapshots["extraction_active"] = SaveManager.new().state_to_dictionary(state)
			if crafting_started and crucible.get_cycle_duration() - crucible.cycle_progress < 0.2 and not snapshots.has("near_completion"):
				snapshots["near_completion"] = SaveManager.new().state_to_dictionary(state)
		if not crucible.cycle_active:
			if crucible.operation_mode_id == "forge_relic" and crafting_started:
				completed_crafts += 1
				actions.append({"tick": tick, "action": "random_craft_completed", "count": completed_crafts})
				if completed_crafts >= 2:
					snapshots["after_repeated"] = SaveManager.new().state_to_dictionary(state)
					break
				crafting_started = false
				crucible.set_operation_mode("normal")
			if state.relic_manager.get_stackable_item_quantity("relic_shard") >= 10:
				if not crucible.set_operation_mode("forge_relic"):
					failures.append("Native recipe mode selection failed")
				for entry: Dictionary in state.relic_manager.inventory:
					if str(entry.get("item_id", "")) == "relic_shard" and int(entry.get("quantity", 0)) >= 10:
						if state.relic_manager.get_machine_entry_at_slot(crucible.definition.id, 0).get("instance_id", "") != entry["instance_id"] and not state.relic_manager.move_inventory_entry_to_machine_slot(str(entry["instance_id"]), crucible.definition.id, 0):
							failures.append("Native ingredient move failed")
						break
			if simulation.can_buy_generator(crucible.definition.id) and simulation.buy_generator(crucible.definition.id, "earned_relic_policy"):
				crafting_started = crucible.operation_mode_id == "forge_relic"
				var label: String = ("first_craft" if completed_crafts == 0 else "repeat_craft") if crafting_started else "first_extraction"
				if not snapshots.has(label):
					snapshots[label] = SaveManager.new().state_to_dictionary(state)
				actions.append({"tick": tick, "action": "cycle", "mode": crucible.operation_mode_id})
		if not failures.is_empty():
			break
		if index % 30000 == 0:
			print("CRAFTING_PROGRESSION ", tick, " matter=", state.get_resource_amount(ResourceIds.MATTER), " shards=", state.relic_manager.get_stackable_item_quantity("relic_shard"), " inventory=", state.relic_manager.inventory.size())
	if not snapshots.has("after_repeated"):
		failures.append("No repeated earned crafting fixture within policy bound")
	var file := FileAccess.open("res://tests/experimental/relic_crafting_progression.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"source": "automation_progression.json settled; paid native slot purchases and UI-equivalent rebuild, free native Reliquary starter, native shard extraction/recipe/random crafting and equip APIs; no grants", "ticks": tick, "actions": actions, "snapshots": snapshots, "completed_crafts": completed_crafts, "failures": failures}, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("CRAFTING_PROGRESSION failures=", failures.size())
	quit(0 if failures.is_empty() else 1)


func _act() -> void:
	for id: String in ["thermal_furnace", "matter_furnace"]:
		var generator: Generator = state.get_generator(id)
		var paused: bool = id == "matter_furnace"
		if generator.manually_paused != paused:
			simulation.toggle_generator_pause(id)
			actions.append({"tick": tick, "action": "pause", "id": id, "paused": paused})
	for upgrade: Upgrade in state.upgrades.values():
		var definition: UpgradeDefinition = upgrade.definition
		if definition.automatic or definition.generator_id in ["thermal_compressor", "relic_shard_extractor"] or definition.id == "thermal_compressor_unlock":
			continue
		if state.upgrade_system.is_upgrade_visible(upgrade) and simulation.can_buy_upgrade(definition.id):
			if simulation.buy_upgrade(definition.id, "earned_relic_policy"):
				actions.append({"tick": tick, "action": "upgrade", "id": definition.id, "level": upgrade.level})
	var targets: Dictionary = {"atomic_friction": 60, "molecular_agitation": 60, "thermal_furnace": 50, "lava_mite_colony": 15}
	for id: String in targets:
		if state.get_generator(id).level < int(targets[id]) and simulation.can_buy_generator(id):
			if simulation.buy_generator(id, "earned_relic_policy"):
				actions.append({"tick": tick, "action": "generator", "id": id, "level": state.get_generator(id).level})


func _early_access() -> void:
	# First affordable step of the unchanged early save continuation; no
	# purchases/stock/technology grants precede this actual activation.
	var early: GameState = Core.make_state("early")
	var native := Simulation.new(early)
	for index: int in range(30000):
		if native.can_buy_generator("relic_shard_extractor"):
			snapshots["first_affordable"] = SaveManager.new().state_to_dictionary(early)
			if not native.buy_generator("relic_shard_extractor", "early_crucible_access"):
				failures.append("Early affordable native activation failed")
			snapshots["first_activated"] = SaveManager.new().state_to_dictionary(early)
			actions.append({"branch": "core_early_continuation", "tick": index, "action": "first_affordable_activation"})
			return
		native.update(STEP, true)
	failures.append("Early native continuation did not reach activation cost")
