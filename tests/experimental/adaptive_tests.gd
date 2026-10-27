extends RefCounted

const Adaptive = preload("res://tests/experimental/adaptive_offline.gd")
const Checkpoint = preload("res://tests/experimental/continuous_checkpoint.gd")
const Metrics = preload("res://tests/experimental/adaptive_metrics.gd")
const Fixture = preload("res://tests/experimental/adaptive_benchmark.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func full(state: GameState) -> String:
	var saved: Dictionary = SaveManager.new().state_to_dictionary(state).duplicate(true)
	saved.erase("lava_palette")
	return var_to_bytes([saved, Metrics.numeric(state), Metrics.discrete(state)]).hex_encode().sha256_text()

func observe(simulation: Simulation) -> void:
	var log = simulation.state.gameplay_log
	simulation.generator_unlocked.connect(func(id: String) -> void: log.record_event("signal", "unlock", {"id": id}))
	simulation.crystallization_completed.connect(func(amount: float) -> void: log.record_event("signal", "normal_cycle", {"amount": amount}))
	simulation.critical_crystallization_completed.connect(func(amount: float) -> void: log.record_event("signal", "critical_cycle", {"amount": amount}))
	simulation.relic_crafting_completed.connect(func(name: String, quantity: int, critical: bool) -> void: log.record_event("signal", "craft", {"name": name, "quantity": quantity, "critical": critical}))
	simulation.generator_level_reduced.connect(func(id: String, before: int, after: int) -> void: log.record_event("signal", "downlevel", {"id": id, "before": before, "after": after}))

func compare_states(a: GameState, b: GameState, seconds: float, expect_exact: bool = false, maximum: float = 60.0) -> Dictionary:
	var prototype = Adaptive.new(Simulation.new(a))
	prototype.maximum_step = maximum
	observe(prototype.simulation)
	prototype.run(seconds)
	var reference := Simulation.new(b)
	observe(reference)
	var manager := TimeManager.new(reference)
	if seconds > 0.0:
		b.simulation_statistics = manager.simulation_statistics
	var elapsed: float = 0.0
	for _index in range(ceili(seconds / TimeManager.OFFLINE_MAX_GAME_STEP)):
		var delta: float = minf(TimeManager.OFFLINE_MAX_GAME_STEP, seconds - elapsed)
		if delta <= 0.0:
			break
		elapsed = minf(seconds, elapsed + delta)
		manager.game_time += delta
		manager.offline_time += delta
		manager.prestige_time += delta
		manager.current_offline_duration += delta
		b.set_lava_mite_dormancy_penalty(manager.get_dormancy_penalty(elapsed))
		reference.update(delta, true)
	check(prototype.counters["strict_failure"] == "", "Prototype encountered an unexpected discrete event.")
	check(Metrics.discrete(a) == Metrics.discrete(b), "Discrete outcomes, inventory, eligibility, cooldowns or event order diverged.")
	check(a.gameplay_rng.state == b.gameplay_rng.state, "Prototype changed the gameplay RNG sequence.")
	check(float(Metrics.compare(Metrics.numeric(b, manager), Metrics.numeric(a, prototype.manager), 1e-8, 1e-4)["normalized"]) <= 1.0, "Prototype exceeded the measured numerical target.")
	if expect_exact:
		check(full(a) == full(b), "Exact fallback did not preserve binary state/statistics.")
	return prototype.counters

func test_checkpoint() -> void:
	var state: GameState = Fixture.make_state("matter")
	state.simulation_statistics = ResourceStatistics.new()
	var simulation := Simulation.new(state)
	simulation.update(0.1, true)
	var prototype = Adaptive.new(simulation)
	check(prototype.guard() == "", "Checkpoint fixture did not enter the supported subset.")
	var original: String = full(state)
	var saved: Dictionary = Checkpoint.capture(simulation)
	simulation.update(0.4, true)
	check(full(state) != original, "Checkpoint test did not change resources/statistics.")
	Checkpoint.restore(simulation, saved)
	check(full(state) == original, "Checkpoint restore lost peaks, flows, discovery or balances.")

func test_restricted() -> void:
	for scenario in ["stable", "essence", "idle"]:
		var a: GameState = Fixture.make_state(scenario)
		var b: GameState = Fixture.make_state(scenario)
		var counters: Dictionary = compare_states(a, b, 600.0)
		check(counters["accepted"] > 0 and counters["evaluations"] < 6000, "Restricted fixture did not reduce numerical evaluations: " + scenario)

func test_fallbacks() -> void:
	for scenario in ["automation", "upgrade_automation", "cycles", "coupled", "starved", "ash"]:
		var a: GameState = Fixture.make_state(scenario)
		var b: GameState = Fixture.make_state(scenario)
		if scenario == "cycles":
			for state in [a, b]:
				# Settle automatic contamination before isolating fast critical
				# cycles; otherwise Ash can prevent any Forge completion here.
				Simulation.new(state).update_automatic_upgrades()
				var forge: Generator = state.get_generator("infernal_forge")
				forge.modifiers.clear()
				forge.invalidate_production_modifier_cache()
				state.get_generator("relic_shard_extractor").get_operation_mode().completion_critical_chance = 1.0
		if scenario == "coupled":
			for state in [a, b]:
				state.set_resource_amount(ResourceIds.CRYSTALLIZED_FLAME, 3.0)
				state.set_resource_amount(ResourceIds.ESSENCE, 100.0)
				state.get_generator("infernal_forge").level = 1
				state.get_upgrade("infernal_forge_unlock").level = 1
				Simulation.new(state).rebuild_upgrade_effects()
		var seconds: float = 900.0 if scenario == "coupled" else (180.0 if scenario == "cycles" else 30.0)
		var counters: Dictionary = compare_states(a, b, seconds, true)
		check(counters["accepted"] == 0, "Unsupported mechanics entered adaptive integration: " + scenario)
		if scenario == "cycles":
			check(a.relic_manager.inventory.size() > 0, "Exact fallback test did not craft a relic.")
			check(a.gameplay_log.events.any(func(event: Dictionary) -> bool: return event["event"] == "craft"), "Craft completion signals were not observed.")
			check(a.gameplay_log.events.any(func(event: Dictionary) -> bool: return event["event"] == "craft" and event["details"]["critical"]), "Guaranteed critical crafting fixture did not produce a critical relic.")
			check(a.gameplay_log.events.any(func(event: Dictionary) -> bool: return event["event"] == "critical_cycle"), "Critical cycle outcomes were not observed.")

func test_threshold_order() -> void:
	var a: GameState = Fixture.make_state("fresh")
	var b: GameState = Fixture.make_state("fresh")
	for state in [a, b]:
		var producer: Generator = state.get_generator("molecular_agitation")
		producer.unlocked = true
		producer.level = 1
	var counters: Dictionary = compare_states(a, b, 40.0, true)
	check(int(counters["fallback_reasons"].get("automatic_resource_boundary", 0)) > 0, "Resource-threshold event guard was not exercised.")
	check(a.get_upgrade("ashen_contamination").level == 1, "Threshold fixture missed its automatic upgrade.")

func test_rejection() -> void:
	var counters: Dictionary = compare_states(Fixture.make_state("heat"), Fixture.make_state("heat"), 60.0, true)
	check(counters["rejected"] > 0, "Nonlinear fixture did not exercise rejected-step rollback.")
	check(counters["fallback_ticks"] == 600, "Rejected trials silently replaced authoritative integration.")

func test_save_load() -> void:
	for scenario in ["essence", "cycles"]:
		var source: GameState = Fixture.make_state(scenario)
		Simulation.new(source).update(0.1, true)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(SaveManager.new().state_to_dictionary(source)))
		var a: GameState = Fixture.make_state("fresh")
		var b: GameState = Fixture.make_state("fresh")
		for state in [a, b]:
			check(SaveManager.new().dictionary_to_state(state, saved, SaveManager.SAVE_VERSION), "Saved fixture failed to load.")
		compare_states(a, b, 120.0 if scenario == "cycles" else 30.0, scenario == "cycles")

func test_configuration() -> void:
	compare_states(Fixture.make_state("stable"), Fixture.make_state("stable"), 60.0, true, 0.1)
	for seconds in [0.0, 0.01, 0.15, 0.5]:
		compare_states(Fixture.make_state("stable"), Fixture.make_state("stable"), seconds, true)
	var state: GameState = Fixture.make_state("stable")
	var original: String = full(state)
	var prototype = Adaptive.new(Simulation.new(state))
	prototype.minimum_step = 0.01
	check(prototype.run(10.0)["strict_failure"] != "", "Sub-reference minimum timestep was accepted.")
	check(full(state) == original, "Invalid configuration mutated gameplay state.")

	prototype.minimum_step = 0.1
	prototype.manager.time_scale = 2.0
	check(prototype.run(10.0)["strict_failure"] != "", "Unsupported TimeManager scaling was not rejected.")
	check(full(state) == original, "Unsupported timer context mutated gameplay state.")
