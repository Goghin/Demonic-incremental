extends SceneTree

const Core = preload("res://tests/experimental/core_fixtures.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var actions: Array[Dictionary] = []
var snapshots: Dictionary = {}
var state: GameState
var simulation: Simulation
var failures: Array[String] = []
var tick: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/automation_progression.json"))
	state = Core.from_save(manifest["snapshots"]["settled"])
	simulation = Simulation.new(state)
	for id: String in ["essence_extraction", "thermal_compressor_technology"]:
		if not state.eternal_flame_upgrade_manager.purchase(id, state.eternal_flame_state, state.realm_configuration):
			failures.append("Earned technology purchase failed: " + id)
		actions.append({"tick": 0, "action": "permanent_purchase", "id": id})
	# Match prestige-panel purchase handling before any simulation update.
	state.rebuild_realm_effects()
	var exploration: bool = OS.get_environment("RESOURCE_PROGRESS_EXPLORE") == "1"
	for index: int in range(400000 if exploration else 160000):
		tick = index
		simulation.update(STEP, true)
		if index % 10 == 0:
			_act()
		if state.get_resource_amount(ResourceIds.ESSENCE) > 1.0 and not snapshots.has("essence"):
			snapshots["essence"] = SaveManager.new().state_to_dictionary(state)
		var compressor: Generator = state.get_generator("thermal_compressor")
		if compressor.level > 0 and state.get_resource_amount(ResourceIds.ESSENCE) >= 100.0 and not snapshots.has("compression"):
			snapshots["compression"] = SaveManager.new().state_to_dictionary(state)
		if state.get_resource_amount(ResourceIds.NEXUM) >= 1.0:
			snapshots["nexum"] = SaveManager.new().state_to_dictionary(state)
			if not compressor.set_operation_mode("expansion"):
				failures.append("Reached mode change failed")
			actions.append({"tick": tick, "action": "mode", "id": "thermal_compressor", "mode": "expansion"})
			snapshots["expansion"] = SaveManager.new().state_to_dictionary(state)
			break
		if index % 50000 == 0:
			print("RESOURCE_PROGRESSION ", tick, " essence=", state.get_resource_amount(ResourceIds.ESSENCE), " matter=", state.get_resource_amount(ResourceIds.MATTER), " compressor=", compressor.level)
	snapshots["feedback"] = SaveManager.new().state_to_dictionary(state)
	if not snapshots.has("essence"):
		failures.append("No reached Essence fixture within policy bound")
	var output := FileAccess.open("res://tests/experimental/essence_nexum_exploration.json" if exploration else "res://tests/experimental/essence_nexum_progression.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"source": "automation_progression.json settled; native paid technologies, purchases and mode/pause actions only; no grants", "ticks": tick + 1, "unreached_goals": [] if snapshots.has("expansion") else ["compression", "nexum", "expansion"], "final_resources": {"matter": state.get_resource_amount(ResourceIds.MATTER), "essence": state.get_resource_amount(ResourceIds.ESSENCE), "nexum": state.get_resource_amount(ResourceIds.NEXUM)}, "actions": actions, "snapshots": snapshots, "failures": failures}, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("RESOURCE_PROGRESSION failures=", failures.size())
	quit(0 if failures.is_empty() else 1)


func _act() -> void:
	for id: String in ["thermal_furnace", "matter_furnace"]:
		var generator: Generator = state.get_generator(id)
		# Native player policy: conserve Matter, keep Ash production available.
		var paused: bool = id == "matter_furnace"
		if generator.manually_paused != paused:
			simulation.toggle_generator_pause(id)
			actions.append({"tick": tick, "action": "pause", "id": id, "paused": paused})
	for upgrade: Upgrade in state.upgrades.values():
		var definition: UpgradeDefinition = upgrade.definition
		if definition.automatic or definition.generator_id == "relic_shard_extractor":
			continue
		if state.upgrade_system.is_upgrade_visible(upgrade) and simulation.can_buy_upgrade(definition.id):
			if simulation.buy_upgrade(definition.id, "resource_fixture_policy"):
				actions.append({"tick": tick, "action": "upgrade", "id": definition.id, "level": upgrade.level})
	var targets: Dictionary = {"atomic_friction": 90, "molecular_agitation": 80, "thermal_furnace": 50, "lava_mite_colony": 30, "thermal_compressor": 1}
	for id: String in targets:
		if state.get_generator(id).level < int(targets[id]) and simulation.can_buy_generator(id):
			if simulation.buy_generator(id, "resource_fixture_policy"):
				actions.append({"tick": tick, "action": "generator", "id": id, "level": state.get_generator(id).level})
