extends RefCounted

# Reference managers retain the full registry scan on every offline update.
class ReferenceGeneratorAutomation extends GeneratorAutomationManager:
	func update(delta: float, simulation: Simulation, _offline_mode: bool = false) -> void:
		super.update(delta, simulation, false)

class ReferenceUpgradeAutomation extends UpgradeAutomationManager:
	func update(delta: float, simulation: Simulation, _offline_mode: bool = false) -> void:
		super.update(delta, simulation, false)

class Log extends RefCounted:
	var events: Array[Dictionary] = []
	func record_event(category: String, event: String, details: Dictionary = {}, source: String = "game") -> void:
		events.append({"category": category, "event": event, "details": details.duplicate(true), "source": source})

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func make_state(reference: bool = false) -> GameState:
	var state := GameState.new()
	state.gameplay_rng.seed = 123456
	state.gameplay_log = Log.new()
	if reference:
		state.generator_automation_manager = ReferenceGeneratorAutomation.new(state)
		state.upgrade_automation_manager = ReferenceUpgradeAutomation.new(state)
	return state

func fingerprint(state: GameState) -> String:
	var data: Dictionary = SaveManager.new().state_to_dictionary(state).duplicate(true)
	data.erase("lava_palette")
	var runtime: Dictionary = {}
	for id in state.generators:
		var g: Generator = state.generators[id]
		var io_unlocks: Array[bool] = []
		for mode in g.definition.operation_modes:
			io_unlocks.append(mode.unlocked)
			for io in mode.inputs + mode.outputs + mode.completion_outputs:
				io_unlocks.append(io.unlocked)
		runtime[id] = [g.operating, g.is_throttled, g.cycle_critical_chance_snapshot, io_unlocks]
	return var_to_bytes([data, runtime, state.generator_automation_manager.automation_states,
		state.upgrade_automation_manager.automation_states, state.get_lava_mite_dormancy_penalty(),
		state.gameplay_log.events, state.simulation_statistics.to_dictionary() if state.simulation_statistics != null else {}]).hex_encode().sha256_text()

func enable(state: GameState, id: String, value: bool) -> void:
	state.eternal_flame_state.unlock_technology(state.generator_automation_manager.get_automation_technology_id(id))
	state.eternal_flame_state.unlock_technology(state.upgrade_automation_manager.get_automation_technology_id(id))
	state.generator_automation_manager.set_enabled(id, value)
	state.upgrade_automation_manager.set_enabled(id, value)

func configure(state: GameState) -> void:
	state.set_resource_amount(ResourceIds.HEAT, 100000.0)
	state.set_resource_amount(ResourceIds.MATTER, 500.0)
	state.set_resource_amount(ResourceIds.ASH, 50.0)
	for generator in state.generators.values():
		generator.unlocked = true
		if not generator.definition.cycle_based:
			generator.level = 2
	enable(state, "atomic_friction", true)
	enable(state, "matter_furnace", true)
	state.generator_automation_manager.automation_states["atomic_friction"]["remaining_cooldown"] = 0.3
	state.upgrade_automation_manager.automation_states["atomic_friction"]["remaining_cooldown"] = 0.1

func test_index_parity() -> void:
	var reference := make_state(true)
	var candidate := make_state()
	for state in [reference, candidate]:
		configure(state)
	var a := Simulation.new(reference)
	var b := Simulation.new(candidate)
	for tick in range(160):
		for state in [reference, candidate]:
			if tick == 20:
				enable(state, "molecular_agitation", true)
			if tick == 40:
				enable(state, "atomic_friction", false)
				state.set_resource_amount(ResourceIds.MATTER, 0.0)
			if tick == 80:
				state.set_resource_amount(ResourceIds.MATTER, 500.0)
				state.eternal_flame_state.unlocked_technologies.clear()
			if tick == 100:
				enable(state, "matter_furnace", true)
		a.update(0.1, true)
		b.update(0.1, true)
		check(fingerprint(reference) == fingerprint(candidate), "Registry/index parity diverged at tick %d." % tick)
		if tick == 0:
			check(candidate.get_generator("atomic_friction").level == 2, "Generator automation purchased before its cooldown boundary.")
		if tick == 2:
			check(candidate.get_generator("atomic_friction").level >= 3, "Generator automation missed its cooldown boundary.")
	check(not reference.gameplay_log.events.is_empty(), "Automation parity fixture did not exercise progression events.")
	for state in [reference, candidate]:
		state.reset_current_run()
		state.set_resource_amount(ResourceIds.HEAT, 10000.0)
		enable(state, "atomic_friction", true)
	a.rebuild_upgrade_effects()
	b.rebuild_upgrade_effects()
	for tick in range(60):
		a.update(0.1, true)
		b.update(0.1, true)
	check(fingerprint(reference) == fingerprint(candidate), "Reset/rebuild invalidation changed automation results.")

func test_starvation() -> void:
	for producing in [false, true]:
		var reference := make_state(true)
		var candidate := make_state()
		for state in [reference, candidate]:
			configure(state)
			state.set_lava_mite_dormancy_penalty(0.75)
			for id in state.resources:
				state.set_resource_amount(id, 0.0)
			for g in state.generators.values():
				g.manually_paused = not producing and g.get_active_inputs().is_empty()
		var a := Simulation.new(reference)
		var b := Simulation.new(candidate)
		for tick in range(200):
			a.update(0.1, true)
			b.update(0.1, true)
			check(fingerprint(reference) == fingerprint(candidate), "Starvation/feedback changed state at tick %d." % tick)

