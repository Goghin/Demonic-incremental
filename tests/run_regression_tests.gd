extends SceneTree


# Lightweight regression tests for core game rules.
# Run from the project root:
#   godot --headless --path . --script res://tests/run_regression_tests.gd
#
# These tests create fresh in-memory GameState instances. A fake logger is
# injected so tests never append test events to the player's real gameplay log.


class TestGameplayLog extends RefCounted:
	var events: Array[Dictionary] = []

	func record_event(
		category: String,
		event_name: String,
		details: Dictionary = {},
		source: String = "game"
	) -> void:
		events.append({
			"category": category,
			"event": event_name,
			"details": details.duplicate(true),
			"source": source
		})


class InputRateProbe extends Generator:
	var rate_evaluations: int = 0

	func _init(generator_definition: GeneratorDefinition) -> void:
		super(generator_definition)

	func get_input_consumption_per_second(input: GeneratorIO, state: GameState, throttled_override: Variant = null) -> float:
		rate_evaluations += 1
		return super.get_input_consumption_per_second(input, state, throttled_override)


const GameplayRandomCompat = preload("res://Game/gameplay_random.gd")


const OfflineComparison = preload("res://simulation/offline_simulation_comparison.gd")


var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("")
	print("========================================")
	print(" DEMONIC INCREMENTAL REGRESSION TESTS")
	print("========================================")

	_run_test("GameState initializes core resources and generators", _test_initialization)
	_run_test("Gameplay RNG replay ignores cosmetics and is shared by normal/offline cycles", _test_gameplay_rng_replay)
	_run_test("Gameplay RNG survives JSON save/load without 64-bit rounding", _test_gameplay_rng_save_sequence)
	_run_test("Mixed gameplay rolls continue identically after save/load", _test_gameplay_rng_save_actions)
	_run_test("Active crafting critical snapshots survive JSON save/load", _test_gameplay_rng_critical_snapshot)
	_run_test("Version 8 saves migrate without RNG state or critical snapshots", _test_gameplay_rng_legacy_save)
	_run_test("Gameplay event RNG preserves roll order and probability-edge draw counts", _test_gameplay_rng_event_order)
	_run_test("Explicit relic RNG preserves deterministic rolls and configured ranges", _test_gameplay_rng_relic_ranges)
	_run_test("Resource discovery gates upgrade visibility and survives reset/save migration", _test_resource_discovery_visibility)
	_run_test("Essence accumulation reduces all Essence output and mitigation upgrades weaken it", _test_essence_accumulation_penalty)
	_run_test("Forge and Relic Crucible modes use the intended activation levels", _test_cycle_generator_activation_level_configuration)
	_run_test("Relic Crucible upgrades are independent from cycles and improve critical chance", _test_relic_crucible_level_upgrades)
	_run_test("Heat leak and Matter decay respect their thresholds", _test_environmental_thresholds)
	_run_test("Matter decay records matching lifetime, run and offline totals", _test_matter_decay_statistics)
	_run_test("Matter decay statistics clamp to actual available Matter", _test_matter_decay_clamped_statistics)
	_run_test("Offline benchmark compares numeric aggregates, sparse flows and generator flags", _test_offline_benchmark_comparison)
	_run_test("Offline benchmark formats resource flows and numeric aggregates", _test_offline_benchmark_statistics_output)
	_run_test("Offline partial-input startup matches the existing input gate", _test_offline_partial_input_startup)
	_run_test("Offline startup skips only unnecessary rate evaluations", _test_offline_startup_evaluation_count)
	_run_test("Offline automatic upgrades preserve registry order and eligibility timing", _test_offline_automatic_upgrade_order)
	_run_test("Generator purchase rejects insufficient resources", _test_purchase_rejects_insufficient_resources)
	_run_test("Generator purchase spends the exact cost and adds one level", _test_successful_generator_purchase)
	_run_test("Cycle mode can activate without increasing generator level", _test_cycle_mode_without_level_increase)
	_run_test("Cycle auto-run is prestige-unlock gated and restarts completed cycles", _test_cycle_auto_run)
	_run_test("Generator production increases Heat and records statistics", _test_generator_production)
	_run_test("Interval statistics are returned and cleared", _test_interval_statistics)
	_run_test("Realm reset clears resources and advances the run index", _test_realm_reset)
	_run_test("Prestige enters planning before resetting the next realm", _test_prestige_planning_transition)
	_run_test("Current realm Heat overflow and Matter decay compound for Smash", _test_current_realm_environmental_bonuses)
	_run_test("Prestige and lifetime Eternal Flame milestones grant starting levels and automation", _test_automatic_progression_rewards)
	_run_test("Brazier upgrades permanently unlock flame stats in order", _test_brazier_upgrade_unlocks)
	_run_test("Reliquary and generator relic slots unlock through Prestige progression", _test_reliquary_slot_progression)
	_run_test("Reliquary grants, equips, saves, and preserves relics", _test_relic_inventory_equipment_and_save)
	_run_test("Relic instances roll targeted stats and preserve rolls in saves", _test_rolled_relic_stats)
	_run_test("Generated relic sensitivity targets are specific and Ash Contamination is grouped", _test_generated_relic_sensitivity_targets)
	_run_test("Reservoir relics boost production most at low resource amounts", _test_resource_reservoir_relics)
	_run_test("Relics support sensitivity stats and saved uncommon bonus stats", _test_relic_sensitivity_and_secondary_stats)
	_run_test("Relics modify cycle critical and downlevel chances additively", _test_relic_event_chance_modifiers)
	_run_test("Relic Shards stack, merge, and persist in inventory", _test_relic_shard_stacks)
	_run_test("Machine crafting slots preserve, consume, and return ingredients", _test_machine_crafting_slots)
	_run_test("Crafting recipes are validated and consumed when a cycle starts", _test_crafting_cycle_start)
	_run_test("Relic Shard Extractor exposes five crafting modes and tiered rewards", _test_relic_shard_extractor_modes)
	_run_test("Data-driven relic generation persists rolls and promotes critical crafts", _test_data_driven_relic_generation_and_critical_promotion)
	_run_test("Relic Shard Extractor consumes Matter and grants a shard after one minute", _test_relic_shard_extractor_cycle)
	_run_test("Multiple relic slots stay independent and legacy saves migrate", _test_multiple_relic_slots_and_legacy_migration)
	_run_test("Modifier mode restrictions only apply in targeted modes", _test_modifier_operation_mode_targeting)
	_run_test("Ash contamination uses generic cycle-speed modifiers and sensitivities", _test_ashen_contamination_cycle_speed_modifier)
	_run_test("Forge Immunity blocks Ash production penalty but preserves cycle slowdown", _test_forge_immunity_ash_sensitivity)
	_run_test("Miscellaneous modifiers report effective multipliers and sensitivity", _test_misc_modifier_sensitivity_reporting)
	_run_test("Generic cycle completion effects modify output and can reduce level to zero", _test_cycle_completion_event_effects)
	_run_test("Cycle completion effects respect operation-mode restrictions", _test_cycle_event_operation_mode_targeting)
	_run_test("Generator stats expose data-driven special effects", _test_generator_special_effect_descriptors)

	_run_test("Offline automation index preserves cooldowns, eligibility, ordering and resets", _test_batch_c_index)
	_run_test("Offline automation index preserves dormant, starved and feedback states", _test_batch_c_starvation)
	_run_test("Offline automation index refreshes after save/load", _test_batch_c_save)
	await _run_async_test("Offline frame budgets preserve repeated crafting, RNG and loaded cycles", _test_batch_c_scheduling)
	await _run_async_test("Offline scheduling preserves zero/short periods and scaled time", _test_batch_c_short)

	_run_test("Experimental adaptive checkpoints restore all continuous statistics", _test_experimental_checkpoint)
	_run_test("Experimental adaptive subset preserves discrete outcomes and measured accuracy", _test_experimental_restricted)
	_run_test("Experimental unsupported mechanics fall back with exact binary parity", _test_experimental_fallbacks)
	_run_test("Experimental resource thresholds retain automatic-upgrade ordering", _test_experimental_threshold_order)
	_run_test("Experimental rejected steps cannot contaminate balances or statistics", _test_experimental_rejection)
	_run_test("Experimental adaptive and exact paths preserve loaded RNG/crafts", _test_experimental_save_load)
	_run_test("Experimental adaptive path validates minimum steps and short durations", _test_experimental_configuration)

	_run_test("Experimental reference-map feedback meets three sampled accuracy targets", _test_feedback_targets)
	_run_test("Experimental feedback preserves long-interval dormancy and statistics", _test_feedback_long_clocks)
	_run_test("Experimental feedback retains exact fallback for consumers and discrete systems", _test_feedback_fallbacks)
	_run_test("Experimental feedback cooldown bounds rejected trials and restores state", _test_feedback_retry_control)
	_run_test("Experimental feedback preserves loaded states and short intervals", _test_feedback_save_short)
	_run_test("Experimental feedback commits offline-entry interval bookkeeping exactly", _test_feedback_offline_entry)
	_run_test("Experimental accuracy modes validate policy and avoid short-interval regressions", _test_horizon_modes)
	_run_test("Experimental reference-map cleanups preserve every sampled binary state", _test_horizon_exact_cleanups)
	_run_test("Experimental diagnostics and retained audits are observational", _test_horizon_diagnostics)
	_run_test("Experimental modes use exact simulation at prestige reward boundaries", _test_horizon_prestige_protection)
	_run_test("Experimental modes preserve mixed gameplay, automation and consumers", _test_horizon_fallbacks)
	_run_test("Experimental source-free Matter decay safely leaves the absolute margin", _test_horizon_monotone_margin)
	_run_test("Experimental autobuyers advance only within proven waiting bounds", _test_autobuyer_waiting)
	_run_test("Experimental autobuyers preserve purchase ticks, priority and deductions", _test_autobuyer_purchases)
	_run_test("Experimental affordability proofs invalidate stale and dynamic costs", _test_autobuyer_invalidation)
	_run_test("Experimental autobuyer short and zero intervals remain exact", _test_autobuyer_short)
	_run_test("Upgrade autobuyers start cooldowns only after success and retry live waits", _test_cooldown_success_and_waiting)
	_run_test("Waiting upgrade buyers observe live requirements and exclusive choices", _test_cooldown_requirements_and_preferences)
	_run_test("Autobuyer purchases preserve registry, tree and generator-first priority", _test_cooldown_priority_and_competition)
	_run_test("Autobuyer large deltas stop failures and retain success overshoot", _test_cooldown_large_delta)
	_run_test("Waiting automation preserves existing save/load and prestige reset rules", _test_cooldown_save_and_reset)
	_run_test("Experimental ready upgrade waits skip replay with exact timer parity", _test_autobuyer_replay_elimination)
	_run_test("Experimental resource-flow proofs preserve dense endpoints, exhaustion and dependency transitions", _test_resource_flow_bounds)


	print("")
	print("========================================")
	print(" RESULTS: %d passed, %d failed" % [_passed, _failed])
	print("========================================")
	await process_frame
	quit(0 if _failed == 0 else 1)


func _run_test(test_name: String, test_callable: Callable) -> void:
	var errors_before: int = _failed
	test_callable.call()
	if _failed == errors_before:
		_passed += 1
		print("[PASS] " + test_name)
	else:
		print("[FAIL] " + test_name)


func _new_test_state() -> GameState:
	var state := GameState.new()
	state.gameplay_log = TestGameplayLog.new()
	return state


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed += 1
	push_error(message)


func _expect_approx(actual: float, expected: float, message: String) -> void:
	_expect(
		is_equal_approx(actual, expected),
		"%s (expected %s, got %s)" % [message, str(expected), str(actual)]
	)


func _test_initialization() -> void:
	var state := _new_test_state()
	_expect(state.resources.has(ResourceIds.HEAT), "Heat resource was not registered.")
	_expect(state.resources.has(ResourceIds.MATTER), "Matter resource was not registered.")
	_expect(state.resources.has(ResourceIds.ASH), "Ash resource was not registered.")
	_expect(state.generators.has("atomic_friction"), "Atomic Friction was not registered.")
	_expect(state.get_generator("atomic_friction") != null, "Atomic Friction could not be retrieved.")


func _test_resource_discovery_visibility() -> void:
	var state := _new_test_state()
	var essence_upgrade: Upgrade = state.get_upgrade("essence_influence")
	var matter_decay_upgrade: Upgrade = state.get_upgrade("loss_coefficient_refinement")
	var crystallization_upgrade: Upgrade = state.get_upgrade("crystallization_adaptation")
	var forge_unlock: Upgrade = state.get_upgrade("infernal_forge_unlock")
	_expect(essence_upgrade != null, "Essence Influence upgrade was not registered.")
	_expect(matter_decay_upgrade != null, "Matter decay refinement upgrade was not registered.")
	_expect(crystallization_upgrade != null, "Crystallization Adaptation upgrade was not registered.")
	_expect(forge_unlock != null, "Infernal Forge unlock upgrade was not registered.")
	if essence_upgrade == null or matter_decay_upgrade == null or crystallization_upgrade == null or forge_unlock == null:
		return

	_expect(not state.upgrade_system.is_upgrade_visible(matter_decay_upgrade), "Matter decay upgrade was visible before Matter discovery.")
	_expect(not state.upgrade_system.is_upgrade_visible(crystallization_upgrade), "Crystallization upgrade was visible before its mechanic was unlocked.")

	_expect(not state.is_resource_discovered(ResourceIds.MATTER), "Matter should begin undiscovered.")
	_expect(not state.is_resource_discovered(ResourceIds.ESSENCE), "Essence should begin undiscovered.")
	_expect(not state.upgrade_system.is_upgrade_visible(essence_upgrade), "Essence Influence was visible before Essence discovery.")

	state.record_resource_produced(ResourceIds.MATTER, 1.0)
	_expect(state.is_resource_discovered(ResourceIds.MATTER), "Producing Matter did not discover it.")
	_expect(state.upgrade_system.is_upgrade_visible(matter_decay_upgrade), "Matter decay upgrade did not become visible after Matter discovery.")
	_expect(not state.upgrade_system.is_upgrade_visible(essence_upgrade), "Discovering Matter incorrectly exposed Essence upgrades.")
	forge_unlock.level = 1
	_expect(state.upgrade_system.is_upgrade_visible(crystallization_upgrade), "Crystallization upgrade did not appear after its mechanic was unlocked.")

	state.record_resource_produced(ResourceIds.ESSENCE, 1.0)
	_expect(state.is_resource_discovered(ResourceIds.ESSENCE), "Producing Essence did not discover it.")
	_expect(not state.upgrade_system.is_upgrade_visible(essence_upgrade), "Essence Influence appeared before its technology was discovered.")
	state.eternal_flame_state.unlock_technology(EternalFlameState.LAVA_MITE_ESSENCE_TECHNOLOGY_ID)
	_expect(state.upgrade_system.is_upgrade_visible(essence_upgrade), "Essence Influence did not become visible after its technology was discovered.")

	state.reset_current_run()
	_expect(state.is_resource_discovered(ResourceIds.MATTER), "Matter discovery was lost on prestige reset.")
	_expect(state.is_resource_discovered(ResourceIds.ESSENCE), "Essence discovery was lost on prestige reset.")

	var save_manager := SaveManager.new()
	var save_data: Dictionary = save_manager.state_to_dictionary(state)
	_expect(save_data.has("discovered_resources"), "Save data did not include resource discoveries.")
	var restored_state := _new_test_state()
	_expect(save_manager.dictionary_to_state(restored_state, save_data, SaveManager.SAVE_VERSION), "Current-version save could not be restored.")
	_expect(restored_state.is_resource_discovered(ResourceIds.ESSENCE), "Essence discovery was not restored from save data.")

	# Legacy saves infer discoveries from lifetime statistics when no explicit dictionary exists.
	var legacy_data: Dictionary = save_data.duplicate(true)
	legacy_data.erase("discovered_resources")
	var legacy_state := _new_test_state()
	_expect(save_manager.dictionary_to_state(legacy_state, legacy_data, SaveManager.SAVE_VERSION - 1), "Legacy save could not be restored.")
	_expect(legacy_state.is_resource_discovered(ResourceIds.MATTER), "Legacy Matter discovery was not recovered from lifetime statistics.")
	_expect(legacy_state.is_resource_discovered(ResourceIds.ESSENCE), "Legacy Essence discovery was not recovered from lifetime statistics.")


