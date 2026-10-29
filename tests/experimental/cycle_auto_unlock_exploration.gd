extends SceneTree

const Core = preload("res://tests/experimental/core_fixtures.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var state: GameState
var simulation: Simulation
var actions: Array[Dictionary] = []
var snapshots: Dictionary = {}
var failures: Array[String] = []
var tick: int = 0
var earned: bool = false
var completed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	state = Core.make_state("forge")
	simulation = Simulation.new(state)
	var prestige := PrestigeSystem.new()
	for index: int in range(600000):
		tick = index
		var before: float = state.resource_statistics.get_total_produced(ResourceIds.CRYSTALLIZED_FLAME)
		simulation.update(STEP, true)
		if earned and state.resource_statistics.get_total_produced(ResourceIds.CRYSTALLIZED_FLAME) > before:
			completed += 1
			if completed >= 2:
				snapshots["repeated"] = SaveManager.new().state_to_dictionary(state)
				break
		if index % 10 == 0:
			if not earned and prestige.calculate_eternal_flame_gain(state) >= maxf(1.0, minf(8.0, 30.0 - state.eternal_flame_state.eternal_flame)):
				var reward: float = prestige.smash(state, float(index + 1) * STEP)
				actions.append({"tick": tick, "action": "smash", "reward": reward})
				if state.eternal_flame_state.eternal_flame >= 30.0:
					if not state.eternal_flame_upgrade_manager.purchase("unlock_cycle_auto_run_infernal_forge", state.eternal_flame_state, state.realm_configuration):
						failures.append("Earned auto-run purchase failed")
						break
					actions.append({"tick": tick, "action": "permanent", "id": "unlock_cycle_auto_run_infernal_forge", "cost": 30})
					earned = true
				if not prestige.begin_next_realm(state):
					failures.append("Native realm reset failed")
					break
				simulation = Simulation.new(state)
				for manager: Variant in [state.generator_automation_manager, state.upgrade_automation_manager]:
					if not manager.set_enabled("atomic_friction", true):
						failures.append("Earned buyer not unlocked")
						break
					actions.append({"tick": tick, "action": "buyer", "upgrade": manager is UpgradeAutomationManager})
			_act()
		var forge: Generator = state.get_generator("infernal_forge")
		if earned and forge.cycle_active and not snapshots.has("auto_active"):
			snapshots["auto_active"] = SaveManager.new().state_to_dictionary(state)
		if earned and forge.cycle_active and forge.cycle_progress > forge.get_cycle_duration() - 0.2 and not snapshots.has("auto_near"):
			snapshots["auto_near"] = SaveManager.new().state_to_dictionary(state)
		if index % 20000 == 0:
			print("CYCLE_PROGRESSION tick=", tick, " earned=", earned, " CF=", state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME), " gain=", prestige.calculate_eternal_flame_gain(state), " level=", forge.level, " progress=", forge.cycle_progress)
	if snapshots.size() != 3:
		failures.append("Reached auto-run snapshots incomplete")
	var output := FileAccess.open("res://tests/experimental/cycle_auto_unlock_exploration.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"source": "core_progression.json forge; native legal continuation and paid 30-flame auto-run unlock", "ticks": tick + 1, "actions": actions, "completed_after_unlock": completed, "snapshots": snapshots, "failures": failures}, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("CYCLE_PROGRESSION failures=", failures.size())
	quit(0 if failures.is_empty() else 1)


func _act() -> void:
	for upgrade: Upgrade in state.upgrades.values():
		var definition: UpgradeDefinition = upgrade.definition
		if definition.automatic or definition.generator_id in ["thermal_compressor", "relic_shard_extractor"] or definition.id == "thermal_compressor_unlock":
			continue
		if state.upgrade_system.is_upgrade_visible(upgrade) and simulation.can_buy_upgrade(definition.id) and simulation.buy_upgrade(definition.id, "cycle_fixture_policy"):
			actions.append({"tick": tick, "action": "upgrade", "id": definition.id, "level": upgrade.level})
	for id: String in ["thermal_furnace", "matter_furnace"]:
		var paused: bool = id == "matter_furnace" or tick % 600 < 450
		if state.get_generator(id).manually_paused != paused:
			simulation.toggle_generator_pause(id)
			actions.append({"tick": tick, "action": "pause", "id": id, "paused": paused})
	var forge: Generator = state.get_generator("infernal_forge")
	if not forge.cycle_active:
		for mode: GeneratorOperationMode in forge.definition.operation_modes:
			if mode.id == "fast" and mode.unlocked:
				forge.set_operation_mode(mode.id)
	if earned and forge.unlocked and not forge.auto_run_cycles:
		if state.eternal_flame_state.is_technology_unlocked(EternalFlameState.get_cycle_auto_run_technology_id(forge.definition.id)):
			forge.auto_run_cycles = true
			actions.append({"tick": tick, "action": "enable_auto_run", "mode": forge.operation_mode_id})
	elif not earned and not forge.cycle_active and simulation.can_buy_generator("infernal_forge") and simulation.buy_generator("infernal_forge", "cycle_fixture_policy"):
		actions.append({"tick": tick, "action": "cycle", "level": forge.level, "mode": forge.operation_mode_id})
	var targets: Dictionary = {"atomic_friction": 60, "molecular_agitation": 60, "thermal_furnace": 50, "lava_mite_colony": 15}
	for id: String in targets:
		if state.get_generator(id).level < int(targets[id]) and simulation.can_buy_generator(id) and simulation.buy_generator(id, "cycle_fixture_policy"):
			actions.append({"tick": tick, "action": "generator", "id": id, "level": state.get_generator(id).level})
