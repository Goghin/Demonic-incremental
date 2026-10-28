extends SceneTree

# Deterministic player policy, not a simulator optimization. Every resource is
# earned by authoritative reference ticks. Every purchase uses real visibility,
# requirements, exclusivity, costs and unlock effects. No technology grants.
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
const Save = preload("res://Game/save_manager.gd")
const Logs = preload("res://tests/experimental/autobuyer_fixtures.gd")
var state: GameState
var simulation: Simulation
var tick: int = 0
var actions: Array[Dictionary] = []
var snapshots: Dictionary = {}
var max_ticks: int = 3000000
var targets: Dictionary = {"atomic_friction": 60, "molecular_agitation": 45, "thermal_furnace": 30, "lava_mite_colony": 5, "matter_furnace": 1}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	state = GameState.new()
	state.gameplay_rng.seed = 27481
	state.gameplay_log = Logs.TickLog.new()
	state.gameplay_log.clock = func() -> float: return float(tick) * STEP
	simulation = Simulation.new(state)
	for index: int in range(max_ticks):
		tick = index
		simulation.update(STEP, true)
		if index % 10 == 0:
			_act()
		if not snapshots.has("early") and state.get_resource_amount(ResourceIds.MATTER) > 5.0 and state.get_generator("molecular_agitation").level >= 25:
			_capture("early")
		if not snapshots.has("mid") and state.generator_automation_manager.is_enabled("atomic_friction") and state.get_generator("lava_mite_colony").level >= 5 and not state.get_generator("infernal_forge").cycle_active:
			_capture("mid")
		if not snapshots.has("forge") and snapshots.has("mid") and state.get_generator("infernal_forge").cycle_active:
			_capture("forge")
		if index % 10000 == 0:
			print("PROGRESSION " + JSON.stringify(_summary()), " actions=", actions.size())
		if snapshots.size() == 3:
			break
	var result: Dictionary = {"seed": 27481, "step": STEP, "targets": targets, "ticks": tick, "actions": actions, "snapshots": snapshots, "summary": _summary()}
	var file: FileAccess = FileAccess.open("res://tests/experimental/core_progression.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	print("PROGRESSION_DONE " + JSON.stringify(_summary()))
	quit(0 if snapshots.size() == 3 else 1)


func _act() -> void:
	# After earning a CF, finish this realm through the actual Smash API.
	if state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME) >= 1.0 and not snapshots.has("mid"):
		var prestige := PrestigeSystem.new()
		var reward: float = prestige.smash(state, float(tick) * STEP)
		if reward > 0.0:
			actions.append({"tick": tick, "action": "smash", "reward": reward})
			prestige.begin_next_realm(state)
			simulation = Simulation.new(state)
			return
	if state.generator_automation_manager.is_automation_unlocked("atomic_friction") and not state.generator_automation_manager.is_enabled("atomic_friction"):
		if state.generator_automation_manager.set_enabled("atomic_friction", true):
			actions.append({"tick": tick, "action": "enable", "id": "atomic_friction"})
	# Spend only through visible, legal upgrades. No Arcane Compressor,
	# prestige-technology-only upgrades or unearned operation modes are bought.
	for upgrade: Upgrade in state.upgrades.values():
		var definition: UpgradeDefinition = upgrade.definition
		if definition.automatic or definition.generator_id in ["thermal_compressor", "relic_shard_extractor"]:
			continue
		if definition.id == "thermal_compressor_unlock":
			continue
		if state.upgrade_system.is_upgrade_visible(upgrade) and simulation.can_buy_upgrade(definition.id):
			var cost: float = simulation.get_upgrade_cost(upgrade)
			if simulation.buy_upgrade(definition.id, "fixture_policy"):
				actions.append({"tick": tick, "action": "upgrade", "id": definition.id, "cost": cost, "level": upgrade.level})
	# A player alternates a 45-second Heat-saving phase and a 15-second
	# conversion phase, buying upstream levels/upgrades between conversions.
	# Mites remain active after their legitimate unlock to compete for Heat.
	var conversion: bool = tick % 600 >= 450
	for id: String in ["thermal_furnace", "matter_furnace"]:
		var generator: Generator = state.get_generator(id)
		var pause: bool = not conversion
		if id == "matter_furnace" and (not state.get_upgrade("infernal_forge_unlock").is_purchased() or state.get_generator("infernal_forge").cycle_active):
			pause = true
		if generator.manually_paused != pause:
			simulation.toggle_generator_pause(id)
			actions.append({"tick": tick, "action": "pause", "id": id, "paused": pause})
	# Real mode choices are only used after their unlock upgrade is purchased.
	var forge: Generator = state.get_generator("infernal_forge")
	if not forge.cycle_active:
		for mode: GeneratorOperationMode in forge.definition.operation_modes:
			if mode.id == "fast" and mode.unlocked:
				forge.set_operation_mode(mode.id)
		if simulation.can_buy_generator("infernal_forge") and simulation.buy_generator("infernal_forge", "fixture_policy"):
			actions.append({"tick": tick, "action": "cycle", "id": "infernal_forge", "level": forge.level, "mode": forge.operation_mode_id})
	# Cheapest affordable level first, within a recorded player strategy.
	var candidates: Array = targets.keys()
	candidates.sort_custom(func(a: String, b: String) -> bool: return state.get_generator(a).get_cost(state) < state.get_generator(b).get_cost(state))
	for id: String in candidates:
		var generator: Generator = state.get_generator(id)
		if id == "lava_mite_colony" and not snapshots.has("early"):
			continue
		if generator.level >= int(targets[id]) or not generator.unlocked:
			continue
		if simulation.can_buy_generator(id):
			var cost: float = generator.get_cost(state)
			if simulation.buy_generator(id, "fixture_policy"):
				actions.append({"tick": tick, "action": "generator", "id": id, "cost": cost, "level": generator.level})


func _capture(name: String) -> void:
	snapshots[name] = {"tick": tick, "action_count": actions.size(), "save": Save.new().state_to_dictionary(state).duplicate(true), "summary": _summary()}
	print("CAPTURE ", name, " ", JSON.stringify(_summary()))


func _summary() -> Dictionary:
	var generators: Dictionary = {}
	for id: String in targets:
		generators[id] = state.get_generator(id).level
	generators["infernal_forge"] = state.get_generator("infernal_forge").level
	var resources: Dictionary = {}
	for id: String in state.resources:
		resources[id] = state.get_resource_amount(id)
	return {"tick": tick, "prestiges": state.eternal_flame_state.prestige_count, "flames": state.eternal_flame_state.eternal_flame, "levels": generators, "resources": resources, "cycle_progress": state.get_generator("infernal_forge").cycle_progress}