func _test_essence_accumulation_penalty() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var essence_upgrade: Upgrade = state.get_upgrade("essence_accumulation_penalty")
	_expect(essence_upgrade != null, "Essence accumulation upgrade was not registered.")
	if essence_upgrade == null:
		return

	state.set_resource_amount(ResourceIds.ESSENCE, 1.0)
	simulation.update_automatic_upgrades()
	_expect(essence_upgrade.is_purchased(), "Essence accumulation effect did not auto-unlock when Essence became available.")

	var friction: Generator = state.get_generator("atomic_friction")
	var essence_modifier: Modifier = null
	for modifier in friction.modifiers:
		if modifier.id == "essence_accumulation_penalty":
			essence_modifier = modifier
			break
	_expect(essence_modifier != null, "Global Essence production penalty was not applied through the modifier pathway.")
	if essence_modifier == null:
		return

	_expect(
		essence_modifier.applies_to(ModifierTypes.PRODUCTION, ResourceIds.ESSENCE),
		"Essence accumulation penalty did not target Essence production."
	)
	_expect(
		not essence_modifier.applies_to(ModifierTypes.PRODUCTION, ResourceIds.HEAT),
		"Essence accumulation penalty incorrectly affected Heat production."
	)

	state.set_resource_amount(ResourceIds.ESSENCE, 100.0)
	var unmitigated_multiplier: float = essence_modifier.get_effective_multiplier(state, friction)
	_expect_approx(
		unmitigated_multiplier,
		1.0 / 1.9,
		"Essence accumulation penalty did not scale dynamically with held Essence."
	)

	state.set_resource_amount(ResourceIds.ESSENCE, 1000.0)
	_expect(simulation.buy_upgrade("essence_retention"), "Essence Retention could not be purchased.")
	_expect(simulation.buy_upgrade("essence_stabilization"), "Essence Stabilization could not be purchased after Retention.")
	state.set_resource_amount(ResourceIds.ESSENCE, 100.0)
	var mitigated_multiplier: float = essence_modifier.get_effective_multiplier(state, friction)
	_expect(
		mitigated_multiplier > unmitigated_multiplier and mitigated_multiplier < 1.0,
		"Essence mitigation upgrades should weaken, but not eliminate, the accumulation penalty."
	)


func _test_cycle_generator_activation_level_configuration() -> void:
	var state := _new_test_state()
	var forge: Generator = state.get_generator("infernal_forge")
	var crucible: Generator = state.get_generator("relic_shard_extractor")
	if forge == null:
		_expect(false, "Infernal Forge is missing.")
		return
	if crucible == null:
		_expect(false, "Relic Crucible is missing.")
		return

	for mode in forge.definition.operation_modes:
		_expect(mode.increase_level_on_activation, "Forge mode '%s' should increase its level." % mode.id)

	_expect(
		crucible.definition.display_name == "Relic Crucible",
		"Relic machine display name was not updated."
	)
	var found_extraction_mode: bool = false
	for mode in crucible.definition.operation_modes:
		# The "normal" mode is the extractor's shard-extraction operation.
		var is_extraction_mode: bool = mode.id == "normal"
		found_extraction_mode = found_extraction_mode or is_extraction_mode
		_expect(
			not mode.increase_level_on_activation,
			"Relic Crucible mode '%s' should not level up when a cycle starts." % mode.id
		)
	_expect(found_extraction_mode, "Relic Crucible's normal extraction mode is missing.")
	_expect(crucible.level == 1, "Relic Crucible should start at level 1 for extraction.")
	_expect(not crucible.definition.scale_rates_with_level, "Crucible recipe rates should not scale with machine level.")
	_expect(crucible.definition.level_upgrade_enabled, "Relic Crucible level upgrades should be enabled.")


func _test_relic_crucible_level_upgrades() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var crucible: Generator = state.get_generator("relic_shard_extractor")
	if crucible == null:
		_expect(false, "Relic Crucible is missing.")
		return

	var forge_mode: GeneratorOperationMode = crucible.definition.operation_modes[3]
	_expect_approx(simulation.get_effective_relic_critical_chance(crucible, forge_mode), 0.05, "Level 1 should use the 5% base critical chance.")
	_expect_approx(simulation.get_generator_level_upgrade_cost(crucible), 100.0, "First Crucible level upgrade should cost 100 Matter.")
	_expect(not simulation.can_buy_generator_level("relic_shard_extractor"), "Crucible upgrade should be unavailable without enough Matter.")
	state.set_resource_amount(ResourceIds.MATTER, 100.0)
	_expect(simulation.can_buy_generator_level("relic_shard_extractor"), "Affordable Crucible upgrade was rejected.")
	_expect(simulation.buy_generator_level("relic_shard_extractor", "regression_test"), "Crucible level upgrade failed.")
	_expect(crucible.level == 2, "Crucible level upgrade did not increase the level exactly once.")
	_expect_approx(state.get_resource_amount(ResourceIds.MATTER), 0.0, "Crucible upgrade did not consume its exact Matter cost.")
	_expect_approx(simulation.get_generator_level_upgrade_cost(crucible), 125.0, "Second Crucible level upgrade cost did not scale by 1.25.")
	_expect_approx(simulation.get_effective_relic_critical_chance(crucible, forge_mode), 0.055, "Level 2 should provide a 5.5% critical chance.")

	# Cycle inputs and shard outputs remain fixed as the Crucible levels up.
	state.set_resource_amount(ResourceIds.MATTER, 110.0)
	crucible.set_operation_mode("normal")
	var level_before_cycle := crucible.level
	_expect(simulation.buy_generator("relic_shard_extractor", "regression_test"), "Crucible extraction cycle failed to start.")
	_expect(crucible.level == level_before_cycle, "Starting an extraction cycle changed the Crucible level.")
	_expect_approx(crucible.get_input_consumption_per_second(crucible.get_active_inputs()[0], state), 100.0 / 60.0, "Extraction Matter draw changed with Crucible level.")
	simulation.complete_cycle(crucible)
	var shard_quantity := 0
	for entry in state.relic_manager.inventory:
		if str(entry.get("item_id", "")) == "relic_shard":
			shard_quantity += int(entry.get("quantity", 0))
	_expect(shard_quantity == 1, "Extraction should produce one shard per cycle regardless of Crucible level.")


func _test_environmental_thresholds() -> void:
	var state := _new_test_state()
	var heat_threshold: float = state.realm_effects.heat_leak_threshold
	var matter_threshold: float = state.realm_effects.matter_decay_threshold

	state.set_resource_amount(ResourceIds.HEAT, heat_threshold)
	state.set_resource_amount(ResourceIds.MATTER, matter_threshold)
	_expect_approx(state.get_heat_leak_per_second(), 0.0, "Heat leak should be zero at the threshold.")
	_expect_approx(state.get_matter_decay_per_second(), 0.0, "Matter decay should be zero at the threshold.")

	state.set_resource_amount(ResourceIds.HEAT, heat_threshold * 2.0)
	state.set_resource_amount(ResourceIds.MATTER, matter_threshold * 2.0)
	_expect(state.get_heat_leak_per_second() > 0.0, "Heat leak should become positive above its threshold.")
	_expect(state.get_matter_decay_per_second() > 0.0, "Matter decay should become positive above its threshold.")


func _test_matter_decay_statistics() -> void:
	for offline in [false, true]:
		_assert_matter_decay_statistics(0.1, offline)


func _test_matter_decay_clamped_statistics() -> void:
	for offline in [false, true]:
		_assert_matter_decay_statistics(1000000.0, offline)


func _assert_matter_decay_statistics(delta: float, offline: bool) -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	state.track_gameplay_interval_statistics = not offline
	if offline:
		state.simulation_statistics = ResourceStatistics.new()
	var initial_matter: float = state.realm_effects.matter_decay_threshold * 2.0
	var initial_heat: float = 25.0
	state.set_resource_amount(ResourceIds.MATTER, initial_matter)
	state.set_resource_amount(ResourceIds.HEAT, initial_heat)
	var expected_decay: float = minf(state.get_matter_decay_per_second() * delta, initial_matter)
	_expect(expected_decay > 0.0, "The decay fixture must exercise positive Matter loss.")
	simulation.apply_matter_decay(delta)
	_expect_approx(state.get_resource_amount(ResourceIds.MATTER), initial_matter - expected_decay, "Matter balance no longer follows the existing decay formula.")
	_expect_approx(state.get_resource_amount(ResourceIds.HEAT), initial_heat + expected_decay, "Decay must convert removed Matter to Heat exactly once.")
	_expect_approx(state.total_matter_decayed_this_prestige, expected_decay, "Decay changed the current-realm Smash reward counter.")
	var counters: Array[ResourceStatistics] = [state.resource_statistics, state.current_run_statistics]
	if offline:
		counters.append(state.simulation_statistics)
	for statistics in counters:
		_expect_approx(statistics.get_total_lost(ResourceIds.MATTER), expected_decay, "Matter loss statistics differ from actual decay.")
		_expect_approx(statistics.get_total_produced(ResourceIds.HEAT), expected_decay, "Decay Heat production was counted more or less than once.")
		_expect_approx(statistics.get_total_matter_decayed(), expected_decay, "Matter-decayed aggregate was not recorded for every statistics scope.")
		_expect_approx(statistics.get_total_consumed(ResourceIds.MATTER), 0.0, "Environmental decay must not count as generator consumption.")
		var restored := ResourceStatistics.new()
		restored.from_dictionary(statistics.to_dictionary())
		_expect_approx(restored.get_total_matter_decayed(), expected_decay, "Matter-decayed aggregate did not survive serialization.")
		_expect_approx(restored.get_total_produced(ResourceIds.HEAT), expected_decay, "Heat-production total did not survive serialization.")

	# At the threshold no additional decay, Heat, or reward should be recorded.
	state.set_resource_amount(ResourceIds.MATTER, state.realm_effects.matter_decay_threshold)
	simulation.apply_matter_decay(delta)
	_expect_approx(state.get_resource_amount(ResourceIds.HEAT), initial_heat + expected_decay, "Threshold-only Matter incorrectly produced Heat.")
	_expect_approx(state.total_matter_decayed_this_prestige, expected_decay, "Threshold-only Matter increased the Smash counter.")
	for statistics in counters:
		_expect_approx(statistics.get_total_matter_decayed(), expected_decay, "Zero decay changed the Matter-decayed aggregate.")


func _benchmark_comparison_fixture() -> Dictionary:
	return {
		"resources": {"heat": 10.0},
		"generators": {"test_generator": {"level": 2, "cycle_progress": 1.0, "operating": true, "cycle_active": false}},
		"overflow": 4.0,
		"statistics": {
			"heat": {"total_produced": 10.0, "total_consumed": 0.0, "total_lost": 0.0, "highest_amount": 10.0},
			"_total_overflow": 4.0,
			"_total_matter_decayed": 10.0
		}
	}


func _test_offline_benchmark_comparison() -> void:
	var baseline: Dictionary = _benchmark_comparison_fixture()
	_expect_approx(OfflineComparison.get_max_deviation(baseline, baseline.duplicate(true)), 0.0, "Identical snapshots should have zero deviation, including numeric aggregates.")
	var comparison: Dictionary = baseline.duplicate(true)
	comparison["statistics"]["_total_matter_decayed"] = 15.0
	_expect_approx(OfflineComparison.get_max_deviation(baseline, comparison), 50.0, "Matter-decayed aggregate differences were ignored.")
	comparison = baseline.duplicate(true)
	comparison["statistics"]["_total_overflow"] = 8.0
	_expect_approx(OfflineComparison.get_max_deviation(baseline, comparison), 100.0, "Overflow aggregate differences were ignored.")
	comparison = baseline.duplicate(true)
	comparison["statistics"]["heat"]["total_produced"] = 12.0
	_expect_approx(OfflineComparison.get_max_deviation(baseline, comparison), 20.0, "Resource-flow differences were ignored.")
	comparison = baseline.duplicate(true)
	comparison["resources"]["heat"] = 11.0
	_expect_approx(OfflineComparison.get_max_deviation(baseline, comparison), 10.0, "Final resource differences were ignored.")
	comparison = baseline.duplicate(true)
	comparison["generators"]["test_generator"]["level"] = 3
	_expect_approx(OfflineComparison.get_max_deviation(baseline, comparison), 50.0, "Generator level differences were ignored.")
	comparison = baseline.duplicate(true)
	comparison["generators"]["test_generator"]["cycle_progress"] = 2.0
	_expect_approx(OfflineComparison.get_max_deviation(baseline, comparison), 100.0, "Cycle progress differences were ignored.")
	for flag in ["operating", "cycle_active"]:
		comparison = baseline.duplicate(true)
		comparison["generators"]["test_generator"][flag] = not bool(comparison["generators"]["test_generator"][flag])
		_expect_approx(OfflineComparison.get_max_deviation(baseline, comparison), 100.0, "Generator state flag differences were ignored.")
	comparison = baseline.duplicate(true)
	comparison["statistics"]["ash"] = {"total_produced": 2.0}
	_expect_approx(OfflineComparison.get_max_deviation(baseline, comparison), 200.0, "Comparison-only resource flow was ignored.")
	_expect_approx(OfflineComparison.get_max_deviation(comparison, baseline), 100.0, "Baseline-only resource flow was ignored.")
	comparison = baseline.duplicate(true)
	comparison["statistics"]["heat"] = "invalid"
	_expect(not is_finite(OfflineComparison.get_max_deviation(baseline, comparison)), "Invalid statistic data must not report zero deviation.")
	comparison = baseline.duplicate(true)
	comparison["resources"]["heat"] = NAN
	_expect(not is_finite(OfflineComparison.get_max_deviation(baseline, comparison)), "Non-finite data must invalidate a comparison.")


func _test_offline_benchmark_statistics_output() -> void:
	var baseline: Dictionary = _benchmark_comparison_fixture()
	var comparison: Dictionary = baseline.duplicate(true)
	comparison["statistics"]["_total_matter_decayed"] = 15.0
	comparison["statistics"]["ash"] = {"total_produced": 2.0}
	var lines: Array[String] = OfflineComparison.format_statistics_comparison(baseline["statistics"], comparison["statistics"])
	_expect(lines.size() == 4, "Statistics output should contain both resources and both aggregates.")
	_expect(lines[0].contains("heat produced") and lines[0].contains("consumed") and lines[0].contains("lost"), "Resource flow output is incomplete.")
	_expect(lines[1].contains("_total_overflow:"), "Numeric overflow output is missing.")
	_expect(lines[2].contains("_total_matter_decayed:") and lines[2].contains("15"), "Numeric Matter-decay output is missing.")
	_expect(lines[3].contains("ash produced") and lines[3].contains("2"), "Comparison-only resource output is missing.")


func _test_purchase_rejects_insufficient_resources() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var generator: Generator = state.get_generator("atomic_friction")
	if generator == null:
		_expect(false, "Atomic Friction is missing.")
		return

	var previous_level: int = generator.level
	var cost: float = generator.get_cost(state)
	state.set_resource_amount(generator.definition.cost_resource_id, maxf(cost - 1.0, 0.0))
	var previous_amount: float = state.get_resource_amount(generator.definition.cost_resource_id)

	_expect(not simulation.buy_generator("atomic_friction"), "Purchase should fail when resources are insufficient.")
	_expect(generator.level == previous_level, "Failed purchase changed the generator level.")
	_expect_approx(
		state.get_resource_amount(generator.definition.cost_resource_id),
		previous_amount,
		"Failed purchase changed the resource balance."
	)


func _test_successful_generator_purchase() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var generator: Generator = state.get_generator("atomic_friction")
	if generator == null:
		_expect(false, "Atomic Friction is missing.")
		return

	var previous_level: int = generator.level
	var cost: float = generator.get_cost(state)
	state.set_resource_amount(generator.definition.cost_resource_id, cost + 10.0)

	var purchased: bool = simulation.buy_generator("atomic_friction", "regression_test")
	_expect(purchased, "Affordable generator purchase was rejected.")
	_expect(generator.level == previous_level + 1, "Successful purchase did not add exactly one level.")
	_expect_approx(
		state.get_resource_amount(generator.definition.cost_resource_id),
		10.0,
		"Successful purchase did not deduct the exact displayed cost."
	)

	var logger: TestGameplayLog = state.gameplay_log
	_expect(not logger.events.is_empty(), "Purchase event was not sent to the logger.")
	if not logger.events.is_empty():
		_expect(
			logger.events.back().get("event", "") == "generator_level_purchased",
			"Purchase logged the wrong event type."
		)


func _test_cycle_mode_without_level_increase() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var generator: Generator = state.get_generator("relic_shard_extractor")
	if generator == null:
		_expect(false, "Relic Shard Extractor is missing.")
		return

	var mode := generator.get_operation_mode()
	if mode == null:
		_expect(false, "Extractor operation mode is missing.")
		return
	mode.increase_level_on_activation = false
	generator.level = 2
	var cost: float = generator.get_cost(state)
	state.set_resource_amount(generator.definition.cost_resource_id, cost + 10.0)

	_expect(simulation.buy_generator("relic_shard_extractor", "regression_test"), "Non-leveling cycle activation was rejected.")
	_expect(generator.level == 2, "Non-leveling cycle activation changed the generator level.")
	_expect(generator.cycle_active, "Non-leveling cycle mode did not activate its cycle.")
	_expect_approx(
		state.get_resource_amount(generator.definition.cost_resource_id),
		10.0,
		"Non-leveling cycle activation did not deduct its normal cost."
	)
	var logger: TestGameplayLog = state.gameplay_log
	_expect(
		not logger.events.is_empty() and logger.events.back().get("event", "") == "generator_cycle_activated",
		"Non-leveling cycle activation was not logged distinctly."
	)


