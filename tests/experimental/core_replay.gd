extends SceneTree

const Fixtures = preload("res://tests/experimental/core_fixtures.gd")
const Logs = preload("res://tests/experimental/autobuyer_fixtures.gd")
var tick: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/core_progression.json"))
	var state := GameState.new()
	state.gameplay_rng.seed = int(manifest["seed"])
	state.gameplay_log = Logs.TickLog.new()
	state.gameplay_log.clock = func() -> float: return float(tick) * TimeManager.OFFLINE_MAX_GAME_STEP
	var simulation := Simulation.new(state)
	var action_index: int = 0
	var verified: Array[String] = []
	var event_fixture: Dictionary = {}
	var started: int = Time.get_ticks_usec()
	for index: int in range(int(manifest["ticks"]) + 1):
		tick = index
		var before: Dictionary = {}
		var forge: Generator = state.get_generator("infernal_forge")
		if event_fixture.is_empty() and forge.cycle_active and forge.get_cycle_duration() - forge.cycle_progress < 1.0:
			before = SaveManager.new().state_to_dictionary(state).duplicate(true)
		var flames: float = state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME)
		simulation.update(TimeManager.OFFLINE_MAX_GAME_STEP, true)
		if not before.is_empty() and state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME) > flames:
			event_fixture = {"source": "authoritative ledger replay, first completed Forge", "tick": tick, "before": before, "after": SaveManager.new().state_to_dictionary(state).duplicate(true)}
		while action_index < manifest["actions"].size() and int(manifest["actions"][action_index]["tick"]) == tick:
			var action: Dictionary = manifest["actions"][action_index]
			var id: String = str(action.get("id", ""))
			var ok: bool = false
			match action["action"]:
				"generator", "cycle":
					ok = simulation.can_buy_generator(id) and _equal(state.get_generator(id).get_cost(state), float(action.get("cost", state.get_generator(id).get_cost(state))))
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
				"enable":
					ok = state.generator_automation_manager.set_enabled(id, true)
				"smash":
					var system := PrestigeSystem.new()
					ok = system.smash(state, float(tick) * TimeManager.OFFLINE_MAX_GAME_STEP) == float(action["reward"])
					ok = system.begin_next_realm(state) and ok
					simulation = Simulation.new(state)
				_:
					ok = false
			if not ok:
				failures.append("Ledger transaction mismatch: " + str(action_index))
				break
			action_index += 1
		for name: String in manifest["snapshots"]:
			var snapshot: Dictionary = manifest["snapshots"][name]
			if int(snapshot["tick"]) != tick:
				continue
			_check_snapshot(state, snapshot["save"], name)
			if action_index != int(snapshot["action_count"]):
				failures.append("Snapshot action count mismatch: " + name)
			verified.append(name)
		if not failures.is_empty():
			break
		if tick % 100000 == 0:
			print("REPLAY_TICK ", tick)
	var result: Dictionary = {"ticks": tick + 1, "transactions": action_index, "verified": verified, "failures": failures, "wall_seconds": float(Time.get_ticks_usec() - started) / 1e6, "engine": Engine.get_version_info()["string"], "event_tick": event_fixture.get("tick", -1)}
	if event_fixture.is_empty():
		failures.append("No actual cycle completion witness")
	var file: FileAccess = FileAccess.open("res://tests/experimental/core_replay_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	if not event_fixture.is_empty():
		file = FileAccess.open("res://tests/experimental/core_event_fixture.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(event_fixture, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("CORE_REPLAY " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)


func _equal(a: float, b: float) -> bool:
	# JSON ledger transport precision only; simulation comparison tolerances
	# remain the established 1e-8 absolute / 1e-4 relative elsewhere.
	return absf(a - b) <= 1e-8 + 1e-12 * absf(a)


func _check_snapshot(state: GameState, data: Dictionary, name: String) -> void:
	for id: String in data["resources"]:
		if not _equal(state.get_resource_amount(id), float(data["resources"][id])):
			failures.append("Reachability resource mismatch: " + name + "/" + id)
	for id: String in data["generators"]:
		if state.get_generator(id).level != int(data["generators"][id]["level"]) or state.get_generator(id).operation_mode_id != str(data["generators"][id]["operation_mode_id"]):
			failures.append("Reachability generator mismatch: " + name + "/" + id)
	for id: String in data["upgrades"]:
		if state.get_upgrade(id).level != int(data["upgrades"][id]["level"]):
			failures.append("Reachability upgrade mismatch: " + name + "/" + id)
	if str(state.gameplay_rng.state) != str(data["gameplay_rng"]["state"]):
		failures.append("Reachability RNG mismatch: " + name)
