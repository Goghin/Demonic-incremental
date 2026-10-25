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
	_run_test("Heat leak and Matter decay respect their thresholds", _test_environmental_thresholds)
	_run_test("Generator purchase rejects insufficient resources", _test_purchase_rejects_insufficient_resources)
	_run_test("Generator purchase spends the exact cost and adds one level", _test_successful_generator_purchase)
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
	_expect(manager.get_relic_description(normal_relic).contains("Rolled:"), "Generated relic description omitted its primary roll.")

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
	_expect(state.relic_manager.get_relic_description(relic).contains("Rolled:"), "Relic tooltip does not expose the instance's rolled stat.")

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