func _test_cycle_auto_run() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var extractor: Generator = state.get_generator("relic_shard_extractor")
	var forge: Generator = state.get_generator("infernal_forge")
	_expect(extractor != null, "Relic Shard Extractor was unavailable for the auto-run test.")
	if extractor == null:
		return
	extractor.unlocked = true
	extractor.level = maxi(extractor.level, 1)
	_expect(not extractor.auto_run_cycles, "Cycle auto-run should default to OFF.")
	if forge != null:
		forge.unlocked = true
		forge.level = maxi(forge.level, 1)
		forge.auto_run_cycles = true
		simulation.update_cycle_generator(forge, 1.0, false)
		_expect(not forge.cycle_active, "Infernal Forge auto-run activated without its own shop unlock.")
	_expect(
		state.eternal_flame_upgrade_manager.get_upgrade(
			"unlock_cycle_auto_run_relic_shard_extractor"
		) != null,
		"Relic Shard Extractor Auto-run was not registered in the Eternal Flame shop."
	)
	_expect(
		state.eternal_flame_upgrade_manager.get_upgrade(
			"unlock_cycle_auto_run_infernal_forge"
		) != null,
		"Infernal Forge Auto-run was not registered in the Eternal Flame shop."
	)
	simulation.update_cycle_generator(extractor, 1.0, false)
	_expect(not extractor.cycle_active, "Cycle auto-run started before its permanent shop unlock.")
	state.eternal_flame_state.unlock_technology(
		EternalFlameState.get_cycle_auto_run_technology_id(extractor.definition.id)
	)
	extractor.auto_run_cycles = true
	if forge != null:
		simulation.update_cycle_generator(forge, 1.0, false)
		_expect(not forge.cycle_active, "Unlocking extractor auto-run also unlocked Forge auto-run.")
	for resource in state.get_resources().values():
		state.set_resource_amount(resource.definition.id, 1000000000000.0)
	var cycle_duration: float = extractor.get_cycle_duration()
	# Two full cycles plus five seconds should complete two batches and begin
	# progressing through a third during offline catch-up.
	simulation.update_cycle_generator(extractor, cycle_duration * 2.0 + 5.0, true)
	_expect(extractor.cycle_active, "Auto-run did not start the next cycle during offline catch-up.")
	_expect_approx(extractor.cycle_progress, 5.0, "Offline auto-run did not preserve the time remaining after repeated cycle completions.")

func _test_generator_production() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var generator: Generator = state.get_generator("atomic_friction")
	if generator == null:
		_expect(false, "Atomic Friction is missing.")
		return

	var starting_heat: float = 100.0
	state.set_resource_amount(ResourceIds.HEAT, starting_heat)
	simulation.produce_outputs(generator, 1.0, 1.0)

	_expect(
		state.get_resource_amount(ResourceIds.HEAT) > starting_heat,
		"Atomic Friction did not increase Heat during a one-second production step."
	)
	_expect(
		float(state.gameplay_interval_produced.get(ResourceIds.HEAT, 0.0)) > 0.0,
		"Produced Heat was not recorded in interval statistics."
	)


func _test_interval_statistics() -> void:
	var state := _new_test_state()
	state.record_resource_produced(ResourceIds.HEAT, 12.0)
	state.record_resource_consumed(ResourceIds.MATTER, 3.0)
	state.record_resource_lost(ResourceIds.ASH, 2.0)

	var snapshot: Dictionary = state.take_gameplay_interval_statistics()
	_expect_approx(float(snapshot["produced"].get(ResourceIds.HEAT, 0.0)), 12.0, "Produced total was incorrect.")
	_expect_approx(float(snapshot["consumed"].get(ResourceIds.MATTER, 0.0)), 3.0, "Consumed total was incorrect.")
	_expect_approx(float(snapshot["lost"].get(ResourceIds.ASH, 0.0)), 2.0, "Lost total was incorrect.")
	_expect(state.gameplay_interval_produced.is_empty(), "Produced counters were not cleared.")
	_expect(state.gameplay_interval_consumed.is_empty(), "Consumed counters were not cleared.")
	_expect(state.gameplay_interval_lost.is_empty(), "Lost counters were not cleared.")


func _test_realm_reset() -> void:
	var state := _new_test_state()
	state.set_resource_amount(ResourceIds.HEAT, 1234.0)
	state.set_resource_amount(ResourceIds.MATTER, 56.0)
	state.gameplay_interval_produced[ResourceIds.HEAT] = 10.0
	var previous_run_index: int = state.gameplay_realm_run_index

	state.reset_current_run()

	_expect(state.gameplay_realm_run_index == previous_run_index + 1, "Realm run index did not advance.")
	_expect_approx(state.get_resource_amount(ResourceIds.HEAT), 0.0, "Heat was not reset.")
	_expect_approx(state.get_resource_amount(ResourceIds.MATTER), 0.0, "Matter was not reset.")
	_expect(state.gameplay_interval_produced.is_empty(), "Interval statistics survived the realm reset.")


func _test_prestige_planning_transition() -> void:
	var state := _new_test_state()
	var prestige := PrestigeSystem.new()
	var forge: Generator = state.get_generator("infernal_forge")
	if forge == null:
		_expect(false, "Infernal Forge is missing.")
		return
	forge.level = 1
	state.realm_stabilized = false
	state.realm_configuration.assign_flame("stability")
	state.set_resource_amount(ResourceIds.CRYSTALLIZED_FLAME, 1.0)
	state.set_resource_amount(ResourceIds.HEAT, 1234.0)
	state.set_resource_amount(ResourceIds.MATTER, 56.0)
	state.current_run_statistics.update_highest(ResourceIds.HEAT, 1234.0)
	state.current_run_statistics.update_highest(ResourceIds.MATTER, 56.0)
	var previous_run_index: int = state.gameplay_realm_run_index

	var gain: float = prestige.smash(state, 42.0)
	_expect_approx(gain, 1.0, "Smash did not award the expected Eternal Flame.")
	_expect(state.prestige_planning, "Smash did not enter prestige planning.")
	_expect(state.realm_configuration.get_assigned_flames() == 0, "Smash did not clear the previous realm allocation.")
	_expect(not state.realm_configuration.locked, "Realm configuration should be editable during planning.")
	_expect(state.eternal_flame_state.prestige_count == 1, "Prestige count did not increment.")
	_expect(state.gameplay_realm_run_index == previous_run_index, "Smash reset the run before planning.")
	_expect_approx(state.get_resource_amount(ResourceIds.HEAT), 1234.0, "Old run resources were reset during planning.")
	_expect_approx(float(state.last_prestige_report.get("survival_seconds", 0.0)), 42.0, "Report did not capture survival time.")
	_expect_approx(float(state.last_prestige_report.get("peak_heat", 0.0)), 1234.0, "Report did not capture peak Heat.")
	_expect(state.eternal_flame_state.get_upgrade_level("eternal_furnace") == 0, "Eternal Furnace should remain a currency-purchased realm upgrade.")
	_expect(state.eternal_flame_state.get_upgrade_level("accelerated_friction") == 1, "First-prestige starting-level milestone was not granted.")

	var save_manager := SaveManager.new()
	var save_data: Dictionary = save_manager.state_to_dictionary(state)
	var restored_state := _new_test_state()
	_expect(save_manager.dictionary_to_state(restored_state, save_data, 6), "Could not restore a saved planning state.")
	_expect(restored_state.prestige_planning, "Planning state was not persisted.")
	_expect_approx(
		float(restored_state.last_prestige_report.get("eternal_flames_gained", 0.0)),
		1.0,
		"Prestige report was not persisted."
	)

	_expect_approx(prestige.smash(state, 42.0), 0.0, "Repeated Smash awarded Eternal Flames during planning.")
	var began_next_realm: bool = prestige.begin_next_realm(state)
	_expect(began_next_realm, "Could not begin the next realm from planning.")
	_expect(not state.prestige_planning, "Next realm remained in planning state.")
	_expect(state.realm_configuration.locked, "Flame allocation was not locked after planning ended.")
	_expect(state.gameplay_realm_run_index == previous_run_index + 1, "Next realm did not reset exactly once.")
	_expect_approx(state.get_resource_amount(ResourceIds.HEAT), 0.0, "Next realm did not reset Heat.")
	_expect_approx(state.get_resource_amount(ResourceIds.MATTER), 0.0, "Next realm did not reset Matter.")
	_expect(not prestige.begin_next_realm(state), "Next realm could be initialized twice.")


func _test_current_realm_environmental_bonuses() -> void:
	var state := _new_test_state()
	var prestige := PrestigeSystem.new()
	var forge: Generator = state.get_generator("infernal_forge")
	if forge == null:
		_expect(false, "Infernal Forge is missing for environmental reward test.")
		return
	forge.level = 1
	state.set_resource_amount(ResourceIds.CRYSTALLIZED_FLAME, 100.0)

	_expect_approx(prestige.calculate_eternal_flame_gain(state), 100.0, "Environmental bonuses should start at x1.00.")

	state.total_overflow_this_prestige = 100.0
	_expect_approx(state.get_heat_overflow_bonus(), 1.2, "Heat overflow bonus should use current realm overflow.")
	_expect_approx(prestige.calculate_eternal_flame_gain(state), 120.0, "Heat overflow should affect the current Smash.")

	state.total_matter_decayed_this_prestige = 1000.0
	_expect_approx(state.get_matter_decay_bonus(), 1.3, "Matter decay bonus should match Heat's logarithmic strength.")
	_expect_approx(state.get_combined_environmental_reward_multiplier(), 1.56, "Environmental bonuses should multiply together.")
	_expect_approx(prestige.calculate_eternal_flame_gain(state), 156.0, "Combined environmental bonuses were not applied to Smash.")

	var save_manager := SaveManager.new()
	var save_data: Dictionary = save_manager.state_to_dictionary(state)
	var restored_state := _new_test_state()
	_expect(save_manager.dictionary_to_state(restored_state, save_data, 7), "Could not restore current-realm environmental totals.")
	_expect_approx(restored_state.total_overflow_this_prestige, 100.0, "Heat overflow total did not persist.")
	_expect_approx(restored_state.total_matter_decayed_this_prestige, 1000.0, "Matter decay total did not persist.")
	_expect_approx(PrestigeSystem.new().calculate_eternal_flame_gain(restored_state), 156.0, "Restored environmental bonuses changed the Smash preview.")
	var actual_gain: float = PrestigeSystem.new().smash(restored_state, 1.0)
	_expect_approx(actual_gain, 156.0, "Actual Smash reward did not match the environmental bonus preview.")
	_expect_approx(float(restored_state.last_prestige_report.get("environmental_multiplier", 1.0)), 1.56, "Smash report omitted the combined environmental multiplier.")

	var simulation := Simulation.new(state)
	state.total_matter_decayed_this_prestige = 0.0
	var matter_threshold: float = state.realm_effects.matter_decay_threshold
	state.set_resource_amount(ResourceIds.MATTER, matter_threshold * 2.0)
	var matter_before: float = state.get_resource_amount(ResourceIds.MATTER)
	simulation.apply_matter_decay(1.0)
	var actual_decay: float = matter_before - state.get_resource_amount(ResourceIds.MATTER)
	_expect(actual_decay > 0.0, "Environmental Matter decay did not remove Matter in the test.")
	_expect_approx(state.total_matter_decayed_this_prestige, actual_decay, "Matter bonus counter did not match actual Matter lost to decay.")
	_expect_approx(state.resource_statistics.get_total_matter_decayed(), actual_decay, "Lifetime Matter decay statistic did not track actual decay.")
	var decay_save_data: Dictionary = save_manager.state_to_dictionary(state)
	var decay_restored_state := _new_test_state()
	_expect(save_manager.dictionary_to_state(decay_restored_state, decay_save_data, 7), "Could not restore lifetime Matter decay statistics.")
	_expect_approx(decay_restored_state.resource_statistics.get_total_matter_decayed(), actual_decay, "Lifetime Matter decay statistic did not persist through save/load.")

	state.reset_current_run()
	_expect_approx(state.total_overflow_this_prestige, 0.0, "Heat overflow total carried into the next realm.")
	_expect_approx(state.total_matter_decayed_this_prestige, 0.0, "Matter decay total carried into the next realm.")


func _test_automatic_progression_rewards() -> void:
	var state := _new_test_state()
	var flame_state: EternalFlameState = state.eternal_flame_state
	var manager: EternalFlameUpgradeManager = state.eternal_flame_upgrade_manager

	# Prestige 3 grants the first three starting-level milestones without
	# requiring purchases or consuming Eternal Flames.
	flame_state.prestige_count = 3
	flame_state.eternal_flame = 3.0
	flame_state.total_crystallized_flame = 100.0
	flame_state.spent_flames = 2.0
	manager.apply_automatic_progression_rewards(flame_state)

	_expect(flame_state.get_upgrade_level("accelerated_friction") == 3, "Prestige 3 did not grant 15 starting AF levels.")
	_expect(flame_state.get_upgrade_level("accelerated_agitation") == 2, "Prestige 3 did not grant 10 starting MA levels.")
	_expect(flame_state.get_upgrade_level("established_colony") == 1, "Prestige 3 did not grant the first LMC starting-level milestone.")
	_expect(flame_state.get_upgrade_level("accelerated_condensation") == 0, "Condensation starting levels were granted before their milestone.")
	_expect(flame_state.get_upgrade_level("unlock_generator_automation_atomic_friction") == 0, "AF automation unlocked before its lifetime-EF threshold.")
	_expect_approx(flame_state.spent_flames, 2.0, "Automatic starting-level rewards consumed Eternal Flames.")
	_expect(not manager.can_purchase("accelerated_friction", flame_state, state.realm_configuration), "Starting-level milestones were still purchasable with Eternal Flames.")

	# Higher progress grants the appropriate level and the AF autobuyer once
	# both its prestige and lifetime-EF requirements are satisfied.
	flame_state.prestige_count = 5
	flame_state.eternal_flame = 8.0
	manager.apply_automatic_progression_rewards(flame_state)
	_expect(flame_state.get_upgrade_level("accelerated_friction") == 5, "Prestige 5 did not max AF starting levels.")
	_expect(flame_state.get_upgrade_level("unlock_generator_automation_atomic_friction") == 1, "AF automation was not granted at its milestone.")
	_expect(flame_state.is_technology_unlocked("generator_automation_atomic_friction"), "AF automation milestone did not unlock its technology.")
	_expect_approx(flame_state.spent_flames, 2.0, "Automatic automation rewards consumed Eternal Flames.")
	_expect(not manager.can_purchase("unlock_generator_automation_atomic_friction", flame_state, state.realm_configuration), "Automatically granted automation remained purchasable.")

	# Reapplying milestones is idempotent, and reset applies the earned starting
	# levels to the actual generators rather than adding them cumulatively.
	manager.apply_automatic_progression_rewards(flame_state)
	state.reset_current_run()
	_expect(state.get_generator("atomic_friction").level == 25, "AF did not start at its milestone level.")
	_expect(state.get_generator("molecular_agitation").level == 20, "MA did not start at its milestone level.")
	_expect(state.get_generator("lava_mite_colony").level == 9, "LMC did not start at its milestone level.")
	_expect(state.get_generator("thermal_furnace").level == 6, "Infernal Condensation did not start at its milestone level.")


func _test_brazier_upgrade_unlocks() -> void:
	var state := _new_test_state()
	state.eternal_flame_state.eternal_flame = 200.0
	var manager: EternalFlameUpgradeManager = state.eternal_flame_upgrade_manager
	var progression: Array[Dictionary] = [
		{"upgrade": "brazier_intensity", "technology": "brazier_intensity", "cost": 1},
		{"upgrade": "brazier_stability", "technology": "brazier_stability", "cost": 4},
		{"upgrade": "brazier_density", "technology": "brazier_density", "cost": 10},
		{"upgrade": "brazier_integrity", "technology": "brazier_integrity", "cost": 20},
		{"upgrade": "brazier_resonance", "technology": "brazier_resonance", "cost": 35}
	]
	for entry in progression:
		var upgrade_id: String = str(entry["upgrade"])
		var technology_id: String = str(entry["technology"])
		_expect(
			manager.get_upgrade_cost(upgrade_id, state.eternal_flame_state) == int(entry["cost"]),
			"Unexpected Eternal Flame cost for " + upgrade_id + "."
		)
		_expect(
			manager.purchase(upgrade_id, state.eternal_flame_state, state.realm_configuration),
			"Could not purchase " + upgrade_id + "."
		)
		_expect(
			state.eternal_flame_state.is_technology_unlocked(technology_id),
			"Purchase did not permanently unlock " + technology_id + "."
		)
		_expect(
			state.eternal_flame_state.get_upgrade_level(upgrade_id) == 1,
			"Purchase did not set the permanent upgrade level for " + upgrade_id + "."
		)


