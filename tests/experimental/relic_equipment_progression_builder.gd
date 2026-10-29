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


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	snapshots["one"] = SaveManager.new().state_to_dictionary(state)
	var crucible: Generator = state.get_generator("relic_shard_extractor")
	for index: int in range(180000):
		tick = index + 1
		simulation.update(STEP, true)
		if index % 10 == 0:
			_act()
		if not crucible.cycle_active:
			if crucible.operation_mode_id == "forge_relic" and crafting_started:
				for entry: Dictionary in state.relic_manager.inventory:
					var instance_id: String = str(entry.get("instance_id", ""))
					if instance_id == starter or state.relic_manager.get_inventory_entry_type(entry) != "relic":
						continue
					for holder: String in ["molecular_agitation", "lava_mite_colony"]:
						if state.relic_manager.get_equipped_relic_id(holder) != "":
							continue
						if state.relic_manager.get_effect_status(instance_id, holder, state) == "Active" and state.relic_manager.equip_relic(holder, instance_id, state):
							state.rebuild_relic_modifiers()
							actions.append({"tick": tick, "action": "equip", "id": instance_id, "generator": holder})
							snapshots["multiple"] = SaveManager.new().state_to_dictionary(state)
							break
					if snapshots.has("multiple"):
						break
				if snapshots.has("multiple"):
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
				actions.append({"tick": tick, "action": "cycle", "mode": crucible.operation_mode_id})
		if not failures.is_empty():
			break
		if index % 30000 == 0:
			print("RELIC_PROGRESSION ", tick, " matter=", state.get_resource_amount(ResourceIds.MATTER), " shards=", state.relic_manager.get_stackable_item_quantity("relic_shard"), " inventory=", state.relic_manager.inventory.size())
	if not snapshots.has("multiple"):
		failures.append("No multiple active earned equipment fixture within policy bound")
	var file := FileAccess.open("res://tests/experimental/relic_equipment_progression.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"source": "automation_progression.json settled; paid native slot purchases and UI-equivalent rebuild, free native Reliquary starter, native shard extraction/recipe/random crafting and equip APIs; no grants", "ticks": tick, "actions": actions, "snapshots": snapshots, "failures": failures}, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("RELIC_PROGRESSION failures=", failures.size())
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
