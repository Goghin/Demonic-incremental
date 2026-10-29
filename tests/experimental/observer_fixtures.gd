extends RefCounted

const Crafting = preload("res://tests/experimental/relic_crafting_tests.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const Sink = preload("res://tests/experimental/observer_readonly_sink.gd")
const External = preload("res://tests/experimental/observer_fixture_callback.gd")

static func context(label: String, workload: String, instrument: bool = false) -> Dictionary:
	var item: Dictionary = Crafting.context(label)
	var simulation: Simulation = item["simulation"]
	var journal: RefCounted = item["journal"]
	if workload == "automation":
		Crafting.Fixtures.Equipment.Cycles.Automation.Buyers.enable(simulation.state, "atomic_friction")
	var receivers: Array[RefCounted] = [journal]
	journal.observer_instrument = instrument
	if workload == "none":
		for info: Dictionary in simulation.get_signal_list():
			for connection: Dictionary in simulation.get_signal_connection_list(info["name"]):
				simulation.disconnect(info["name"], connection["callable"])
		receivers.clear()
		item["journal"] = null
	elif workload in ["readonly", "heavy", "mixed"]:
		for _index: int in range(8 if workload == "heavy" else 2):
			var sink: RefCounted = Sink.new()
			sink.observer_instrument = instrument
			sink.attach(simulation)
			receivers.append(sink)
	if workload not in ["none", "journal", "readonly", "heavy"]:
		var shared_order: Array = []
		for index: int in range(2 if workload == "mixed" else 1):
			var external: RefCounted = External.new()
			external.action = "observe" if workload == "mixed" else workload
			external.tag = str(index)
			external.order = shared_order
			external.observer_instrument = instrument
			external.attach(simulation)
			receivers.append(external)
	item["receivers"] = receivers
	return item

static func observable(item: Dictionary) -> PackedByteArray:
	var result: Array = []
	for receiver: RefCounted in item["receivers"]:
		if receiver.get_script() == External:
			result.append([receiver.order, receiver.observations, receiver.acted, receiver.added_sink.snapshot() if receiver.added_sink != null else []])
		elif receiver.get_script() == Sink:
			result.append(receiver.snapshot())
		else:
			result.append(receiver.events)
	return var_to_bytes(result)

static func release(item: Dictionary) -> void:
	# Unsupported callback fixture holds Simulation; disconnect to break cycles.
	for receiver: RefCounted in item["receivers"]:
		if receiver.get_script() == External:
			receiver.detach()
			receiver.simulation = null

static func invocations(item: Dictionary) -> int:
	var total: int = 0
	for receiver: RefCounted in item["receivers"]:
		if receiver.get_script() == External:
			total += receiver.observations.size()
			if receiver.added_sink != null:
				var sink: RefCounted = receiver.added_sink
				total += sink.unlocks + sink.normal + sink.critical + sink.relics + sink.downlevels
		elif receiver.get_script() == Sink:
			total += receiver.unlocks + receiver.normal + receiver.critical + receiver.relics + receiver.downlevels
		else:
			total += receiver.events.size()
	return total
