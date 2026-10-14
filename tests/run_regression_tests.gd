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
