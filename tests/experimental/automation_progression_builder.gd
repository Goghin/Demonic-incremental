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
	var prestige := PrestigeSystem.new()
	var snapshots: Dictionary = {}
	for index: int in range(300000):
		tick = index
		simulation.update(STEP, true)
		if index % 10 == 0:
			var target: float = 15.0 - state.eternal_flame_state.eternal_flame
			if prestige.calculate_eternal_flame_gain(state) >= target:
				var reward: float = prestige.smash(state, float(index + 1) * STEP)
				actions.append({"tick": index, "action": "smash", "reward": reward})
				if reward <= 0.0 or not prestige.begin_next_realm(state):
					failures.append("Legitimate prestige failed")
					break
				simulation = Simulation.new(state)
				for manager: Variant in [state.generator_automation_manager, state.upgrade_automation_manager]:
					if not manager.set_enabled("atomic_friction", true):
						failures.append("Earned automation unlock absent")
					actions.append({"tick": index, "action": "enable", "id": "atomic_friction", "upgrade_buyer": manager is UpgradeAutomationManager})
				# A legal heat-saving phase of the same player policy as the
				# source ledger. Mites and both buyers remain enabled/active.
				if not state.get_generator("thermal_furnace").manually_paused:
					simulation.toggle_generator_pause("thermal_furnace")
					actions.append({"tick": index, "action": "pause", "id": "thermal_furnace", "paused": true})
				snapshots["entry"] = SaveManager.new().state_to_dictionary(state)
				for extra: int in range(2000):
					simulation.update(STEP, true)
				snapshots["settled"] = SaveManager.new().state_to_dictionary(state)
				break
			_act()
		if index % 10000 == 0:
			print("AUTOMATION_PROGRESSION ", index, " CF=", state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME), " forge=", state.get_generator("infernal_forge").cycle_progress, " gain=", prestige.calculate_eternal_flame_gain(state))
	if snapshots.size() != 2:
		failures.append("No reached upgrade-automation fixture within bound")
	var output := FileAccess.open("res://tests/experimental/automation_progression.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"source": "core_progression.json forge save; legal native continuation, no grants/ablations", "ticks": tick + 1, "actions": actions, "snapshots": snapshots, "failures": failures}, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("AUTOMATION_PROGRESSION failures=" + str(failures.size()))
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