func _test_relic_inventory_equipment_and_save() -> void:
	var state := _new_test_state()
	state.eternal_flame_state.eternal_flame = 100.0
	var purchased := state.eternal_flame_upgrade_manager.purchase("reliquary", state.eternal_flame_state, state.realm_configuration)
	_expect(purchased, "Reliquary purchase failed.")
	state.relic_manager.ensure_starter_relic()
	_expect(state.relic_manager.inventory.size() == 1, "Reliquary did not grant exactly one starter relic.")
	var starter_relic: Dictionary = state.relic_manager.inventory[0]
	var starter_definition: Dictionary = state.relic_manager.get_relic_definition(starter_relic)
	_expect(
		str(starter_definition.get("effect_id", "")) == "heat_reservoir_boost",
		"Starter relic should guarantee the Heat Reservoir effect."
	)
	var starter_roll := float(starter_relic.get("rolled_value", 0.0))
	_expect(
		starter_roll >= 0.50 and starter_roll <= 0.80,
		"Starter Heat Reservoir roll should stay within the Common tier range."
	)
	var relic_id := str(starter_relic.get("instance_id", ""))
	_expect(state.relic_manager.equip_relic("atomic_friction", relic_id, state), "Starter relic could not be equipped.")
	state.rebuild_relic_modifiers()
	var generator: Generator = state.get_generator("atomic_friction")
	var relic_modifier_found := false
	for modifier in generator.modifiers:
		if modifier.id == "relic:" + relic_id:
			relic_modifier_found = true
	for sensitivity in generator.modifier_sensitivities:
		if sensitivity.source_upgrade_id == "relic:" + relic_id:
			relic_modifier_found = true
	_expect(relic_modifier_found, "Equipping a relic did not add its effect to the generator.")
	var before_save: Dictionary = SaveManager.new().state_to_dictionary(state)
	var loaded_state := _new_test_state()
	var save_manager := SaveManager.new()
	var loaded := save_manager.dictionary_to_state(loaded_state, before_save, 7)
	_expect(loaded, "Relic save data could not be loaded.")
	_expect(loaded_state.relic_manager.inventory.size() == 1, "Relic inventory did not survive a save/load round trip.")
	_expect(loaded_state.relic_manager.get_equipped_relic_id("atomic_friction") != "", "Equipped relic did not survive a save/load round trip.")
	var loaded_modifier_found := false
	for modifier in loaded_state.get_generator("atomic_friction").modifiers:
		if modifier.id.begins_with("relic:"):
			loaded_modifier_found = true
	_expect(loaded_modifier_found, "Relic modifier was not rebuilt after loading.")

	# Startup rebuilds upgrade effects after loading. That pass clears all
	# generator modifiers, so it must also restore the saved relic effects.
	Simulation.new(loaded_state).rebuild_upgrade_effects()
	var modifier_after_upgrade_rebuild := false
	for modifier in loaded_state.get_generator("atomic_friction").modifiers:
		if modifier.id.begins_with("relic:"):
			modifier_after_upgrade_rebuild = true
	for sensitivity in loaded_state.get_generator("atomic_friction").modifier_sensitivities:
		if sensitivity.source_upgrade_id.begins_with("relic:"):
			modifier_after_upgrade_rebuild = true
	_expect(
		modifier_after_upgrade_rebuild,
		"Rebuilding upgrade effects removed equipped relic effects instead of restoring them."
	)

	loaded_state.reset_current_run()
	_expect(loaded_state.relic_manager.get_equipped_relic_id("atomic_friction") != "", "Realm reset incorrectly removed equipped relics.")
	var reset_modifier_found := false
	var reset_generator: Generator = loaded_state.get_generator("atomic_friction")
	for modifier in reset_generator.modifiers:
		if modifier.id.begins_with("relic:"):
			reset_modifier_found = true
	for sensitivity in reset_generator.modifier_sensitivities:
		if sensitivity.source_upgrade_id.begins_with("relic:"):
			reset_modifier_found = true
	_expect(reset_modifier_found, "Equipped relic effect was not restored after realm reset.")




func _test_relic_shard_extractor_modes() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var generator: Generator = state.get_generator("relic_shard_extractor")
	_expect(generator != null, "Relic Shard Extractor was not registered.")
	if generator == null:
		return
	_expect(generator.definition.operation_modes.size() == 5, "Extractor should expose exactly five operation modes.")
	var expected_modes := ["normal", "recycle_relic", "combine_shards", "forge_relic", "forge_greater_relic"]
	for index in range(expected_modes.size()):
		_expect(
			generator.definition.operation_modes[index].id == expected_modes[index],
			"Extractor mode order or ID was incorrect at index %d." % index
		)
	var standard_mode: GeneratorOperationMode = generator.definition.operation_modes[3]
	var greater_mode: GeneratorOperationMode = generator.definition.operation_modes[4]
	_expect(standard_mode.completion_random_relic_tier == 1, "Standard forge should produce tier 1 relics.")
	_expect(greater_mode.completion_random_relic_tier == 2, "Greater forge should produce tier 2 relics.")
	_expect(state.relic_manager.get_stackable_item_definition("greater_relic_shard").size() > 0, "Greater Relic Shard item is missing.")
	_expect(standard_mode.crafting_input_requirements.size() == 1, "Standard forging should require one ingredient stack.")
	_expect(greater_mode.crafting_input_requirements[0].get("item_id", "") == "greater_relic_shard", "Higher-tier forging should require Greater Relic Shards.")

	# Recycling consumes the explicitly loaded relic and returns a fixed shard amount.
	generator.set_operation_mode("recycle_relic")
	var recycled_relic_id := state.relic_manager.add_random_relic_for_tier(1)
	_expect(recycled_relic_id != "", "Could not create a relic for the recycling test.")
	_expect(
		state.relic_manager.move_inventory_entry_to_machine_slot(recycled_relic_id, "relic_shard_extractor", 0),
		"Could not load the selected relic into the extractor."
	)
	state.set_resource_amount(ResourceIds.MATTER, 100.0)
	_expect(simulation.buy_generator("relic_shard_extractor"), "Recycling cycle did not start with a valid relic.")
	_expect(state.relic_manager.get_inventory_entry_by_instance_id(recycled_relic_id).is_empty(), "Recycled relic was not consumed at cycle start.")
	var shards_before := 0
	for entry in state.relic_manager.inventory:
		if str(entry.get("item_id", "")) == "relic_shard":
			shards_before += int(entry.get("quantity", 0))
	simulation.complete_cycle(generator)
	var shards_after := 0
	for entry in state.relic_manager.inventory:
		if str(entry.get("item_id", "")) == "relic_shard":
			shards_after += int(entry.get("quantity", 0))
	_expect(shards_after - shards_before == 3, "Recycling should produce exactly 3 shards regardless of generator level.")

	_expect(state.relic_manager.add_random_relic_for_tier(2) != "", "Tier 2 random relic generation failed.")
	var produced_relic: Dictionary = state.relic_manager.inventory.back()
	var produced_definition := state.relic_manager.get_definition(str(produced_relic.get("definition_id", "")))
	_expect(int(produced_definition.get("tier", 0)) == 2, "Random tier 2 reward came from the wrong tier.")
	# Completion grants one random relic independently of extractor level.
	generator.level = 4
	generator.set_operation_mode("forge_relic")
	var before_count := state.relic_manager.inventory.size()
	simulation.complete_cycle(generator)
	_expect(state.relic_manager.inventory.size() == before_count + 1, "Forging should grant exactly one relic, not one per generator level.")


func _test_data_driven_relic_generation_and_critical_promotion() -> void:
	var manager := RelicManager.new()
	var normal_id := manager.add_random_relic_for_tier(1)
	var normal_relic: Dictionary = manager.get_relic(normal_id)
	var normal_definition: Dictionary = manager.get_relic_definition(normal_relic)
	_expect(not normal_id.is_empty(), "Tier 1 generation did not create a relic.")
	_expect(int(normal_definition.get("tier", 0)) == 1, "Normal crafting changed the requested tier.")
	_expect(bool(normal_definition.get("generated", false)), "Crafted relic did not store its generated definition.")
	_expect(str(normal_definition.get("display_name", "")) != "", "Generated relic name was empty.")
	var normal_description := manager.get_relic_description(normal_relic)
	_expect(not normal_description.is_empty(), "Generated relic description omitted its primary stat.")
	_expect(not normal_description.contains("Rolled:"), "Generated relic description should not use the redundant Rolled prefix.")

	var critical_id := manager.add_random_relic_for_tier(1, 1.0)
	var critical_relic: Dictionary = manager.get_relic(critical_id)
	var critical_definition: Dictionary = manager.get_relic_definition(critical_relic)
	_expect(not critical_id.is_empty(), "Guaranteed critical crafting failed to create a relic.")
	_expect(int(critical_definition.get("tier", 0)) == 2, "Critical crafting did not promote tier 1 to tier 2.")
	_expect(bool(critical_relic.get("critical_craft", false)), "Promoted relic did not record its critical craft.")
	var critical_secondary: Variant = critical_relic.get("secondary_stat", {})
	_expect(critical_secondary is Dictionary and not critical_secondary.is_empty(), "Promoted tier did not generate its configured secondary effect.")
	_expect(manager.get_relic_description(critical_relic).contains("Bonus:"), "Generated secondary effect was not described.")

	var tier_three_critical_id := manager.add_random_relic_for_tier(2, 1.0)
	var tier_three_critical_relic: Dictionary = manager.get_relic(tier_three_critical_id)
	var tier_three_critical_definition: Dictionary = manager.get_relic_definition(tier_three_critical_relic)
	_expect(int(tier_three_critical_definition.get("tier", 0)) == 3, "Critical Tier 2 crafting did not promote to Tier 3.")
	_expect(bool(tier_three_critical_relic.get("critical_craft", false)), "Tier 2-to-3 promotion was not recorded as critical.")
	var tier_three_secondaries: Array[Dictionary] = []
	var first_tier_three_secondary: Variant = tier_three_critical_relic.get("secondary_stat", {})
	if first_tier_three_secondary is Dictionary and not first_tier_three_secondary.is_empty():
		tier_three_secondaries.append(first_tier_three_secondary)
	var additional_tier_three_secondaries: Variant = tier_three_critical_relic.get("additional_secondary_stats", [])
	if additional_tier_three_secondaries is Array:
		for secondary_variant in additional_tier_three_secondaries:
			if secondary_variant is Dictionary and not secondary_variant.is_empty():
				tier_three_secondaries.append(secondary_variant)
	_expect(tier_three_secondaries.size() == 2, "Tier 3 relic should roll exactly two secondary effects.")

	var direct_tier_three_id := manager.add_random_relic_for_tier(3)
	var direct_tier_three_relic: Dictionary = manager.get_relic(direct_tier_three_id)
	var direct_tier_three_definition: Dictionary = manager.get_relic_definition(direct_tier_three_relic)
	_expect(int(direct_tier_three_definition.get("tier", 0)) == 3, "Direct Tier 3 generation failed.")
	_expect(str(direct_tier_three_definition.get("rarity_name", "")) == "Rare", "Tier 3 rarity name should be Rare.")
	_expect(
		manager.get_relic_description(direct_tier_three_relic).count("Bonus:") == 2,
		"Tier 3 relic description should include both secondary effects."
	)

	var highest_tier_id := manager.add_random_relic_for_tier(3, 1.0)
	var highest_tier_relic: Dictionary = manager.get_relic(highest_tier_id)
	var highest_tier_definition: Dictionary = manager.get_relic_definition(highest_tier_relic)
	_expect(int(highest_tier_definition.get("tier", 0)) == 3, "Critical crafting changed the tier when no higher tier exists.")
	_expect(not bool(highest_tier_relic.get("critical_craft", false)), "A non-promoting top-tier craft was incorrectly marked as promoted.")

	var saved_data := manager.get_save_data()
	var loaded_manager := RelicManager.new()
	loaded_manager.load_save_data(saved_data)
	var loaded_critical: Dictionary = loaded_manager.get_relic(critical_id)
	_expect(
		loaded_manager.get_relic_definition(loaded_critical) == critical_definition,
		"Generated definition changed during save/load."
	)
	_expect(
		loaded_critical.get("secondary_stat", {}) == critical_relic.get("secondary_stat", {}),
		"Generated secondary roll changed during save/load."
	)

	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var extractor: Generator = state.get_generator("relic_shard_extractor")
	state.relic_manager.add_stackable_item("relic_shard", 10)
	var shard_entry := state.relic_manager.get_inventory_entry_at_slot(0)
	_expect(
		state.relic_manager.move_inventory_entry_to_machine_slot(
			str(shard_entry.get("instance_id", "")),
			"relic_shard_extractor",
			0
		),
		"Could not load ingredients for the critical crafting cycle."
	)
	state.set_resource_amount(ResourceIds.MATTER, 10.0)
	extractor.set_operation_mode("forge_relic")
	extractor.get_operation_mode().completion_critical_chance = 1.0
	_expect(simulation.buy_generator("relic_shard_extractor"), "Could not start guaranteed critical crafting.")
	var before_count := state.relic_manager.inventory.size()
	simulation.complete_cycle(extractor)
	_expect(state.relic_manager.inventory.size() == before_count + 1, "Critical craft did not award exactly one relic.")
	var crafted_relic: Dictionary = state.relic_manager.inventory.back()
	var crafted_definition: Dictionary = state.relic_manager.get_relic_definition(crafted_relic)
	_expect(int(crafted_definition.get("tier", 0)) == 2, "Crafting cycle did not use the configured critical chance to promote its reward.")


func _test_relic_shard_extractor_cycle() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var extractor: Generator = state.get_generator("relic_shard_extractor")
	_expect(extractor != null, "Relic Shard Extractor was not registered.")
	if extractor == null:
		return

	_expect(extractor.unlocked, "Relic Shard Extractor should be unlocked for testing.")
	_expect(extractor.definition.cycle_based, "Relic Shard Extractor should use the cycle system.")
	_expect_approx(extractor.get_cycle_duration(), 60.0, "Relic Shard Extractor cycle should last 60 seconds.")

	state.set_resource_amount(ResourceIds.MATTER, 110.0)
	_expect(simulation.buy_generator("relic_shard_extractor"), "Could not purchase the test extractor.")
	_expect_approx(state.get_resource_amount(ResourceIds.MATTER), 100.0, "Extractor purchase cost should be 10 Matter.")
	_expect(state.relic_manager.get_inventory_entry_at_slot(0).is_empty(), "Extractor should not grant a shard before its cycle completes.")

	simulation.update(30.0)
	_expect_approx(extractor.cycle_progress, 30.0, "Extractor did not advance halfway through its cycle.")
	_expect_approx(state.get_resource_amount(ResourceIds.MATTER), 50.0, "Extractor did not consume half its 100 Matter cycle cost.")
	_expect(state.relic_manager.get_inventory_entry_at_slot(0).is_empty(), "Extractor granted a shard before the 60-second cycle completed.")

	simulation.update(30.0)
	_expect(not extractor.cycle_active, "Extractor cycle remained active after completing.")
	_expect_approx(state.get_resource_amount(ResourceIds.MATTER), 0.0, "Extractor did not consume 100 Matter over the full cycle.")
	var shard_entry := state.relic_manager.get_inventory_entry_at_slot(0)
	_expect(str(shard_entry.get("item_id", "")) == "relic_shard", "Extractor did not grant a Relic Shard inventory item.")
	_expect(int(shard_entry.get("quantity", 0)) == 1, "Extractor should grant exactly one Relic Shard per completed cycle.")

	state.reset_current_run()
	var persistent_shard := state.relic_manager.get_inventory_entry_at_slot(0)
	_expect(
		str(persistent_shard.get("item_id", "")) == "relic_shard"
		and int(persistent_shard.get("quantity", 0)) == 1,
		"Relic Shard Extractor reward did not persist through Smash/reset."
	)


