extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tests: RefCounted = preload("res://tests/experimental/transaction_tests.gd").new()
	var result: Dictionary = tests.run_all()
	var snapshot: RefCounted = preload("res://tests/experimental/transaction_checkpoint.gd").new()
	var simulation := Simulation.new(preload("res://tests/experimental/core_fixtures.gd").make_state("forge_competing"))
	simulation.state.simulation_statistics = ResourceStatistics.new()
	var journal: RefCounted = preload("res://tests/experimental/transaction_events.gd").new()
	journal.attach(simulation)
	if not snapshot.capture(simulation, journal):
		tests.failures.append(snapshot.error)
	var inventory := FileAccess.open("res://tests/experimental/transaction_state_inventory.json", FileAccess.WRITE)
	inventory.store_string(JSON.stringify(snapshot.describe(), "\t") + "\n")
	inventory.close()
	var output := FileAccess.open("res://tests/experimental/checkpoint_transaction_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t") + "\n")
	output.close()
	for failure: String in tests.failures:
		push_error(failure)
	print("TRANSACTION_TESTS " + JSON.stringify(result))
	quit(0 if tests.failures.is_empty() else 1)
