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
	_run_test("Brazier upgrades permanently unlock flame stats in order", _test_brazier_upgrade_unlocks)
	_run_test("Reliquary and generator relic slots unlock through Prestige progression", _test_reliquary_slot_progression)
	_run_test("Reliquary grants, equips, saves, and preserves relics", _test_relic_inventory_equipment_and_save)
	_run_test("Relic instances roll targeted stats and preserve rolls in saves", _test_rolled_relic_stats)
	_run_test("Relics support sensitivity stats and saved uncommon bonus stats", _test_relic_sensitivity_and_secondary_stats)
	_run_test("Relics modify cycle critical and downlevel chances additively", _test_relic_event_chance_modifiers)
	_run_test("Relic Shards stack, merge, and persist in inventory", _test_relic_shard_stacks)
	_run_test("Machine crafting slots preserve, consume, and return ingredients", _test_machine_crafting_slots)
	_run_test("Crafting recipes are validated and consumed when a cycle starts", _test_crafting_cycle_start)
	_run_test("Relic Shard Extractor exposes five crafting modes and tiered rewards", _test_relic_shard_extractor_modes)
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
	_expect(state.eternal_flame_state.get_upgrade_level("eternal_furnace") == 1, "First-prestige Eternal Furnace bonus was lost.")
	_expect(state.eternal_flame_state.get_upgrade_level("accelerated_friction") == 1, "First-prestige acceleration bonus was lost.")

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
	var relic_id := str(state.relic_manager.inventory[0].get("instance_id", ""))
	_expect(state.relic_manager.equip_relic("atomic_friction", relic_id, state), "Starter relic could not be equipped.")
	state.rebuild_relic_modifiers()
	var generator: Generator = state.get_generator("atomic_friction")
	var relic_modifier_found := false
	for modifier in generator.modifiers:
		if modifier.id == "relic:" + relic_id:
			relic_modifier_found = true
	_expect(relic_modifier_found, "Equipping a relic did not add its modifier to the generator.")
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
	loaded_state.reset_current_run()
	_expect(loaded_state.relic_manager.get_equipped_relic_id("atomic_friction") != "", "Realm reset incorrectly removed equipped relics.")
	var reset_modifier_found := false
	for modifier in loaded_state.get_generator("atomic_friction").modifiers:
		if modifier.id.begins_with("relic:"):
			reset_modifier_found = true
	_expect(reset_modifier_found, "Equipped relic modifier was not restored after realm reset.")




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
	var recycled_relic_id := state.relic_manager.add_relic("clockwork_ember")
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
	var relic_id := state.relic_manager.add_relic("cinder_shard")
	var relic: Dictionary = state.relic_manager.get_relic(relic_id)
	var rolled_value := float(relic.get("rolled_value", 0.0))
	_expect(rolled_value >= 1.05 and rolled_value <= 1.15, "Cinder Shard roll fell outside its configured range.")
	_expect(state.relic_manager.get_relic_description(relic).contains("Rolled:"), "Relic tooltip does not expose the instance's rolled stat.")

	state.eternal_flame_state.eternal_flame = 100.0
	_expect(state.eternal_flame_upgrade_manager.purchase("reliquary", state.eternal_flame_state, state.realm_configuration), "Could not unlock Reliquary for rolled-stat test.")
	_expect(state.relic_manager.equip_relic("atomic_friction", relic_id, state), "Could not equip rolled Cinder Shard.")
	state.rebuild_relic_modifiers()
	var found_targeted_modifier := false
	for modifier in state.get_generator("atomic_friction").modifiers:
		if modifier.id != "relic:" + relic_id:
			continue
		found_targeted_modifier = true
		_expect(modifier.type == ModifierTypes.PRODUCTION, "Cinder Shard did not use the production modifier type.")
		_expect(modifier.target_id == ResourceIds.HEAT, "Cinder Shard did not target Heat specifically.")
		_expect_approx(modifier.multiplier, rolled_value, "Equipped modifier did not use the instance's rolled value.")
	_expect(found_targeted_modifier, "Cinder Shard modifier was not rebuilt.")

	var save_data: Dictionary = SaveManager.new().state_to_dictionary(state)
	var loaded_state := _new_test_state()
	_expect(SaveManager.new().dictionary_to_state(loaded_state, save_data, 7), "Rolled relic save could not be loaded.")
	var loaded_relic: Dictionary = loaded_state.relic_manager.get_relic(relic_id)
	_expect_approx(float(loaded_relic.get("rolled_value", 0.0)), rolled_value, "Relic stat rerolled during save/load.")


func _test_relic_sensitivity_and_secondary_stats() -> void:
	var state := _new_test_state()
	var generator: Generator = state.get_generator("infernal_forge")
	var sensitivity_relic_id := state.relic_manager.add_relic("ashveil_charm")
	var sensitivity_relic: Dictionary = state.relic_manager.get_relic(sensitivity_relic_id)
	var sensitivity_value := float(sensitivity_relic.get("rolled_value", 1.0))
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

	var uncommon_id := state.relic_manager.add_relic("refined_matterheart")
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

	var relic_id := loaded_manager.add_relic("cinder_shard")
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
	var second_relic_id := state.relic_manager.add_relic("clockwork_ember")
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
	state.rebuild_relic_modifiers()
	var relic_modifier_count := 0
	for modifier in state.get_generator("atomic_friction").modifiers:
		if modifier.id.begins_with("relic:"):
			relic_modifier_count += 1
	_expect(relic_modifier_count == 2, "Both equipped relics were not applied as modifiers.")

	var legacy_manager := RelicManager.new()
	legacy_manager.load_save_data({
		"inventory": [{"instance_id": "relic_1", "definition_id": "cinder_shard"}],
		"equipped": {"atomic_friction": "relic_1"},
		"next_instance_number": 2
	})
	_expect(
		legacy_manager.get_equipped_relic_id("atomic_friction", 0) == "relic_1",
		"Legacy one-relic-per-generator save was not migrated to slot zero."
	)


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
