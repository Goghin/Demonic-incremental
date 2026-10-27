extends RefCounted

const Existing = preload("res://tests/experimental/autobuyer_fixtures.gd")
const SCENARIOS: Array[String] = ["transfer", "exhaustion", "matter_modifier", "heat_leak", "matter_decay", "threshold", "generator_wait", "upgrade_wait", "competing", "mixed", "cycles", "late_both", "dynamic_cost"]


static func make_state(scenario: String) -> GameState:
	if scenario in ["mixed", "competing", "late_both"]:
		return Existing.make_state(scenario)
	if scenario == "dynamic_cost":
		return Existing.make_state("late_dynamic")
	if scenario == "cycles":
		var cycles: GameState = Existing.Existing.make_state("cycles")
		cycles.gameplay_log = Existing.TickLog.new()
		return cycles
	var state := GameState.new()
	state.gameplay_rng.seed = 123456
	state.gameplay_log = Existing.TickLog.new()
	# Controlled funded realm: use real definitions, IO, rates, unlock effects,
	# and realm formulas. This is not represented as a natural save/playthrough.
	state.realm_configuration.stability = 1e12
	state.realm_configuration.density = 1e12
	state.rebuild_realm_effects()
	state.get_generator("atomic_friction").manually_paused = true
	state.get_upgrade("thermal_compressor_unlock").level = 1
	var simulation := Simulation.new(state)
	simulation.rebuild_upgrade_effects()
	var transfer: Generator = state.get_generator("thermal_compressor")
	transfer.unlocked = true
	transfer.level = 1
	transfer.set_operation_mode("expansion")
	state.set_resource_amount(ResourceIds.NEXUM, 1e6)
	if scenario == "exhaustion":
		state.set_resource_amount(ResourceIds.NEXUM, 400.0)
	elif scenario == "matter_modifier":
		state.get_generator("atomic_friction").manually_paused = false
	elif scenario in ["heat_leak", "matter_decay", "threshold"]:
		state.realm_configuration.stability = 0.0
		state.realm_configuration.density = 0.0
		state.rebuild_realm_effects()
		if scenario == "heat_leak":
			state.get_generator("atomic_friction").manually_paused = false
			state.set_resource_amount(ResourceIds.HEAT, state.realm_effects.heat_leak_threshold * 2.0)
		elif scenario == "matter_decay":
			state.set_resource_amount(ResourceIds.MATTER, state.realm_effects.matter_decay_threshold * 2.0)
		else:
			state.set_resource_amount(ResourceIds.MATTER, state.realm_effects.matter_decay_threshold * 0.99)
	elif scenario in ["generator_wait", "upgrade_wait"]:
		Existing.enable(state, "atomic_friction", scenario == "upgrade_wait")
	return state