func _test_rolled_relic_stats() -> void:
	var state := _new_test_state()
	var relic_id := state.relic_manager.add_random_relic_for_tier(1)
	var relic: Dictionary = state.relic_manager.get_relic(relic_id)
	var rolled_value := 1.08
	relic["generated_definition"] = {
		"generated": true,
		"effect_id": "output_increase",
		"modifier_type": ModifierTypes.PRODUCTION,
		"target_id": ResourceIds.HEAT,
		"description_label": "Heat production",
		"description_mode": "multiplier"
	}
	relic["rolled_value"] = rolled_value
	var definition := state.relic_manager.get_relic_definition(relic)
	_expect(bool(definition.get("generated", false)), "Relic did not use the data-driven definition.")
	_expect(rolled_value > 0.0, "Generated relic did not store a rolled value.")
	var relic_description := state.relic_manager.get_relic_description(relic)
	_expect(
		relic_description.contains("Heat production +8.0%"),
		"Relic tooltip should show the instance's rolled stat value without a Rolled prefix."
	)
	_expect(not relic_description.contains("Rolled:"), "Relic tooltip should not use the redundant Rolled prefix.")

	state.eternal_flame_state.eternal_flame = 100.0
	_expect(state.eternal_flame_upgrade_manager.purchase("reliquary", state.eternal_flame_state, state.realm_configuration), "Could not unlock Reliquary for rolled-stat test.")
	_expect(state.relic_manager.equip_relic("atomic_friction", relic_id, state), "Could not equip generated relic.")
	state.rebuild_relic_modifiers()
	var found_targeted_modifier := false
	for modifier in state.get_generator("atomic_friction").modifiers:
		if modifier.id != "relic:" + relic_id:
			continue
		found_targeted_modifier = true
		_expect(modifier.type == definition.get("modifier_type", ""), "Generated relic modifier type did not match its definition.")
		_expect(modifier.target_id == str(definition.get("target_id", "")), "Generated relic target did not match its definition.")
		_expect_approx(modifier.multiplier, rolled_value, "Equipped modifier did not use the instance's rolled value.")
	_expect(found_targeted_modifier, "Generated relic modifier was not rebuilt.")

	var save_data: Dictionary = SaveManager.new().state_to_dictionary(state)
	var loaded_state := _new_test_state()
	_expect(SaveManager.new().dictionary_to_state(loaded_state, save_data, 7), "Generated relic save could not be loaded.")
	var loaded_relic: Dictionary = loaded_state.relic_manager.get_relic(relic_id)
	_expect_approx(float(loaded_relic.get("rolled_value", 0.0)), rolled_value, "Relic stat rerolled during save/load.")


func _test_resource_reservoir_relics() -> void:
	var definitions: Dictionary = RelicGenerationManager.EFFECT_DEFINITIONS
	var heat_effect: Dictionary = definitions.get("heat_reservoir_boost", {})
	var matter_effect: Dictionary = definitions.get("matter_reservoir_boost", {})

	_expect(
		str(heat_effect.get("target_id", "")) == ResourceIds.HEAT
		and str(heat_effect.get("dynamic_resource_id", "")) == ResourceIds.HEAT,
		"Heat reservoir relic should boost Heat production based on current Heat."
	)
	_expect(
		str(matter_effect.get("target_id", "")) == ResourceIds.MATTER
		and str(matter_effect.get("dynamic_resource_id", "")) == ResourceIds.MATTER,
		"Matter reservoir relic should boost Matter production based on current Matter."
	)
	_expect(
		str(heat_effect.get("dynamic_formula", "")) == Modifier.DYNAMIC_RESOURCE_INVERSE_BOOST
		and str(matter_effect.get("dynamic_formula", "")) == Modifier.DYNAMIC_RESOURCE_INVERSE_BOOST,
		"Both reservoir relics should use the inverse resource boost formula."
	)
	_expect(
		float(heat_effect.get("dynamic_threshold", 0.0)) == 100000.0
		and float(matter_effect.get("dynamic_threshold", 0.0)) == 10000.0,
		"Heat and Matter reservoir relics should use their configured independent decay scales."
	)

	var state := _new_test_state()
	var heat_generator: Generator = state.get_generator("atomic_friction")
	state._apply_relic_stat(heat_generator, "test_heat_reservoir", {
		"stat_type": "modifier",
		"modifier_type": ModifierTypes.PRODUCTION,
		"target_id": ResourceIds.HEAT,
		"rolled_value": 0.8,
		"dynamic": true,
		"dynamic_formula": Modifier.DYNAMIC_RESOURCE_INVERSE_BOOST,
		"dynamic_resource_id": ResourceIds.HEAT,
		"dynamic_threshold": 100000.0,
		"dynamic_exponent": 1.5
	})

	var reservoir_modifier: Modifier = null
	for modifier in heat_generator.modifiers:
		if modifier.id == "relic:test_heat_reservoir":
			reservoir_modifier = modifier
			break
	_expect(reservoir_modifier != null, "Heat reservoir relic did not apply a production modifier.")
	if reservoir_modifier == null:
		return

	state.set_resource_amount(ResourceIds.HEAT, 0.0)
	_expect_approx(
		reservoir_modifier.get_effective_multiplier(state, heat_generator),
		1.8,
		"Heat reservoir relic should start at 1.8x with a 0.8 bonus roll and no Heat held."
	)
	state.set_resource_amount(ResourceIds.HEAT, 100000.0)
	var at_scale := reservoir_modifier.get_effective_multiplier(state, heat_generator)
	_expect_approx(
		at_scale,
		1.0 + 0.8 / pow(2.0, 1.5),
		"Heat reservoir relic should decay smoothly at its configured scale."
	)
	state.set_resource_amount(ResourceIds.HEAT, 1000000.0)
	var at_ten_scales := reservoir_modifier.get_effective_multiplier(state, heat_generator)
	_expect(
		at_ten_scales < at_scale and at_ten_scales > 1.0,
		"Heat reservoir bonus should fall sharply toward neutral as Heat accumulates, without becoming a penalty."
	)

	var matter_modifier := Modifier.new(ModifierTypes.PRODUCTION, ResourceIds.MATTER, 0.8)
	matter_modifier.dynamic = true
	matter_modifier.dynamic_formula = Modifier.DYNAMIC_RESOURCE_INVERSE_BOOST
	matter_modifier.dynamic_resource_id = ResourceIds.MATTER
	matter_modifier.dynamic_threshold = 10000.0
	matter_modifier.dynamic_exponent = 1.5
	state.set_resource_amount(ResourceIds.MATTER, 0.0)
	_expect_approx(
		matter_modifier.get_multiplier(state),
		1.8,
		"Matter reservoir formula should start at the same rolled bonus when Matter is empty."
	)
	state.set_resource_amount(ResourceIds.MATTER, 100000.0)
	_expect(
		matter_modifier.get_multiplier(state) < 1.1,
		"Matter reservoir bonus should decay sharply above ten times its scale."
	)


func _test_generated_relic_sensitivity_targets() -> void:
	var definitions: Dictionary = RelicGenerationManager.EFFECT_DEFINITIONS
	var ash_effect: Dictionary = definitions.get("ash_contamination_sensitivity_reduction", {})
	var thermic_reduction: Dictionary = definitions.get("thermic_mass_sensitivity_reduction", {})
	var thermic_increase: Dictionary = definitions.get("thermic_mass_sensitivity_increase", {})
	var crystallization: Dictionary = definitions.get("crystallization_sensitivity_reduction", {})

	_expect(
		ash_effect.get("sensitivity_targets", []) == ["ashen_contamination", "ashen_contamination_cycle_speed"],
		"Ash Contamination relic target should apply to both independent Ash sensitivity modifiers."
	)
	_expect(
		ash_effect.get("roll_ranges", {}).get(1, []) == [0.96, 0.98]
		and ash_effect.get("roll_ranges", {}).get(2, []) == [0.93, 0.96],
		"Ash Contamination reduction ranges should be 2–4% for Common and 4–7% for Uncommon."
	)
	_expect(
		thermic_reduction.get("sensitivity_targets", []) == ["thermic_mass"]
		and thermic_increase.get("sensitivity_targets", []) == ["thermic_mass"],
		"Thermic Mass sensitivity effects should only target Thermic Mass."
	)
	_expect(
		crystallization.get("sensitivity_targets", []) == ["crystallization"],
		"Crystallization sensitivity reduction should target only Crystallization."
	)
	_expect(
		crystallization.get("roll_ranges", {}).get(1, []) == [0.985, 0.995]
		and crystallization.get("roll_ranges", {}).get(2, []) == [0.975, 0.99],
		"Crystallization reduction ranges should be 0.5–1.5% for Common and 1–2.5% for Uncommon."
	)
	_expect(
		float(crystallization.get("weight", 0.0)) < float(ash_effect.get("weight", 0.0)),
		"Crystallization sensitivity should be rarer than Ash Contamination sensitivity."
	)

	for effect_variant in definitions.keys():
		var effect: Dictionary = definitions[effect_variant]
		if str(effect.get("stat_type", "")) == "sensitivity":
			_expect(
				not effect.get("sensitivity_targets", []).has("*"),
				"Generated sensitivity effects should not use a universal wildcard target."
			)


func _test_relic_sensitivity_and_secondary_stats() -> void:
	var state := _new_test_state()
	var generator: Generator = state.get_generator("infernal_forge")
	var sensitivity_relic_id := state.relic_manager.add_random_relic_for_tier(1)
	var sensitivity_relic: Dictionary = state.relic_manager.get_relic(sensitivity_relic_id)
	var sensitivity_value := 0.97
	sensitivity_relic["generated_definition"] = {
		"generated": true,
		"stat_type": "sensitivity",
		"sensitivity_targets": ["ashen_contamination", "ashen_contamination_cycle_speed"],
		"description_label": "Ash Contamination",
		"description_mode": "multiplier"
	}
	sensitivity_relic["rolled_value"] = sensitivity_value
	state._apply_relic_stat(generator, sensitivity_relic_id, {
		"stat_type": "sensitivity",
		"sensitivity_targets": ["ashen_contamination", "ashen_contamination_cycle_speed"],
		"rolled_value": sensitivity_value
	})
	var matched_sensitivities := 0
	for sensitivity in generator.modifier_sensitivities:
		if sensitivity.source_upgrade_id != "relic:" + sensitivity_relic_id:
			continue
		if sensitivity.modifier_id in ["ashen_contamination", "ashen_contamination_cycle_speed"]:
			matched_sensitivities += 1
			_expect_approx(sensitivity.multiplier, sensitivity_value, "Ash sensitivity relic did not preserve its rolled multiplier.")
	_expect(matched_sensitivities == 2, "Ash sensitivity relic should affect both general contamination and forge cycle slowdown.")

	var uncommon_id := state.relic_manager.add_random_relic_for_tier(2)
	var uncommon_relic: Dictionary = state.relic_manager.get_relic(uncommon_id)
	var secondary: Variant = uncommon_relic.get("secondary_stat", {})
	_expect(secondary is Dictionary and not secondary.is_empty(), "Uncommon relic did not roll a secondary stat.")
	_expect(state.relic_manager.get_relic_description(uncommon_relic).contains("Bonus:"), "Uncommon relic tooltip did not describe its secondary stat.")
	var saved_data: Dictionary = state.relic_manager.get_save_data()
	var loaded_manager := RelicManager.new()
	loaded_manager.load_save_data(saved_data)
	var loaded_relic: Dictionary = loaded_manager.get_relic(uncommon_id)
	_expect(loaded_relic.get("secondary_stat", {}) == secondary, "Uncommon relic secondary stat changed during save/load.")


func _test_relic_event_chance_modifiers() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var forge: Generator = state.get_generator("infernal_forge")
	var relic := Modifier.new(ModifierTypes.EVENT_CHANCE, "downlevel_chance", 0.12)
	relic.id = "relic:test_downlevel_chance"
	forge.modifiers.append(relic)
	var downlevel_effect := UpgradeEffect.generator_event(
		"infernal_forge",
		UpgradeEffectTypes.EVENT_CYCLE_COMPLETED,
		UpgradeEffectTypes.EVENT_ACTION_DECREASE_GENERATOR_LEVEL,
		"",
		0.05,
		1.0
	)
	_expect_approx(
		simulation._get_effective_event_chance(forge, downlevel_effect, 0.05),
		0.17,
		"Downlevel chance relic should add percentage points to the beneficial downlevel chance."
	)
	var critical_relic := Modifier.new(ModifierTypes.EVENT_CHANCE, "critical_chance", 0.03)
	critical_relic.id = "relic:test_critical_chance"
	forge.modifiers.append(critical_relic)
	var critical_effect := UpgradeEffect.generator_event(
		"infernal_forge",
		UpgradeEffectTypes.EVENT_CYCLE_COMPLETED,
		UpgradeEffectTypes.EVENT_ACTION_TRIGGER,
		"forge_critical",
		0.10,
		0.0
	)
	_expect_approx(
		simulation._get_effective_event_chance(forge, critical_effect, 0.10),
		0.13,
		"Critical chance relic should add percentage points to the critical chance."
	)


func _test_relic_shard_stacks() -> void:
	var manager := RelicManager.new()
	_expect(
		manager.add_stackable_item("relic_shard", 1250) == 1250,
		"Relic Shard stack creation did not accept the full quantity."
	)
	_expect(manager.inventory.size() == 2, "1,250 shards should occupy two stacks.")
	var first_stack: Dictionary = manager.get_inventory_entry_at_slot(0)
	var second_stack: Dictionary = manager.get_inventory_entry_at_slot(1)
	_expect(
		int(first_stack.get("quantity", 0)) == 1000,
		"First Relic Shard stack did not respect the 1,000-item cap."
	)
	_expect(
		int(second_stack.get("quantity", 0)) == 250,
		"Overflow Relic Shards were not placed into a second stack."
	)

	# Simulate spending some shards, then merge the second stack into the first.
	var first_id := str(first_stack.get("instance_id", ""))
	var second_id := str(second_stack.get("instance_id", ""))
	for entry in manager.inventory:
		if str(entry.get("instance_id", "")) == first_id:
			entry["quantity"] = 900
	_expect(
		manager.move_inventory_entry_to_slot(second_id, 0),
		"Moving a compatible stack onto another stack failed."
	)
	_expect(
		int(manager.get_inventory_entry_at_slot(0).get("quantity", 0)) == 1000,
		"Stack merge did not fill the target stack to its 1,000 cap."
	)
	_expect(
		int(manager.get_inventory_entry_at_slot(1).get("quantity", 0)) == 150,
		"Stack merge did not leave the unmerged remainder in the source square."
	)

	var saved_data := manager.get_save_data()
	var loaded_manager := RelicManager.new()
	loaded_manager.load_save_data(saved_data)
	_expect(
		int(loaded_manager.get_inventory_entry_at_slot(0).get("quantity", 0)) == 1000,
		"Saved Relic Shard stack quantity did not survive loading."
	)
	_expect(
		int(loaded_manager.get_inventory_entry_at_slot(1).get("quantity", 0)) == 150,
		"Saved Relic Shard inventory position or remainder did not survive loading."
	)

	var state := _new_test_state()
	state.relic_manager.add_stackable_item("relic_shard", 10)
	var shard_entry := state.relic_manager.get_inventory_entry_at_slot(0)
	_expect(
		not state.relic_manager.equip_relic(
			"atomic_friction",
			str(shard_entry.get("instance_id", "")),
			state
		),
		"Stackable Relic Shards should not be equippable as relics."
	)
	state.reset_current_run()
	_expect(
		int(state.relic_manager.get_inventory_entry_at_slot(0).get("quantity", 0)) == 10,
		"Relic Shards did not survive the realm Smash/reset."
	)


func _test_machine_crafting_slots() -> void:
	var manager := RelicManager.new()
	manager.add_stackable_item("relic_shard", 10)
	var shard_entry := manager.get_inventory_entry_at_slot(0)
	var shard_instance_id := str(shard_entry.get("instance_id", ""))
	_expect(
		manager.move_inventory_entry_to_machine_slot(shard_instance_id, "relic_shard_extractor", 0),
		"Relic Shards could not be moved into a machine input slot."
	)
	_expect(
		manager.get_inventory_entry_at_slot(0).is_empty(),
		"An item in a machine input slot still occupied a Reliquary square."
	)
	var recipe: Array[Dictionary] = [{
		"item_type": "stackable",
		"item_id": "relic_shard",
		"quantity": 3
	}]
	_expect(
		manager.can_satisfy_crafting_recipe("relic_shard_extractor", recipe),
		"A valid stackable crafting recipe was rejected."
	)
	_expect(
		manager.consume_crafting_recipe("relic_shard_extractor", recipe),
		"A valid crafting recipe could not consume its ingredients."
	)
	_expect(
		int(manager.get_machine_entry_at_slot("relic_shard_extractor", 0).get("quantity", 0)) == 7,
		"Crafting did not preserve the excess quantity in a shard stack."
	)

	var saved_data := manager.get_save_data()
	var loaded_manager := RelicManager.new()
	loaded_manager.load_save_data(saved_data)
	_expect(
		int(loaded_manager.get_machine_entry_at_slot("relic_shard_extractor", 0).get("quantity", 0)) == 7,
		"Machine input contents did not survive save/load."
	)
	_expect(
		loaded_manager.resize_machine_slots("relic_shard_extractor", 0),
		"Machine could not return contents when a recipe no longer needed the slot."
	)
	_expect(
		int(loaded_manager.get_inventory_entry_at_slot(0).get("quantity", 0)) == 7,
		"Hidden machine-slot contents were not returned to the Reliquary."
	)

	var relic_id := loaded_manager.add_random_relic_for_tier(1)
	var relic_slot := int(loaded_manager.inventory_positions.get(relic_id, -1))
	_expect(relic_slot >= 0, "Test relic did not receive an inventory square.")
	_expect(
		loaded_manager.move_inventory_entry_to_machine_slot(relic_id, "relic_shard_extractor", 0),
		"A relic could not be placed into a machine input slot."
	)
	var relic_recipe: Array[Dictionary] = [{"item_type": "relic", "quantity": 1}]
	_expect(
		loaded_manager.consume_crafting_recipe("relic_shard_extractor", relic_recipe),
		"A valid relic recycling recipe could not consume its selected relic."
	)
	_expect(
		loaded_manager.get_relic(relic_id).is_empty(),
		"A recycled relic was not removed from inventory ownership."
	)


