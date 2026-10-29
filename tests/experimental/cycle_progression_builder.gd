extends SceneTree

const Core = preload("res://tests/experimental/core_fixtures.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var actions: Array[Dictionary] = []
var failures: Array[String] = []
var state: GameState
var simulation: Simulation
var tick: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	state = Core.make_state("forge")
	simulation = Simulation.new(state)
	var snapshots: Dictionary = {}
	var completed: int = 0
	for index: int in range(100000):
		tick = index
		var before: float = state.resource_statistics.get_total_produced(ResourceIds.CRYSTALLIZED_FLAME)
		simulation.update(STEP, true)
		if state.resource_statistics.get_total_produced(ResourceIds.CRYSTALLIZED_FLAME) > before:
			completed += 1
			if completed >= 2:
				snapshots["repeated"] = SaveManager.new().state_to_dictionary(state)
				break
		if index % 10 == 0:
			_act()
		var forge: Generator = state.get_generator("infernal_forge")
		if completed >= 1 and forge.cycle_active and not snapshots.has("manual_active"):
			snapshots["manual_active"] = SaveManager.new().state_to_dictionary(state)
		if forge.cycle_active and forge.cycle_progress > forge.get_cycle_duration() - 0.2 and not snapshots.has("manual_near"):
			snapshots["manual_near"] = SaveManager.new().state_to_dictionary(state)
		if index % 10000 == 0:
			print("CYCLE_PROGRESSION ", tick, " completed=", completed, " progress=", forge.cycle_progress)
	if snapshots.size() != 3:
		failures.append("Reached manual cycle snapshots incomplete")
	var output := FileAccess.open("res://tests/experimental/cycle_progression.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"source": "core_progression.json forge save; unchanged automation-milestone manual policy before prestige, no grants/ablations", "ticks": tick + 1, "completed": completed, "actions": actions, "snapshots": snapshots, "failures": failures}, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("CYCLE_PROGRESSION failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)


func _act() -> void:
	for upgrade: Upgrade in state.upgrades.values():
		var definition: UpgradeDefinition = upgrade.definition
		if definition.automatic or definition.generator_id in ["thermal_compressor", "relic_shard_extractor"] or definition.id == "thermal_compressor_unlock":
			continue
		if state.upgrade_system.is_upgrade_visible(upgrade) and simulation.can_buy_upgrade(definition.id):
			if simulation.buy_upgrade(definition.id, "automation_fixture_policy"):
				actions.append({"tick": tick, "action": "upgrade", "id": definition.id, "level": upgrade.level})
	for id: String in ["thermal_furnace", "matter_furnace"]:
		var generator: Generator = state.get_generator(id)
		var paused: bool = id == "matter_furnace"
		if generator.manually_paused != paused:
			simulation.toggle_generator_pause(id)
			actions.append({"tick": tick, "action": "pause", "id": id, "paused": paused})
	var forge: Generator = state.get_generator("infernal_forge")
	if not forge.cycle_active and simulation.can_buy_generator("infernal_forge"):
		if simulation.buy_generator("infernal_forge", "automation_fixture_policy"):
			actions.append({"tick": tick, "action": "cycle", "id": "infernal_forge", "level": forge.level})
	var targets: Dictionary = {"atomic_friction": 60, "molecular_agitation": 60, "thermal_furnace": 50, "lava_mite_colony": 15}
	for id: String in targets:
		if state.get_generator(id).level < int(targets[id]) and simulation.can_buy_generator(id):
			if simulation.buy_generator(id, "automation_fixture_policy"):
				actions.append({"tick": tick, "action": "generator", "id": id, "level": state.get_generator(id).level})
