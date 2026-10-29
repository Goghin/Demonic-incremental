extends SceneTree

const Core = preload("res://tests/experimental/core_fixtures.gd")
const Flows = preload("res://tests/experimental/resource_flow_fixtures.gd")
const Horizon = preload("res://tests/experimental/horizon_fixtures.gd")
const Kernel = preload("res://tests/experimental/exact_flow_kernel.gd")
const Cycles = preload("res://tests/experimental/exact_flow_cycles.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const Equipment = preload("res://tests/experimental/exact_flow_equipment.gd")
const Generation = preload("res://Game/relic_generation_manager.gd")
const Oracle = preload("res://tests/experimental/transaction_tests.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rows: Array[Dictionary] = []
	for label: String in ["transfer", "late_both", "mixed", "essence", "cycles"]:
		var original: GameState = Horizon.make_state("essence") if label == "essence" else Flows.make_state(label)
		# Canonical save-loaded diagnostics, not reached progression evidence.
		var saved: Dictionary = SaveManager.new().state_to_dictionary(original)
		var candidate := Simulation.new(Core.from_save(saved))
		var control := Simulation.new(Core.from_save(saved))
		var journal: RefCounted = Events.new()
		var reference: RefCounted = Events.new()
		journal.attach(candidate)
		reference.attach(control)
		var initial: Dictionary = _inventory(candidate.state)
		var runner: RefCounted = Kernel.new(candidate, journal)
		runner.run(10)
		for tick: int in range(10):
			control.update(TimeManager.OFFLINE_MAX_GAME_STEP, true)
		var oracle: RefCounted = Oracle.new()
		var parity: bool = oracle.fingerprint(candidate, journal) == oracle.fingerprint(control, reference)
		failures.append_array(oracle.failures)
		if not parity:
			failures.append("Scope audit parity: " + label)
		rows.append({"label": label, "diagnostic_save_load": true, "ticks": 10, "binary_parity": parity, "initial": initial, "final": _inventory(candidate.state), "counters": runner.counters.duplicate(true)})
	var output := FileAccess.open("res://tests/experimental/relic_equipment_scope_audit.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"rows": rows, "failures": failures, "equipment_contract": Equipment.CONTRACT, "tiers": Generation.TIER_DEFINITIONS, "effects": Generation.EFFECT_DEFINITIONS}, "\t") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("RELIC_EQUIPMENT_SCOPE_AUDIT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)


func _inventory(state: GameState) -> Dictionary:
	var cycles: Array[Dictionary] = []
	var transfers: Array[String] = []
	var essence: Array[String] = []
	for generator: Generator in state.generators.values():
		if generator.cycle_active or generator.auto_run_cycles:
			cycles.append({"id": generator.definition.id, "rejection": Cycles.rejection(generator, state)})
		if generator.unlocked and generator.get_operation_mode().is_resource_transfer:
			transfers.append(generator.definition.id)
		for modifier: Modifier in generator.modifiers:
			if modifier.dynamic and modifier.dynamic_resource_id == ResourceIds.ESSENCE:
				essence.append(generator.definition.id + "/" + modifier.id)
	return {"transfers_supported": true, "essence_nexum_supported": true, "cycles": cycles, "transfers": transfers, "essence_modifiers": essence, "inventory_entries": state.relic_manager.inventory.size()}
