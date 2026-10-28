extends RefCounted

const Reference = preload("res://tests/experimental/transaction_checkpoint.gd")
const Compact = preload("res://tests/experimental/compact_checkpoint.gd")
const Fixtures = preload("res://tests/experimental/core_fixtures.gd")
const Automation = preload("res://tests/experimental/autobuyer_fixtures.gd")
const Transaction = preload("res://tests/experimental/simulation_transaction.gd")
const Differential = preload("res://tests/experimental/transaction_tests.gd")
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func run_all() -> void:
	for implementation: Script in [Reference, Compact]:
		_nested(implementation)
		_waiting(implementation)
		_unsupported(implementation)


func _nested(implementation: Script) -> void:
	var simulation := Simulation.new(Fixtures.make_state("forge_competing"))
	var state: GameState = simulation.state
	var generator: Generator = state.get_generator("infernal_forge")
	var mode: GeneratorOperationMode = generator.get_operation_mode()
	var modifier: Modifier = generator.modifiers[0]
	var equal_a: Dictionary = {"value": 1.0}
	var equal_b: Dictionary = {"value": 1.0}
	state.last_prestige_report["nested"] = [{"phase": generator.production_progress, "object": modifier, "child": [{"value": 1.5}]}]
	state.last_prestige_report["equal_a"] = equal_a
	state.last_prestige_report["equal_b"] = equal_b
	state.last_prestige_report["self"] = state.last_prestige_report
	state.relic_manager.add_random_relic_for_tier(1, 0.25)
	var inventory: Array[Dictionary] = state.relic_manager.inventory
	var entry: Dictionary = inventory[0]
	var oracle: RefCounted = Differential.new()
	var before: PackedByteArray = oracle.fingerprint(simulation)
	var transaction: RefCounted = Transaction.new(simulation, null, implementation)
	for repeat: int in range(4):
		check(transaction.begin(), "Nested probe begin failed")
		generator.cycle_progress += 12.5
		generator.production_progress[ResourceIds.MATTER] = 0.8125
		mode.cycle_duration += 7.0
		mode.completion_item_outputs.append({"item_id": "relic_shard", "quantity": 2, "nested": [{"amount": 0.5}]})
		mode.completion_outputs[0].amount_per_second += 1.25
		modifier.multiplier += 0.125
		state.last_prestige_report["nested"][0]["child"][0]["value"] = 999.0
		equal_a["new"] = [1, 2, {"shared": equal_b}]
		equal_b["value"] = 9.0
		entry["generated_definition"]["display_name"] = "candidate-only"
		state.relic_manager.equipped[generator.definition.id] = [entry["instance_id"]]
		state.get_upgrade("thermal_conversion").definition.effects[0].event_source_upgrade_id = "candidate-only"
		check(transaction.rollback(), "Nested rollback failed")
		check(oracle.fingerprint(simulation) == before, "Nested definition/runtime data leaked")
		check(is_same(equal_a, state.last_prestige_report["equal_a"]) and is_same(equal_b, state.last_prestige_report["equal_b"]) and not is_same(equal_a, equal_b), "Equal dictionaries were merged")
		check(is_same(state.last_prestige_report["nested"][0]["phase"], generator.production_progress), "Phase alias was lost")
		check(is_same(entry, inventory[0]) and is_same(inventory, state.relic_manager.inventory), "Relic aliases were lost")
		# Interleave successful resolution with rejected attempts on the same owner.
		check(transaction.begin(), "Interleaved commit begin failed")
		check(transaction.commit(), "Interleaved commit failed")
	check(oracle.failures.is_empty(), "Reference fingerprint failed")
	state.last_prestige_report.clear()


func _waiting(implementation: Script) -> void:
	var state: GameState = Automation.make_state("all_wait")
	var simulation := Simulation.new(state)
	var oracle: RefCounted = Differential.new()
	var before: PackedByteArray = oracle.fingerprint(simulation)
	var transaction: RefCounted = Transaction.new(simulation, null, implementation)
	check(transaction.begin(), "Waiting begin failed")
	for tick: int in range(100):
		transaction.advance(0.1)
	var waiting: bool = false
	for item: Dictionary in state.generator_automation_manager.automation_states.values():
		waiting = waiting or bool(item["waiting_for_resources"])
	check(waiting, "Unsuccessful generator buyer did not enter waiting state")
	check(transaction.rollback(), "Waiting rollback failed")
	check(oracle.fingerprint(simulation) == before, "Waiting cost/cooldown/cache drift")


func _unsupported(implementation: Script) -> void:
	var simulation := Simulation.new(Fixtures.make_state("early"))
	var transaction: RefCounted = Transaction.new(simulation, null, implementation)
	simulation.state.last_prestige_report["packed"] = PackedFloat64Array([0.5])
	check(not transaction.begin(), "Unsupported packed mutable data accepted")
	simulation.state.last_prestige_report.clear()
	# Exercise a dynamically added signal after the descriptor cache is warm.
	check(transaction.begin() and transaction.rollback(), "Warm schema capture failed")
	var generator: Generator = simulation.state.get_generator("atomic_friction")
	generator.add_user_signal("external_side_effect")
	var callback: Callable = func() -> void: pass
	generator.connect("external_side_effect", callback, CONNECT_DEFERRED)
	check(not transaction.begin(), "Deferred dynamic observer accepted")
	generator.disconnect("external_side_effect", callback)
	check(not transaction.error.is_empty(), "Unsupported operation supplied no explanation")
