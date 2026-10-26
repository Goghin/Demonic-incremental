extends "res://tests/offline_performance_benchmark.gd"

var batch_scenario: String = "stress"
var budget_ms: float = 0.0
var cosmetic_noise: bool = false

func _run_benchmarks() -> void:
	var options: Dictionary = {"duration": "600", "mode": "direct", "scenario": "stress", "repeats": "3", "profile": "false", "budget": "12"}
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			options[parts[0]] = parts[1]
	batch_scenario = str(options["scenario"])
	budget_ms = float(options.get("budget", "0"))
	cosmetic_noise = options.get("noise", "false") == "true"
	for repeat_index in range(int(options["repeats"])):
		var result: Dictionary = await _measure(float(options["duration"]), str(options["mode"]), batch_scenario, options["profile"] == "true")
		result["repeat"] = repeat_index
		print("PERFORMANCE_JSON " + JSON.stringify(result))
	quit()

func _configure_test_state(state: GameState) -> void:
	if batch_scenario == "fresh":
		return
	super._configure_test_state(state)
	if batch_scenario in ["midgame", "starved", "idle", "environment"]:
		for id in GeneratorAutomationManager.AUTOMATABLE_GENERATOR_IDS:
			state.generator_automation_manager.set_enabled(id, false)
		for id in UpgradeAutomationManager.AUTOMATABLE_GENERATOR_IDS:
			state.upgrade_automation_manager.set_enabled(id, false)
	if batch_scenario == "starved":
		for id in state.resources:
			state.set_resource_amount(id, 0.0)
		for generator in state.generators.values():
			if generator.get_active_inputs().is_empty():
				generator.manually_paused = true
	if batch_scenario == "idle":
		for id in state.resources:
			state.set_resource_amount(id, 0.0)
		for generator in state.generators.values():
			generator.manually_paused = true
	if batch_scenario == "environment":
		state.realm_configuration.stability = 0
		state.realm_configuration.integrity = 0
		state.rebuild_realm_effects()
		state.set_resource_amount(ResourceIds.HEAT, 1e9)
		state.set_resource_amount(ResourceIds.MATTER, 1e8)
		state.set_resource_amount(ResourceIds.ASH, 1e5)


func _create_time_manager(simulation: Simulation) -> TimeManager:
	var manager := TimeManager.new(simulation)
	if manager.get("offline_work_budget_ms") != null:
		manager.set("offline_work_budget_ms", budget_ms)
	if cosmetic_noise:
		manager.offline_simulation_progress.connect(func(_current: int, _total: int) -> void:
			seed(_current + 53421)
			for _index in range(_current % 23):
				randf()
				randi()
		)
	return manager