func _test_crafting_cycle_start() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var extractor: Generator = state.get_generator("relic_shard_extractor")
	var recipe: Array[Dictionary] = [{
		"item_type": "stackable",
		"item_id": "relic_shard",
		"quantity": 3
	}]
	var crafting_mode := GeneratorOperationMode.new(
		"crafting_test", "Crafting Test", "Regression-only recipe mode",
		1.0, 1.0, 1.0, 60.0, [], [], [], false, [], recipe
	)
	extractor.definition.operation_modes.append(crafting_mode)
	_expect(extractor.set_operation_mode("crafting_test"), "Test crafting operation mode could not be selected.")
	state.relic_manager.add_stackable_item("relic_shard", 10)
	var shard_entry := state.relic_manager.get_inventory_entry_at_slot(0)
	var shard_id := str(shard_entry.get("instance_id", ""))
	_expect(
		state.relic_manager.move_inventory_entry_to_machine_slot(shard_id, "relic_shard_extractor", 0),
		"Test ingredients could not be loaded into the extractor."
	)
	state.set_resource_amount(ResourceIds.MATTER, 10.0)
	_expect(simulation.can_buy_generator("relic_shard_extractor"), "A valid crafting recipe did not enable cycle start.")
	_expect(simulation.buy_generator("relic_shard_extractor"), "A valid crafting cycle could not start.")
	_expect(extractor.cycle_active, "Crafting cycle did not become active after purchase.")
	_expect(
		int(state.relic_manager.get_machine_entry_at_slot("relic_shard_extractor", 0).get("quantity", 0)) == 7,
		"Cycle start did not consume exactly the required shard quantity."
	)


func _test_multiple_relic_slots_and_legacy_migration() -> void:
	var state := _new_test_state()
	state.eternal_flame_state.eternal_flame = 100.0
	_expect(
		state.eternal_flame_upgrade_manager.purchase(
			"reliquary",
			state.eternal_flame_state,
			state.realm_configuration
		),
		"Reliquary purchase failed in multi-slot test."
	)
	var reliquary_upgrade: EternalFlameUpgrade = state.eternal_flame_upgrade_manager.upgrades.get("reliquary")
	reliquary_upgrade.effect_per_level = 2.0
	state.relic_manager.ensure_starter_relic()
	var first_relic_id := str(state.relic_manager.inventory[0].get("instance_id", ""))
	var second_relic_id := state.relic_manager.add_random_relic_for_tier(1, 0.0, "heat_reservoir_boost")
	_expect(
		state.relic_manager.equip_relic("atomic_friction", first_relic_id, state, 0),
		"First relic slot could not be equipped."
	)
	_expect(
		state.relic_manager.equip_relic("atomic_friction", second_relic_id, state, 1),
		"Second relic slot could not be equipped independently."
	)
	_expect(
		state.relic_manager.get_equipped_relic_id("atomic_friction", 0) == first_relic_id,
		"Equipping the second slot overwrote the first slot."
	)
	_expect(
		state.relic_manager.get_equipped_relic_id("atomic_friction", 1) == second_relic_id,
		"Second slot did not retain its own relic."
	)

	var infernal_forge: Generator = state.get_generator("infernal_forge")
	_expect(infernal_forge != null, "Infernal Forge was unavailable for the cycle-lock test.")
	if infernal_forge != null:
		_expect(infernal_forge.definition.cycle_based, "Infernal Forge should use cycle-based operation.")
		infernal_forge.cycle_active = true
		_expect(
			not state.relic_manager.equip_relic("infernal_forge", first_relic_id, state, 0),
			"A relic could be equipped while Infernal Forge cycle was active."
		)
		_expect(
			state.relic_manager.get_equipped_relic_id("atomic_friction", 0) == first_relic_id,
			"Rejected cycle-locked equipment change altered the original slot."
		)
		infernal_forge.cycle_active = false

	state.rebuild_relic_modifiers()
	var relic_modifier_count := 0
	for modifier in state.get_generator("atomic_friction").modifiers:
		if modifier.id.begins_with("relic:"):
			relic_modifier_count += 1
	_expect(relic_modifier_count == 2, "Both equipped relics were not applied as modifiers.")

	var generated_manager := RelicManager.new()
	var generated_id := generated_manager.add_random_relic_for_tier(1)
	var generated_save := generated_manager.get_save_data()
	generated_save["equipped"] = {"atomic_friction": generated_id}
	var legacy_manager := RelicManager.new()
	legacy_manager.load_save_data(generated_save)
	_expect(
		legacy_manager.get_equipped_relic_id("atomic_friction", 0) == generated_id,
		"Legacy one-relic-per-generator save format was not migrated to slot zero."
	)
	var old_relic_manager := RelicManager.new()
	old_relic_manager.load_save_data({
		"inventory": [{"instance_id": "relic_1", "definition_id": "cinder_shard"}],
		"equipped": {"atomic_friction": "relic_1"},
		"next_instance_number": 2
	})
	_expect(old_relic_manager.inventory.is_empty(), "Retired named relics should be discarded from old saves.")
	_expect(old_relic_manager.get_equipped_relic_id("atomic_friction", 0).is_empty(), "Equipment referencing a retired relic was not cleared.")


func _test_reliquary_slot_progression() -> void:
	var state := _new_test_state()
	var manager: EternalFlameUpgradeManager = state.eternal_flame_upgrade_manager
	var flame_state: EternalFlameState = state.eternal_flame_state

	_expect(
		manager.get_relic_slot_count("atomic_friction", flame_state) == 0,
		"Atomic Friction should not have a relic slot before the Reliquary is unlocked."
	)
	_expect(
		manager.get_relic_slot_count("molecular_agitation", flame_state) == 0,
		"Other generators should not have relic slots before the Reliquary is unlocked."
	)

	flame_state.eternal_flame = 100.0
	_expect(
		manager.purchase("reliquary", flame_state, state.realm_configuration),
		"The Reliquary should be purchasable with enough Eternal Flame."
	)
	_expect(
		manager.get_relic_slot_count("atomic_friction", flame_state) == 1,
		"The Reliquary should include one Atomic Friction slot."
	)
	_expect(
		manager.get_relic_slot_count("molecular_agitation", flame_state) == 0,
		"Unlocking the Reliquary should not unlock other generator slots."
	)
	_expect(
		not manager.can_purchase(
			"attunement_lava_mite_colony",
			flame_state,
			state.realm_configuration
		),
		"Lava Mite Colony attunement should remain locked until the previous slot upgrade is purchased."
	)
	_expect(
		manager.purchase(
			"attunement_molecular_agitation",
			flame_state,
			state.realm_configuration
		),
		"Molecular Agitation's slot upgrade should be purchasable after the Reliquary."
	)
	_expect(
		manager.get_relic_slot_count("molecular_agitation", flame_state) == 1,
		"Molecular Agitation's slot upgrade should grant exactly one slot."
	)
	_expect(
		manager.get_relic_slot_count("atomic_friction", flame_state) == 1,
		"Purchasing another generator's slot should not alter Atomic Friction's slot count."
	)


func _test_modifier_operation_mode_targeting() -> void:
	var state := _new_test_state()
	var generator: Generator = state.get_generator("infernal_forge")
	if generator == null:
		_expect(false, "Infernal Forge is missing.")
		return

	var modifier := Modifier.new(ModifierTypes.PRODUCTION, "", 1.5)
	modifier.operation_mode_ids = ["fast"]
	_expect(
		generator.load_operation_mode("normal"),
		"Could not load the normal Infernal Forge mode for the test."
	)
	_expect_approx(
		modifier.get_effective_multiplier(state, generator),
		1.0,
		"Mode-restricted modifier should not affect an untargeted mode."
	)
	_expect(
		generator.load_operation_mode("fast"),
		"Could not load the fast Infernal Forge mode for the test."
	)
	_expect_approx(
		modifier.get_effective_multiplier(state, generator),
		1.5,
		"Mode-restricted modifier should affect its targeted mode."
	)


func _test_ashen_contamination_cycle_speed_modifier() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var forge: Generator = state.get_generator("infernal_forge")
	var friction: Generator = state.get_generator("atomic_friction")
	if forge == null or friction == null:
		_expect(false, "Required generators are missing.")
		return

	var base_threshold: float = state.get_resource_threshold(ResourceIds.ASH)
	state.set_resource_amount(ResourceIds.ASH, base_threshold)
	simulation.update_automatic_upgrades()
	_expect(
		state.get_upgrade("ashen_contamination").is_purchased(),
		"Ashen Contamination did not unlock at its Ash requirement."
	)
	_expect_approx(
		simulation._get_cycle_speed_multiplier(forge),
		1.0,
		"Ash at the configured contamination threshold should not slow cycle speed."
	)

	# Threshold upgrades must affect both contamination effects through the same
	# shared resource threshold, rather than a Forge-specific fixed value.
	state.set_resource_amount(ResourceIds.MATTER, 25.0)
	_expect(
		simulation.buy_upgrade("ash_threshold_line_1"),
		"Could not buy the first Ash Filtration threshold upgrade."
	)
	var upgraded_threshold: float = state.get_resource_threshold(ResourceIds.ASH)
	_expect_approx(
		upgraded_threshold,
		base_threshold + 9.0,
		"Ash Filtration I did not raise the shared Ash threshold."
	)
	state.set_resource_amount(ResourceIds.ASH, upgraded_threshold)
	_expect_approx(
		simulation._get_cycle_speed_multiplier(forge),
		1.0,
		"Forge cycle slowdown did not respect the upgraded Ash threshold."
	)

	# The panel must use the same effective modifiers as simulation, including
	# penalties below the old hardcoded 100-Ash display cutoff.
	state.set_resource_amount(ResourceIds.ASH, 25.0)
	var simulation_speed_at_25_ash := simulation._get_cycle_speed_multiplier(forge)
	var panel_speed_at_25_ash := GeneratorPanel.get_effective_cycle_speed_multiplier(state, forge)
	_expect(
		simulation_speed_at_25_ash < 1.0,
		"Ash at 25 should slow the Forge when its configured threshold is 10."
	)
	_expect_approx(
		panel_speed_at_25_ash,
		simulation_speed_at_25_ash,
		"Forge panel cycle estimate did not use the same effective speed modifiers as simulation."
	)
	state.set_resource_amount(ResourceIds.ASH, upgraded_threshold)

	var contamination_modifier: Modifier = null
	for modifier in friction.modifiers:
		if modifier.id == "ashen_contamination":
			contamination_modifier = modifier
			break
	_expect(contamination_modifier != null, "General Ash contamination modifier was not registered.")
	if contamination_modifier != null:
		_expect_approx(
			contamination_modifier.get_effective_multiplier(state, friction),
			1.0,
			"General production penalty did not respect the upgraded Ash threshold."
		)

	state.set_resource_amount(ResourceIds.ASH, 1000.0)
	var contaminated_speed: float = simulation._get_cycle_speed_multiplier(forge)
	_expect(
		contaminated_speed < 1.0,
		"Ash contamination did not slow Infernal Forge cycle speed above the configured threshold."
	)
	_expect_approx(
		simulation._get_cycle_speed_multiplier(friction),
		1.0,
		"Cycle-speed contamination should not affect continuous generators."
	)
	if contamination_modifier != null:
		_expect(
			contamination_modifier.get_effective_multiplier(state, friction) < 1.0,
			"General Ash contamination did not penalize production above the configured threshold."
		)

	forge.modifier_sensitivities.append(
		ModifierSensitivity.new(
			"ashen_contamination_cycle_speed",
			0.0,
			"regression_test"
		)
	)
	_expect_approx(
		simulation._get_cycle_speed_multiplier(forge),
		1.0,
		"A zero modifier sensitivity should negate the cycle-speed penalty."
	)


func _test_forge_immunity_ash_sensitivity() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var forge: Generator = state.get_generator("infernal_forge")
	if forge == null:
		_expect(false, "Infernal Forge is missing.")
		return

	forge.level = 1
	forge.unlocked = true
	# The automatic immunity upgrade requires the Forge unlock upgrade to be owned.
	state.get_upgrade("infernal_forge_unlock").level = 1
	state.set_resource_amount(ResourceIds.ASH, 1000.0)
	simulation.update_automatic_upgrades()

	var immunity: Upgrade = state.get_upgrade("infernal_forge_immunity")
	var contamination: Upgrade = state.get_upgrade("ashen_contamination")
	_expect(immunity != null and immunity.is_purchased(), "Forge Immunity did not activate at Forge level 1.")
	_expect(contamination != null and contamination.is_purchased(), "Ashen Contamination did not activate at the test Ash level.")

	var production_modifier: Modifier = null
	var cycle_speed_modifier: Modifier = null
	for modifier in forge.modifiers:
		if modifier.id == "ashen_contamination":
			production_modifier = modifier
		elif modifier.id == "ashen_contamination_cycle_speed":
			cycle_speed_modifier = modifier

	_expect(production_modifier != null, "Ashen Contamination production modifier was not registered on the Forge.")
	_expect(cycle_speed_modifier != null, "Ashen Contamination cycle-speed modifier was not registered on the Forge.")
	if production_modifier != null:
		_expect_approx(
			production_modifier.get_effective_multiplier(state, forge),
			1.0,
			"Forge Immunity should reduce Ashen Contamination production sensitivity to zero."
		)
	if cycle_speed_modifier != null:
		_expect(
			cycle_speed_modifier.get_effective_multiplier(state, forge) < 1.0,
			"Forge Immunity must not remove Ashen Contamination cycle slowdown."
		)


func _test_misc_modifier_sensitivity_reporting() -> void:
	var state := _new_test_state()
	var forge: Generator = state.get_generator("infernal_forge")
	if forge == null:
		_expect(false, "Infernal Forge is missing.")
		return

	var modifier := Modifier.new(ModifierTypes.COST, "", 1.5)
	modifier.id = "regression_misc_sensitivity"
	forge.modifiers.append(modifier)
	forge.modifier_sensitivities.append(
		ModifierSensitivity.new(
			"regression_misc_sensitivity",
			0.5,
			"regression_test"
		)
	)

	var stats := GameStats.new(state)
	var misc_modifiers: Array = stats.get_generator_modifiers("infernal_forge")
	var found_modifier: Dictionary = {}
	for modifier_data in misc_modifiers:
		if modifier_data.get("id", "") == "regression_misc_sensitivity":
			found_modifier = modifier_data
			break

	_expect(not found_modifier.is_empty(), "Miscellaneous modifier was not returned by GameStats.")
	if found_modifier.is_empty():
		return

	_expect_approx(
		float(found_modifier.get("current_multiplier", 1.0)),
		1.5,
		"Miscellaneous modifier raw multiplier was incorrect."
	)
	_expect_approx(
		float(found_modifier.get("effective_multiplier", 1.0)),
		1.25,
		"Miscellaneous modifier did not apply sensitivity to its effective multiplier."
	)
	_expect_approx(
		float(found_modifier.get("sensitivity", 1.0)),
		0.5,
		"Miscellaneous modifier sensitivity was not exposed to the StatsPanel."
	)



