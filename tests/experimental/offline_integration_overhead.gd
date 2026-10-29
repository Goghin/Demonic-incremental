extends SceneTree

const UserScope = preload("res://tests/experimental/offline_study_user_scope.gd")

const Packet = preload("res://tests/experimental/exact_flow_packet.gd")
const Previous = preload("res://tests/experimental/baselines/exact_flow_182e562_packet.gd")
const Equipment = preload("res://tests/experimental/exact_flow_equipment.gd")
const Cycles = preload("res://tests/experimental/exact_flow_cycles.gd")
const Tests = preload("res://tests/experimental/relic_crafting_tests.gd")
var rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var user_error: String = UserScope.rejection()
	if not user_error.is_empty():
		push_error(user_error)
		quit(1)
		return
	for label: String in ["early", "mid", "reached_multiple", "earned_craft_first_craft", "auto_standard", "late_mixed", "reject_logger", "reject_observer"]:
		for repeat: int in range(11):
			var context: Dictionary = Tests.context("earned_craft_first_craft" if label.begins_with("reject_") else label)
			var simulation: Simulation = context["simulation"]
			if label == "reject_logger":
				simulation.state.gameplay_log = GameplayLog.new()
			elif label == "reject_observer":
				simulation.relic_crafting_completed.connect(_observer)
			var before: int = OS.get_static_memory_usage()
			var start: int = Time.get_ticks_usec()
			var packet: RefCounted = Packet.new()
			var admitted: bool = packet.build(simulation, context["journal"])
			var rejection: String = packet.error
			var allocation: int = OS.get_static_memory_usage() - before
			var build_usec: int = Time.get_ticks_usec() - start
			start = Time.get_ticks_usec()
			var equipment_error: String = Equipment.rejection(simulation.state)
			var equipment_usec: int = Time.get_ticks_usec() - start
			start = Time.get_ticks_usec()
			for generator: Generator in simulation.state.generators.values():
				if generator.definition.cycle_based:
					Cycles.rejection(generator, simulation.state)
			var cycles_usec: int = Time.get_ticks_usec() - start
			start = Time.get_ticks_usec()
			for iteration: int in range(1000):
				packet.event_due()
			var event_usec: int = Time.get_ticks_usec() - start
			start = Time.get_ticks_usec()
			packet = null
			var release_usec: int = Time.get_ticks_usec() - start
			var previous: RefCounted = Previous.new()
			start = Time.get_ticks_usec()
			var old_admitted: bool = previous.build(simulation, context["journal"])
			var previous_build_usec: int = Time.get_ticks_usec() - start
			rows.append({"label": label, "repeat": repeat, "warmup": repeat == 0, "admitted": admitted, "rejection": rejection, "build_usec": build_usec, "equipment_usec": equipment_usec, "equipment_error": equipment_error, "cycle_contract_usec": cycles_usec, "event_checks_1000_usec": event_usec, "release_usec": release_usec, "retained_allocation_estimate_bytes": allocation, "previous_admitted": old_admitted, "previous_build_usec": previous_build_usec})
	var output := FileAccess.open("res://tests/experimental/offline_integration_overhead.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine": Engine.get_version_info(), "cpu": OS.get_processor_name(), "rows": rows}, "\t") + "\n")
	print("OFFLINE_OVERHEAD samples=", rows.size())
	quit()


func _observer(_name: String, _quantity: int, _critical: bool) -> void:
	pass