func test_save_load() -> void:
	var source := make_state()
	configure(source)
	Simulation.new(source).update(0.1, true)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(SaveManager.new().state_to_dictionary(source)))
	var reference := make_state(true)
	var candidate := make_state()
	for state in [reference, candidate]:
		# Warm an empty index before loading enabled automation.
		Simulation.new(state).update(0.1, true)
		check(SaveManager.new().dictionary_to_state(state, saved, SaveManager.SAVE_VERSION), "Save-load fixture failed to load.")
	var a := Simulation.new(reference)
	var b := Simulation.new(candidate)
	for tick in range(100):
		a.update(0.1, true)
		b.update(0.1, true)
	check(fingerprint(reference) == fingerprint(candidate), "Save/load continuation changed indexed automation.")

func configure_cycles(state: GameState) -> void:
	for g in state.generators.values():
		g.manually_paused = not g.definition.cycle_based
	state.set_resource_amount(ResourceIds.MATTER, 1e12)
	state.set_resource_amount(ResourceIds.HEAT, 1e12)
	state.get_upgrade("infernal_forge_unlock").level = 1
	state.get_upgrade("infernal_forge_critical_chance").level = 1
	state.get_upgrade("infernal_forge_recrystallization").level = 1
	var simulation := Simulation.new(state)
	simulation.rebuild_upgrade_effects()
	state.realm_effects.matter_decay_threshold = 1e15
	state.realm_effects.heat_leak_threshold = 1e15
	for id in ["infernal_forge", "relic_shard_extractor"]:
		var g: Generator = state.get_generator(id)
		g.unlocked = true
		g.auto_run_cycles = true
		g.definition.base_cost = 0.0
		state.eternal_flame_state.unlock_technology(EternalFlameState.get_cycle_auto_run_technology_id(id))
	var forge: Generator = state.get_generator("infernal_forge")
	forge.operation_mode_id = "fast"
	forge.modifiers.clear()
	forge.invalidate_production_modifier_cache()
	for effect in forge.event_effects:
		effect.event_chance = 0.5
	var crucible: Generator = state.get_generator("relic_shard_extractor")
	crucible.operation_mode_id = "forge_relic"
	state.relic_manager.add_stackable_item("relic_shard", 1000)
	var entry: Dictionary = state.relic_manager.get_inventory_entry_at_slot(0)
	check(state.relic_manager.move_inventory_entry_to_machine_slot(str(entry["instance_id"]), crucible.definition.id, 0), "Could not stock the repeat crafting fixture.")

func catch_up(state: GameState, seconds: float, budget: float, noisy: bool, scale: float = 1.0) -> Dictionary:
	var manager := TimeManager.new(Simulation.new(state))
	manager.offline_work_budget_ms = budget
	manager.time_scale = scale
	var progress: Array[Vector2i] = []
	manager.offline_simulation_progress.connect(func(current: int, total: int) -> void:
		progress.append(Vector2i(current, total))
		if noisy:
			seed(321 + current)
			for _index in range(current % 19):
				randf()
				randi()
	)
	await manager.simulate_offline(seconds)
	check(not manager.offline_simulation_active, "Catch-up remained active after completion.")
	if seconds > 0.0:
		check(not progress.is_empty() and progress.back().x == progress.back().y, "Progress did not reach 100%.")
		for point in progress:
			check(point.x >= 0 and point.x <= point.y, "Progress escaped [0, 100%].")
	else:
		check(progress.is_empty() and manager.offline_yield_count == 0, "Immediate completion introduced progress/yields.")
	return {"state": fingerprint(state), "clocks": var_to_bytes([manager.game_time, manager.offline_time, manager.prestige_time, manager.current_offline_duration]).hex_encode(), "steps": manager.offline_steps_processed}

func test_scheduling() -> void:
	var reference := make_state(true)
	configure_cycles(reference)
	var expected: Dictionary = await catch_up(reference, 360.0, 0.0, false)
	check(reference.relic_manager.inventory.size() >= 3, "Scheduling fixture did not repeat relic crafting.")
	for budget in [8.0, 12.0, 16.0]:
		var state := make_state()
		configure_cycles(state)
		check(await catch_up(state, 360.0, budget, true) == expected, "Frame budget %.0f changed cycles, RNG, resources, event order or clocks." % budget)
	# Reload the same active craft into both paths, avoiding unrelated historical
	# save/resume timing differences from an uninterrupted run.
	var active := make_state()
	configure_cycles(active)
	Simulation.new(active).update(0.1, true)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(SaveManager.new().state_to_dictionary(active)))
	var a := make_state(true)
	var b := make_state()
	for state in [a, b]:
		check(SaveManager.new().dictionary_to_state(state, saved, SaveManager.SAVE_VERSION), "Active-craft scheduling save failed to load.")
	check(await catch_up(a, 120.0, 0.0, false) == await catch_up(b, 120.0, 12.0, true), "Loaded active craft changed with frame scheduling.")
	# Public dictionary edits between sessions must refresh at catch-up entry.
	var before_a := make_state(true)
	var before_b := make_state()
	for state in [before_a, before_b]:
		enable(state, "atomic_friction", false)
		Simulation.new(state).update(0.1, true)
		state.generator_automation_manager.automation_states["atomic_friction"]["enabled"] = true
		state.set_resource_amount(ResourceIds.HEAT, 100.0)
	check(await catch_up(before_a, 0.15, 0.0, false) == await catch_up(before_b, 0.15, 12.0, true), "Catch-up entry retained a stale enabled index.")

func test_short_durations() -> void:
	for scale in [0.0, 1.0, 2.5]:
		for seconds in [-1.0, 0.0, 0.00001, 0.1, 0.15]:
			var a := make_state(true)
			var b := make_state()
			check(await catch_up(a, seconds, 0.0, false, scale) == await catch_up(b, seconds, 12.0, true, scale), "Short/zero-duration or scaled catch-up changed exact state.")