func _test_generator_special_effect_descriptors() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var forge: Generator = state.get_generator("infernal_forge")
	var friction: Generator = state.get_generator("atomic_friction")
	if forge == null or friction == null:
		_expect(false, "Generators required for special-effect stats test are missing.")
		return

	forge.unlocked = true
	forge.level = 1
	state.get_upgrade("infernal_forge_unlock").level = 1
	state.set_resource_amount(ResourceIds.MATTER, 1000000000.0)
	_expect(simulation.buy_upgrade("infernal_forge_critical_chance"), "Could not buy Critical Chance for special-effect stats test.")
	_expect(simulation.buy_upgrade("infernal_forge_critical_production"), "Could not buy Critical Production for special-effect stats test.")
	for effect in forge.event_effects:
		if effect.event_source_upgrade_id == "infernal_forge_critical_production":
			effect.operation_mode_ids = ["fast"]

	var stats_entry := GeneratorStatsEntry.new()
	stats_entry.state = state
	stats_entry.generator_id = "infernal_forge"
	var forge_effects: Array[Dictionary] = stats_entry.get_special_effect_descriptors(forge)
	_expect(not forge_effects.is_empty(), "Purchased Forge event effects were not exposed to generator stats.")

	var found_chance := false
	var found_output_bonus := false
	var found_mode_restriction := false
	for effect_data in forge_effects:
		var effect_key := str(effect_data.get("key", ""))
		var description := str(effect_data.get("description", ""))
		if effect_key.contains("infernal_forge_critical_chance"):
			found_chance = description.contains("Chance:")
		if effect_key.contains("infernal_forge_critical_production"):
			found_output_bonus = description.contains("Bonus:")
			found_mode_restriction = str(effect_data.get("mode_text", "")) == "Fast"
	_expect(found_chance, "Generator stats did not describe the purchased critical chance.")
	_expect(found_output_bonus, "Generator stats did not describe the critical output bonus.")
	_expect(found_mode_restriction, "Generator stats did not expose operation-mode restrictions.")

	var friction_effects: Array[Dictionary] = stats_entry.get_special_effect_descriptors(friction)
	_expect(friction_effects.is_empty(), "A generator without special effects displayed an unnecessary special-effects section.")

	var extractor: Generator = state.get_generator("relic_shard_extractor")
	stats_entry.generator_id = "relic_shard_extractor"
	var extractor_effects: Array[Dictionary] = stats_entry.get_special_effect_descriptors(extractor)
	var found_crafting_critical := false
	for effect_data in extractor_effects:
		if str(effect_data.get("key", "")) != "completion_critical:forge_relic":
			continue
		found_crafting_critical = (
			str(effect_data.get("description", "")).contains("5%")
			and str(effect_data.get("mode_text", "")) == "Forge Relic"
			and not bool(effect_data.get("active", true))
		)
	_expect(
		found_crafting_critical,
		"Generator stats did not expose the mode-specific critical crafting chance."
	)

	stats_entry.free()


func _test_cycle_completion_event_effects() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var forge: Generator = state.get_generator("infernal_forge")
	if forge == null:
		_expect(false, "Infernal Forge is missing.")
		return

	forge.unlocked = true
	forge.level = 1
	# Forge cycle upgrades require the Forge unlock upgrade to be owned.
	state.get_upgrade("infernal_forge_unlock").level = 1
	state.set_resource_amount(ResourceIds.MATTER, 1000000000.0)
	_expect(simulation.buy_upgrade("infernal_forge_critical_chance"), "Could not buy Critical Chance upgrade.")
	_expect(simulation.buy_upgrade("infernal_forge_critical_production"), "Could not buy Critical Production upgrade.")
	_expect(simulation.buy_upgrade("infernal_forge_recrystallization"), "Could not buy Re-crystallization upgrade.")

	for effect in forge.event_effects:
		if effect.event_action == "trigger_event" or effect.event_action == "decrease_generator_level":
			effect.event_chance = 1.0

	state.set_resource_amount(ResourceIds.HEAT, 500000.0)
	state.set_resource_amount(ResourceIds.CRYSTALLIZED_FLAME, 0.0)
	forge.cycle_active = true
	forge.operating = true
	simulation.complete_cycle(forge)

	_expect_approx(
		state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME),
		1.5,
		"Critical completion did not apply its output bonus before Re-crystallization."
	)
	_expect(
		forge.level == 0,
		"Re-crystallization did not allow the Forge to drop from level 1 to level 0."
	)
	_expect(not forge.cycle_active, "Completed cycle remained active after Re-crystallization.")
	_expect_approx(
		state.get_resource_amount(ResourceIds.HEAT),
		0.0,
		"Crystallization should still consume accumulated Heat."
	)

	state.set_resource_amount(ResourceIds.HEAT, 1000001.0)
	_expect(simulation.buy_generator("infernal_forge"), "Forge could not be restarted by purchasing a level from level 0.")
	_expect(forge.level == 1, "Buying from level 0 did not restore Forge level 1.")
	_expect(forge.cycle_active, "Buying a level from level 0 did not start a new cycle.")



func _test_cycle_event_operation_mode_targeting() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	var forge: Generator = state.get_generator("infernal_forge")
	if forge == null:
		_expect(false, "Infernal Forge is missing.")
		return

	forge.unlocked = true
	forge.level = 1
	# Forge cycle upgrades require the Forge unlock upgrade to be owned.
	state.get_upgrade("infernal_forge_unlock").level = 1
	state.set_resource_amount(ResourceIds.MATTER, 1000000000.0)
	_expect(simulation.buy_upgrade("infernal_forge_critical_chance"), "Could not buy Critical Chance upgrade.")
	_expect(simulation.buy_upgrade("infernal_forge_critical_production"), "Could not buy Critical Production upgrade.")

	for effect in forge.event_effects:
		if effect.event_action == UpgradeEffectTypes.EVENT_ACTION_TRIGGER:
			effect.event_chance = 1.0
			effect.operation_mode_ids = ["fast"]
		elif effect.event_action == UpgradeEffectTypes.EVENT_ACTION_MULTIPLY_COMPLETION_OUTPUT:
			effect.operation_mode_ids = ["fast"]

	# The restricted critical event must not trigger in Normal mode.
	forge.operation_mode_id = "normal"
	forge.cycle_active = true
	forge.operating = true
	state.set_resource_amount(ResourceIds.HEAT, 500000.0)
	state.set_resource_amount(ResourceIds.CRYSTALLIZED_FLAME, 0.0)
	simulation.complete_cycle(forge)
	_expect_approx(
		state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME),
		1.0,
		"Fast-only critical effects incorrectly changed Normal-mode output."
	)

	# The same effects should apply when the Forge completes a Fast-mode cycle.
	forge.operation_mode_id = "fast"
	forge.cycle_active = true
	forge.operating = true
	state.set_resource_amount(ResourceIds.HEAT, 500000.0)
	state.set_resource_amount(ResourceIds.CRYSTALLIZED_FLAME, 0.0)
	simulation.complete_cycle(forge)
	_expect_approx(
		state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME),
		1.5,
		"Fast-mode critical event and output bonus did not apply."
	)


func _test_offline_partial_input_startup() -> void:
	var state := _new_test_state()
	var simulation := Simulation.new(state)
	for generator in state.generators.values():
		if generator.definition.cycle_based:
			continue
		generator.unlocked = true
		for mode in generator.definition.operation_modes:
			generator.operation_mode_id = mode.id
			for level in [0, 1, 5]:
				generator.level = level
				for amount in [0.0, 0.000001, 1.0, 100.0]:
					for resource_id in state.resources:
						state.set_resource_amount(resource_id, amount)
					for paused in [false, true]:
						generator.manually_paused = paused
						var original: bool = generator.can_start_operating(state, true)
						var combined: bool = level > 0 and not paused and simulation._get_available_operating_delta(generator, 0.1) > 0.0
						_expect(original == combined, "Offline duration and original partial-input startup gates disagree.")
	# Exercise the registered dynamic modifiers and sensitivities as well.
	state.set_resource_amount(ResourceIds.ASH, 100.0)
	state.set_resource_amount(ResourceIds.MATTER, 100.0)
	state.set_resource_amount(ResourceIds.ESSENCE, 100.0)
	simulation.update_automatic_upgrades()
	for generator in state.generators.values():
		if generator.definition.cycle_based:
			continue
		generator.unlocked = true
		generator.level = 2
		generator.manually_paused = false
		var original: bool = generator.can_start_operating(state, true)
		_expect(original == (simulation._get_available_operating_delta(generator, 0.1) > 0.0), "Dynamic input modifiers changed the startup equivalence.")


func _upgrade_levels_snapshot(state: GameState) -> Dictionary:
	var levels: Dictionary = {}
	for id in state.upgrades:
		levels[id] = state.upgrades[id].level
	return levels


func _test_offline_automatic_upgrade_order() -> void:
	var reference := _new_test_state()
	var indexed := _new_test_state()
	var reference_simulation := Simulation.new(reference)
	var indexed_simulation := Simulation.new(indexed)
	for amount in [0.0, 1.0, 100.0, 0.0]:
		for state in [reference, indexed]:
			for id in state.resources:
				state.set_resource_amount(id, amount)
		reference_simulation.update_automatic_upgrades()
		indexed_simulation.update_automatic_upgrades(true)
		_expect(_upgrade_levels_snapshot(reference) == _upgrade_levels_snapshot(indexed), "Offline automatic upgrades changed eligibility timing.")
		_expect(reference.gameplay_log.events == indexed.gameplay_log.events, "Offline automatic upgrades changed registry application order.")
	indexed_simulation.update_automatic_upgrades(true)
	for upgrade in indexed_simulation._offline_automatic_upgrades:
		_expect(not upgrade.is_maxed(), "The offline index retained a maxed automatic upgrade.")
	for state in [reference, indexed]:
		state.reset_current_run()
		state.gameplay_log.events.clear()
		for id in state.resources:
			state.set_resource_amount(id, 100.0)
	reference_simulation.update_automatic_upgrades()
	indexed_simulation.update_automatic_upgrades(true)
	_expect(_upgrade_levels_snapshot(reference) == _upgrade_levels_snapshot(indexed), "Realm reset did not refresh pruned automatic upgrades.")
	_expect(reference.gameplay_log.events == indexed.gameplay_log.events, "Realm reset changed automatic-upgrade order.")
	# Rebuild after reset/load must not retain an old structural index.
	indexed_simulation.rebuild_upgrade_effects()
	_expect(indexed_simulation._offline_upgrade_count == -1, "Upgrade rebuild did not invalidate the automatic-upgrade index.")


func _test_offline_startup_evaluation_count() -> void:
	var state := _new_test_state()
	var probe := InputRateProbe.new(state.get_generator("infernal_forge").definition)
	probe.level = 1
	probe.unlocked = true
	probe.cycle_active = true
	for resource_id in state.resources:
		state.set_resource_amount(resource_id, 1e12)
	_expect(probe.can_start_operating(state, true), "Nonempty offline inputs should pass startup.")
	_expect(probe.rate_evaluations == 0, "Offline startup evaluated a rate whose value cannot affect its decision.")
	_expect(probe.can_start_operating(state, false), "Normal startup with abundant inputs should pass.")
	_expect(probe.rate_evaluations == probe.get_active_inputs().size(), "Normal gameplay must retain its original rate evaluations.")
	probe.rate_evaluations = 0
	state.set_resource_amount(probe.get_active_inputs()[0].resource_id, 0.0)
	_expect(not probe.can_start_operating(state, true), "Empty input with a positive rate should block offline startup.")
	_expect(probe.rate_evaluations == 1, "Empty inputs still need their rate evaluated.")
	probe.rate_evaluations = 0
	probe.modifiers.append(Modifier.new(ModifierTypes.INPUT_DRAW, probe.get_active_inputs()[0].resource_id, 0.0))
	_expect(probe.can_start_operating(state, true), "An empty input with zero effective draw must still allow offline startup.")
	_expect(probe.rate_evaluations == 1, "Zero-rate empty inputs must be evaluated rather than assumed to block startup.")


# RNG replay fixtures deliberately keep input reserves abundant so the existing
# normal/offline input-operation differences do not obscure random-event parity.
func _rng_state(seed_value: int = 123456) -> GameState:
	var state := _new_test_state()
	state.gameplay_rng.seed = seed_value
	state.set_resource_amount(ResourceIds.HEAT, 1000000.0)
	state.set_resource_amount(ResourceIds.MATTER, 1000000.0)
	var forge: Generator = state.get_generator("infernal_forge")
	forge.unlocked = true
	forge.level = 3
	forge.operation_mode_id = "fast"
	var critical := UpgradeEffect.new(UpgradeEffectTypes.REGISTER_EVENT_EFFECT, forge.definition.id)
	critical.event_trigger = UpgradeEffectTypes.EVENT_CYCLE_COMPLETED
	critical.event_action = UpgradeEffectTypes.EVENT_ACTION_TRIGGER
	critical.event_id = "forge_critical"
	critical.event_chance = 0.5
	var downlevel := UpgradeEffect.new(UpgradeEffectTypes.REGISTER_EVENT_EFFECT, forge.definition.id)
	downlevel.event_trigger = UpgradeEffectTypes.EVENT_CYCLE_COMPLETED
	downlevel.event_action = UpgradeEffectTypes.EVENT_ACTION_DECREASE_GENERATOR_LEVEL
	downlevel.event_chance = 0.5
	downlevel.event_value = 1.0
	forge.event_effects = [critical, downlevel]
	var crucible: Generator = state.get_generator("relic_shard_extractor")
	crucible.operation_mode_id = "forge_relic"
	return state


func _rng_actions(state: GameState, count: int, noisy: bool, offline: bool) -> Array[bool]:
	var simulation := Simulation.new(state)
	var criticals: Array[bool] = []
	simulation.critical_crystallization_completed.connect(func(_amount: float) -> void: criticals.append(true))
	simulation.crystallization_completed.connect(func(_amount: float) -> void: criticals.append(false))
	var forge: Generator = state.get_generator("infernal_forge")
	var crucible: Generator = state.get_generator("relic_shard_extractor")
	for index in range(count):
		if noisy:
			seed(90123 + index)
			var visual_items: Array[int] = [1, 2, 3, 4]
			visual_items.shuffle()
			for _noise in range(index % 19 + 1):
				randf()
				randi_range(0, 100)
		forge.level = maxi(forge.level, 1)
		forge.cycle_active = true
		forge.operating = false
		forge.cycle_progress = forge.get_cycle_duration() - 0.1
		simulation.update_cycle_generator(forge, 0.1, offline)
		crucible.cycle_active = true
		crucible.operating = false
		crucible.cycle_progress = crucible.get_cycle_duration() - 0.1
		crucible.cycle_critical_chance_snapshot = 0.25
		simulation.update_cycle_generator(crucible, 0.1, offline)
	return criticals


func _rng_snapshot(state: GameState) -> Dictionary:
	var resources: Dictionary = {}
	var levels: Dictionary = {}
	for id in state.resources:
		resources[id] = state.get_resource_amount(id)
	for id in state.generators:
		levels[id] = state.generators[id].level
	return {"resources": resources, "levels": levels, "inventory": state.relic_manager.get_save_data(),
		"statistics": state.resource_statistics.to_dictionary(), "rng_state": str(state.gameplay_rng.state)}


func _test_gameplay_rng_replay() -> void:
	var reference := _rng_state()
	var noisy := _rng_state()
	var offline := _rng_state()
	var expected: Array[bool] = _rng_actions(reference, 32, false, false)
	_expect(_rng_actions(noisy, 32, true, false) == expected, "Cosmetic/global RNG calls changed critical results.")
	_expect(_rng_actions(offline, 32, true, true) == expected, "Offline cycles used a different gameplay stream.")
	_expect(_rng_snapshot(reference) == _rng_snapshot(noisy), "Cosmetic RNG changed relics/resources/inventory or the gameplay stream.")
	_expect(_rng_snapshot(reference) == _rng_snapshot(offline), "Normal/offline equivalent cycle actions produced different random outcomes.")
	_expect(expected.has(true) and expected.has(false), "Replay fixture must exercise critical and normal outcomes.")


func _json_rng_save(state: GameState) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(SaveManager.new().state_to_dictionary(state)))
	_expect(parsed is Dictionary, "RNG save fixture did not survive JSON encoding.")
	return parsed if parsed is Dictionary else {}


func _test_gameplay_rng_save_sequence() -> void:
	for seed_value in ["9223372036854775807".to_int(), "-9223372036854775808".to_int()]:
		var original := _rng_state(seed_value)
		for _index in range(17):
			original.gameplay_rng.randi()
		var saved: Dictionary = _json_rng_save(original)
		_expect(saved["gameplay_rng"]["seed"] is String and saved["gameplay_rng"]["state"] is String, "64-bit RNG data must be stored as strings.")
		var restored := _new_test_state()
		_expect(SaveManager.new().dictionary_to_state(restored, saved, SaveManager.SAVE_VERSION), "Modern RNG save failed to load.")
		_expect(restored.gameplay_rng.seed == original.gameplay_rng.seed, "RNG seed lost precision in JSON.")
		_expect(restored.gameplay_rng.state == original.gameplay_rng.state, "RNG state lost precision in JSON.")
		for _index in range(128):
			_expect(restored.gameplay_rng.randi() == original.gameplay_rng.randi(), "Reload changed a subsequent gameplay random value.")
		# Bad modern RNG data fails instead of silently reseeding.
		saved["gameplay_rng"]["state"] = "184467440737095516160"
		_expect(not SaveManager.new().dictionary_to_state(_new_test_state(), saved, SaveManager.SAVE_VERSION), "Overflowed RNG state was accepted.")
		saved.erase("gameplay_rng")
		_expect(not SaveManager.new().dictionary_to_state(_new_test_state(), saved, SaveManager.SAVE_VERSION), "A modern save missing RNG state silently reseeded.")


