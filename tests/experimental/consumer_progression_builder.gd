extends SceneTree

# Replays the original legal policy from a reached save. No grants/ablations.
const Core = preload("res://tests/experimental/core_fixtures.gd")
const STEP: float = TimeManager.OFFLINE_MAX_GAME_STEP
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/core_progression.json"))
	var initial: Dictionary = manifest["snapshots"]["early"]
	var state: GameState = Core.from_save(initial["save"])
	var simulation := Simulation.new(state)
	var action_index: int = int(initial["action_count"])
	var snapshots: Dictionary = {}
	for tick: int in range(int(initial["tick"]) + 1, 50001):
		simulation.update(STEP, true)
		while action_index < manifest["actions"].size() and int(manifest["actions"][action_index]["tick"]) == tick:
			var action: Dictionary = manifest["actions"][action_index]
			var id: String = str(action.get("id", ""))
			var ok: bool = false
			match action["action"]:
				"generator":
					ok = simulation.can_buy_generator(id) and _equal(state.get_generator(id).get_cost(state), float(action["cost"]))
					ok = simulation.buy_generator(id, "fixture_policy") and ok
					ok = ok and state.get_generator(id).level == int(action["level"])
				"upgrade":
					var upgrade: Upgrade = state.get_upgrade(id)
					ok = state.upgrade_system.is_upgrade_visible(upgrade) and simulation.can_buy_upgrade(id) and _equal(simulation.get_upgrade_cost(upgrade), float(action["cost"]))
					ok = simulation.buy_upgrade(id, "fixture_policy") and ok
					ok = ok and upgrade.level == int(action["level"])
				"pause":
					simulation.toggle_generator_pause(id)
					ok = state.get_generator(id).manually_paused == bool(action["paused"])
			if not ok:
				failures.append("Consumer ledger mismatch at action " + str(action_index))
			action_index += 1
		if tick in [9500, 20000, 50000]:
			snapshots[str(tick)] = {"tick": tick, "action_count": action_index, "save": SaveManager.new().state_to_dictionary(state)}
		if not failures.is_empty():
			break
	var output := FileAccess.open("res://tests/experimental/consumer_progression.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"source": "core_progression.json early save + unchanged legal ledger through tick 50000", "snapshots": snapshots, "failures": failures}, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("CONSUMER_PROGRESSION failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)


func _equal(a: float, b: float) -> bool:
	# Original ledger JSON transport allowance, never used for kernel parity.
	return absf(a - b) <= 1e-8 + 1e-12 * absf(a)
