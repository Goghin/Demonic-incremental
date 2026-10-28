extends RefCounted

const Logs = preload("res://tests/experimental/autobuyer_fixtures.gd")
const SCENARIOS: Array[String] = ["early", "mid", "forge_competing", "forge_running", "forge", "transfer", "late_both"]


static func make_state(scenario: String) -> GameState:
	if scenario in ["transfer", "late_both"]:
		return preload("res://tests/experimental/resource_flow_fixtures.gd").make_state(scenario)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/core_progression.json"))
	var state: GameState = from_save(manifest["snapshots"]["forge" if scenario in ["forge_running", "forge_competing"] else scenario]["save"])
	if scenario in ["forge_running", "forge_competing"] and state.get_generator("thermal_furnace").manually_paused:
		# Legal player action at offline entry, with no resource/upgrade edits.
		Simulation.new(state).toggle_generator_pause("thermal_furnace")
	if scenario == "forge_competing" and state.get_generator("matter_furnace").manually_paused:
		Simulation.new(state).toggle_generator_pause("matter_furnace")
	return state


static func from_save(data: Dictionary) -> GameState:
	var state := GameState.new()
	state.gameplay_log = Logs.TickLog.new()
	if not SaveManager.new().dictionary_to_state(state, data, SaveManager.SAVE_VERSION):
		push_error("Invalid core fixture save")
	Simulation.new(state).rebuild_upgrade_effects()
	# This is the actual save/load boundary: nonserialized operating/throttle
	# flags initialize normally and settle via authoritative updates.
	state.gameplay_log.events.clear()
	return state


static func ablate(state: GameState, kind: String) -> void:
	# Diagnostic state copies ONLY. These are not reachable fixtures and may
	# never be counted as realistic coverage gains.
	if kind.contains("cycles"):
		for g: Generator in state.generators.values():
			if g.definition.cycle_based:
				g.unlocked = false
				g.cycle_active = false
				g.auto_run_cycles = false
				g.operating = false
	if kind.contains("automation"):
		for manager in [state.generator_automation_manager, state.upgrade_automation_manager]:
			for id: String in manager.automation_states:
				manager.set_enabled(id, false)
	if kind == "consumers":
		for g: Generator in state.generators.values():
			if not g.get_active_inputs().is_empty():
				g.unlocked = false
				g.operating = false
				g.cycle_active = false