func _test_gameplay_rng_save_actions() -> void:
	var original := _rng_state()
	_rng_actions(original, 16, false, false)
	var saved: Dictionary = _json_rng_save(original)
	var restored := _rng_state(99)
	_expect(SaveManager.new().dictionary_to_state(restored, saved, SaveManager.SAVE_VERSION), "Mixed gameplay save failed to load.")
	_expect(_rng_saved_values_equal(_rng_snapshot(restored), _rng_snapshot(original)), "Loading rerolled or lost existing inventory/state.")
	var existing_count: int = original.relic_manager.inventory.size()
	var expected: Array[bool] = _rng_actions(original, 24, false, true)
	_expect(_rng_actions(restored, 24, true, true) == expected, "Reload changed subsequent cycle critical rolls.")
	_expect(_rng_saved_values_equal(_rng_snapshot(restored), _rng_snapshot(original)), "Reload changed subsequent relics/resources/inventory.")
	_expect(restored.relic_manager.inventory.slice(existing_count) == original.relic_manager.inventory.slice(existing_count), "New post-load relic rolls must match exactly, not approximately.")


func _test_gameplay_rng_critical_snapshot() -> void:
	var state := _new_test_state()
	state.gameplay_rng.seed = 7654321
	var simulation := Simulation.new(state)
	var crucible: Generator = state.get_generator("relic_shard_extractor")
	crucible.operation_mode_id = "forge_relic"
	crucible.level = 2
	state.relic_manager.add_stackable_item("relic_shard", 100)
	var entry: Dictionary = state.relic_manager.get_inventory_entry_at_slot(0)
	_expect(state.relic_manager.move_inventory_entry_to_machine_slot(str(entry["instance_id"]), crucible.definition.id, 0), "Could not stock the active-craft fixture.")
	state.set_resource_amount(ResourceIds.MATTER, 100.0)
	_expect(simulation.buy_generator(crucible.definition.id), "Could not activate the snapshot craft.")
	var activation_chance: float = crucible.cycle_critical_chance_snapshot
	crucible.level = 20
	crucible.cycle_progress = 12.5
	var restored := _new_test_state()
	_expect(SaveManager.new().dictionary_to_state(restored, _json_rng_save(state), SaveManager.SAVE_VERSION), "Active-craft save failed to load.")
	var loaded: Generator = restored.get_generator(crucible.definition.id)
	_expect(loaded.cycle_active and loaded.cycle_progress == 12.5, "Loading changed active cycle progress.")
	_expect(loaded.cycle_critical_chance_snapshot == activation_chance, "Loading lost or rounded the activation-time critical chance.")
	_expect(activation_chance != Simulation.new(restored).get_effective_relic_critical_chance(loaded, loaded.get_operation_mode()), "Snapshot fixture must differ from current-level critical chance.")
	simulation.complete_cycle(crucible)
	Simulation.new(restored).complete_cycle(loaded)
	_expect(restored.relic_manager.get_save_data() == state.relic_manager.get_save_data(), "Loaded active craft produced a different relic.")
	_expect(restored.gameplay_rng.state == state.gameplay_rng.state, "Loaded active craft consumed different RNG draws.")


func _test_gameplay_rng_legacy_save() -> void:
	var legacy: Dictionary = _json_rng_save(_rng_state())
	legacy.erase("gameplay_rng")
	for generator_data in legacy["generators"].values():
		generator_data.erase("cycle_critical_chance_snapshot")
	legacy["generators"]["relic_shard_extractor"]["cycle_active"] = true
	legacy["generators"]["relic_shard_extractor"]["cycle_progress"] = 7.5
	var migrated := _new_test_state()
	migrated.gameplay_rng.seed = 2468
	var initial_state: int = migrated.gameplay_rng.state
	_expect(SaveManager.new().dictionary_to_state(migrated, legacy, 8), "Version-8 save without RNG fields failed to load.")
	_expect(migrated.gameplay_rng.state == initial_state, "Legacy loading unnecessarily reseeded or consumed gameplay RNG.")
	var craft: Generator = migrated.get_generator("relic_shard_extractor")
	_expect(craft.cycle_active and craft.cycle_progress == 7.5, "Legacy cycle progress changed.")
	_expect(craft.cycle_critical_chance_snapshot == -1.0, "Legacy load fabricated an unknown activation probability.")
	var upgraded: Dictionary = _json_rng_save(migrated)
	_expect(upgraded.has("gameplay_rng"), "Migrated save did not acquire persistent RNG state.")
	var restored := _new_test_state()
	_expect(SaveManager.new().dictionary_to_state(restored, upgraded, SaveManager.SAVE_VERSION), "Migrated save could not load as the modern format.")
	_expect(restored.gameplay_rng.state == migrated.gameplay_rng.state, "Migrated RNG stream did not persist.")
	# Preserve the existing starter backfill as a real gameplay RNG event.
	var missing_reward := _new_test_state()
	missing_reward.gameplay_rng.seed = 7531
	missing_reward.eternal_flame_state.set_upgrade_level("reliquary", 1)
	var reward_save: Dictionary = _json_rng_save(missing_reward)
	missing_reward.relic_manager.ensure_starter_relic()
	var loaded_reward := _new_test_state()
	_expect(SaveManager.new().dictionary_to_state(loaded_reward, reward_save, SaveManager.SAVE_VERSION), "Starter-backfill save failed to load.")
	_expect(loaded_reward.relic_manager.get_save_data() == missing_reward.relic_manager.get_save_data(), "Starter backfill did not use the restored gameplay stream.")
	_expect(loaded_reward.gameplay_rng.state == missing_reward.gameplay_rng.state, "Starter backfill consumed unexpected gameplay draws.")


func _test_gameplay_rng_event_order() -> void:
	for chance in [0.0, 0.5, 1.0]:
		var state := _rng_state(123)
		var forge: Generator = state.get_generator("infernal_forge")
		for effect in forge.event_effects:
			effect.event_chance = chance
		var reference := RandomNumberGenerator.new()
		reference.seed = 123
		seed(123)
		var expected_critical: bool = chance >= 1.0 or (chance > 0.0 and randf() < chance)
		var expected_downlevel: bool = chance >= 1.0 or (chance > 0.0 and randf() < chance)
		if chance > 0.0 and chance < 1.0:
			reference.randi()
			reference.randi()
		var actual: Array[bool] = []
		var simulation := Simulation.new(state)
		simulation.critical_crystallization_completed.connect(func(_amount: float) -> void: actual.append(true))
		simulation.crystallization_completed.connect(func(_amount: float) -> void: actual.append(false))
		simulation.complete_cycle(forge)
		_expect(actual == [expected_critical], "The first gameplay draw no longer controls the critical event.")
		_expect(forge.level == 3 - int(expected_downlevel), "The subsequent gameplay draw no longer controls downleveling.")
		_expect(state.gameplay_rng.state == reference.state, "Probability 0/1 or event ordering changed the number of RNG draws.")


func _test_gameplay_rng_relic_ranges() -> void:
	# Compare the legacy global utility samplers themselves, not a duplicate
	# of the new implementation. Covers precision and PCG draw consumption.
	seed(654321)
	var expected: Array[float] = []
	for index in range(500):
		expected.append(randf())
		expected.append(randf_range(0.001, 1.75))
		expected.append(float(randi_range(0, index % 13)))
	var compatibility_rng := RandomNumberGenerator.new()
	compatibility_rng.seed = 654321
	for index in range(500):
		_expect(GameplayRandomCompat.sample_unit(compatibility_rng) == expected[index * 3], "Dedicated stream changed the legacy unit sampler or draw ordering.")
		_expect(GameplayRandomCompat.sample_range(compatibility_rng, 0.001, 1.75) == expected[index * 3 + 1], "Dedicated stream changed legacy stat-range sampling.")
		_expect(float(compatibility_rng.randi_range(0, index % 13)) == expected[index * 3 + 2], "Dedicated stream changed bounded integer draw ordering.")
	var generator = preload("res://Game/relic_generation_manager.gd").new()
	var rng := RandomNumberGenerator.new()
	var replay := RandomNumberGenerator.new()
	rng.seed = 123456
	replay.seed = 123456
	for index in range(200):
		var tier: int = 1 + index % 3
		var result: Dictionary = generator.generate_relic(tier, rng, 0.05)
		randf()
		var duplicate: Dictionary = generator.generate_relic(tier, replay, 0.05)
		_expect(result == duplicate, "Explicit relic RNG did not replay its selection/name/stat rolls.")
		var definition: Dictionary = result["generated_definition"]
		var ranges: Array = generator.EFFECT_DEFINITIONS[definition["effect_id"]]["roll_ranges"][result["tier"]]
		_expect(float(result["rolled_value"]) >= float(ranges[0]) and float(result["rolled_value"]) <= float(ranges[1]), "Relic stat escaped its unchanged configured range.")
		_expect(int(result["tier"]) == tier or int(result["tier"]) == generator.get_next_tier(tier), "Critical promotion escaped its existing tier rules.")
	_expect(rng.state == replay.state, "Relic replay consumed different numbers of RNG draws.")


func _rng_saved_values_equal(a: Variant, b: Variant) -> bool:
	# Existing save JSON decimal roundoff is outside RNG isolation's scope.
	# New rolls and RNG words are checked exactly by the tests above.
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _rng_saved_values_equal(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for index in range(a.size()):
			if not _rng_saved_values_equal(a[index], b[index]):
				return false
		return true
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) <= maxf(1.0, absf(float(a))) * 1e-12
	return a == b


func _run_async_test(test_name: String, test_callable: Callable) -> void:
	var errors_before: int = _failed
	await test_callable.call()
	if _failed == errors_before:
		_passed += 1
		print("[PASS] " + test_name)
	else:
		print("[FAIL] " + test_name)


func _check_batch_c_failures(test: RefCounted) -> void:
	for message in test.failures:
		_expect(false, message)


func _test_batch_c_index() -> void:
	var test = preload("res://tests/offline_batch_c_tests.gd").new()
	test.test_index_parity()
	_check_batch_c_failures(test)


func _test_batch_c_starvation() -> void:
	var test = preload("res://tests/offline_batch_c_tests.gd").new()
	test.test_starvation()
	_check_batch_c_failures(test)


func _test_batch_c_save() -> void:
	var test = preload("res://tests/offline_batch_c_tests.gd").new()
	test.test_save_load()
	_check_batch_c_failures(test)


func _test_batch_c_scheduling() -> void:
	var test = preload("res://tests/offline_batch_c_tests.gd").new()
	await test.test_scheduling()
	_check_batch_c_failures(test)


func _test_batch_c_short() -> void:
	var test = preload("res://tests/offline_batch_c_tests.gd").new()
	await test.test_short_durations()
	_check_batch_c_failures(test)


func _test_experimental_checkpoint() -> void:
	var test = preload("res://tests/experimental/adaptive_tests.gd").new()
	test.test_checkpoint()
	for message in test.failures:
		_expect(false, message)


func _test_experimental_restricted() -> void:
	var test = preload("res://tests/experimental/adaptive_tests.gd").new()
	test.test_restricted()
	for message in test.failures:
		_expect(false, message)


func _test_experimental_fallbacks() -> void:
	var test = preload("res://tests/experimental/adaptive_tests.gd").new()
	test.test_fallbacks()
	for message in test.failures:
		_expect(false, message)


func _test_experimental_threshold_order() -> void:
	var test = preload("res://tests/experimental/adaptive_tests.gd").new()
	test.test_threshold_order()
	for message in test.failures:
		_expect(false, message)


func _test_experimental_rejection() -> void:
	var test = preload("res://tests/experimental/adaptive_tests.gd").new()
	test.test_rejection()
	for message in test.failures:
		_expect(false, message)


func _test_experimental_save_load() -> void:
	var test = preload("res://tests/experimental/adaptive_tests.gd").new()
	test.test_save_load()
	for message in test.failures:
		_expect(false, message)


func _test_experimental_configuration() -> void:
	var test = preload("res://tests/experimental/adaptive_tests.gd").new()
	test.test_configuration()
	for message in test.failures:
		_expect(false, message)


func _test_feedback_targets() -> void:
	var test = preload("res://tests/experimental/feedback_tests.gd").new()
	test.test_feedback_targets()
	for failure in test.failures:
		_expect(false, failure)


func _test_feedback_long_clocks() -> void:
	var test = preload("res://tests/experimental/feedback_tests.gd").new()
	test.test_feedback_long_clocks()
	for failure in test.failures:
		_expect(false, failure)


func _test_feedback_fallbacks() -> void:
	var test = preload("res://tests/experimental/feedback_tests.gd").new()
	test.test_feedback_fallbacks()
	for failure in test.failures:
		_expect(false, failure)


func _test_feedback_retry_control() -> void:
	var test = preload("res://tests/experimental/feedback_tests.gd").new()
	test.test_feedback_retry_control()
	for failure in test.failures:
		_expect(false, failure)


func _test_feedback_save_short() -> void:
	var test = preload("res://tests/experimental/feedback_tests.gd").new()
	test.test_feedback_save_short()
	for failure in test.failures:
		_expect(false, failure)


func _test_feedback_offline_entry() -> void:
	var test = preload("res://tests/experimental/feedback_tests.gd").new()
	test.test_feedback_offline_entry()
	for failure in test.failures:
		_expect(false, failure)


func _test_horizon_modes() -> void:
	var test = preload("res://tests/experimental/horizon_tests.gd").new()
	test.test_modes()
	for failure in test.failures:
		_expect(false, failure)


func _test_horizon_exact_cleanups() -> void:
	var test = preload("res://tests/experimental/horizon_tests.gd").new()
	test.test_exact_cleanups()
	for failure in test.failures:
		_expect(false, failure)


func _test_horizon_diagnostics() -> void:
	var test = preload("res://tests/experimental/horizon_tests.gd").new()
	test.test_diagnostics()
	for failure in test.failures:
		_expect(false, failure)


func _test_horizon_prestige_protection() -> void:
	var test = preload("res://tests/experimental/horizon_tests.gd").new()
	test.test_prestige_protection()
	for failure in test.failures:
		_expect(false, failure)


func _test_horizon_fallbacks() -> void:
	var test = preload("res://tests/experimental/horizon_tests.gd").new()
	test.test_fallbacks()
	for failure in test.failures:
		_expect(false, failure)


func _test_horizon_monotone_margin() -> void:
	var test = preload("res://tests/experimental/horizon_tests.gd").new()
	test.test_monotone_margin()
	for failure in test.failures:
		_expect(false, failure)


func _test_autobuyer_waiting() -> void:
	var test = preload("res://tests/experimental/autobuyer_tests.gd").new()
	test.test_waiting()
	for failure in test.failures:
		_expect(false, failure)


func _test_autobuyer_purchases() -> void:
	var test = preload("res://tests/experimental/autobuyer_tests.gd").new()
	test.test_purchase_boundaries()
	for failure in test.failures:
		_expect(false, failure)


func _test_autobuyer_invalidation() -> void:
	var test = preload("res://tests/experimental/autobuyer_tests.gd").new()
	test.test_proof_invalidation()
	for failure in test.failures:
		_expect(false, failure)


func _test_autobuyer_short() -> void:
	var test = preload("res://tests/experimental/autobuyer_tests.gd").new()
	test.test_zero_short()
	for failure in test.failures:
		_expect(false, failure)


func _test_cooldown_success_and_waiting() -> void:
	var test = preload("res://tests/autobuyer_cooldown_tests.gd").new()
	test.test_success_and_waiting()
	for failure in test.failures:
		_expect(false, failure)


func _test_cooldown_requirements_and_preferences() -> void:
	var test = preload("res://tests/autobuyer_cooldown_tests.gd").new()
	test.test_requirements_and_preferences()
	for failure in test.failures:
		_expect(false, failure)


func _test_cooldown_priority_and_competition() -> void:
	var test = preload("res://tests/autobuyer_cooldown_tests.gd").new()
	test.test_priority_and_competition()
	for failure in test.failures:
		_expect(false, failure)


func _test_cooldown_large_delta() -> void:
	var test = preload("res://tests/autobuyer_cooldown_tests.gd").new()
	test.test_large_delta()
	for failure in test.failures:
		_expect(false, failure)


func _test_cooldown_save_and_reset() -> void:
	var test = preload("res://tests/autobuyer_cooldown_tests.gd").new()
	test.test_save_and_reset()
	for failure in test.failures:
		_expect(false, failure)


func _test_autobuyer_replay_elimination() -> void:
	var test = preload("res://tests/experimental/autobuyer_tests.gd").new()
	test.test_replay_elimination()
	for failure in test.failures:
		_expect(false, failure)


func _test_resource_flow_bounds() -> void:
	var test = preload("res://tests/experimental/resource_flow_tests.gd").new()
	test.run_all()
	for failure: String in test.failures:
		_expect(false, failure)
