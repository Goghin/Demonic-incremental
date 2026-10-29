extends RefCounted

# Deliberately NOT a kernel capability. Even the 'observe' action must fall
# back: action and dependencies are mutable fields, not a safety contract.
const Events = preload("res://tests/experimental/observer_readonly_sink.gd")
var simulation: Simulation
var action: String = "observe"
var tag: String = "external"
var order: Array = []
var observations: Array = []
var observer_instrument: bool = false
var _calls: int = 0
var _usec: int = 0
var observer_calls: int:
	get:
		return _calls + (added_sink.observer_calls if added_sink != null else 0)
var observer_usec: int:
	get:
		return _usec + (added_sink.observer_usec if added_sink != null else 0)
var acted: bool = false
var added_sink: RefCounted

func attach(target: Simulation) -> void:
	simulation = target
	target.generator_unlocked.connect(generator_unlocked)
	target.crystallization_completed.connect(crystallization_completed)
	target.critical_crystallization_completed.connect(critical_crystallization_completed)
	target.relic_crafting_completed.connect(relic_crafting_completed)
	target.generator_level_reduced.connect(generator_level_reduced)

func detach() -> void:
	for signal_info: Dictionary in simulation.get_signal_list():
		for connection: Dictionary in simulation.get_signal_connection_list(signal_info["name"]):
			var callback: Callable = connection["callable"]
			if callback.get_object() == self:
				simulation.disconnect(signal_info["name"], callback)

func generator_unlocked(id: String) -> void:
	_receive("unlock", [id])

func crystallization_completed(amount: float) -> void:
	_receive("normal", [amount])

func critical_crystallization_completed(amount: float) -> void:
	_receive("critical", [amount])

func relic_crafting_completed(name: String, quantity: int, critical: bool) -> void:
	_receive("relic", [name, quantity, critical])

func generator_level_reduced(id: String, previous: int, current: int) -> void:
	_receive("downlevel", [id, previous, current])

func _receive(event: String, arguments: Array) -> void:
	var started: int = Time.get_ticks_usec() if observer_instrument else 0
	var state: GameState = simulation.state
	order.append([tag, event])
	observations.append([event, arguments, state.get_resource_amount(ResourceIds.HEAT), state.get_resource_amount(ResourceIds.MATTER), state.get_generator("atomic_friction").level, state.gameplay_rng.state])
	if not acted:
		acted = true
		match action:
			"resource": state.set_resource_amount(ResourceIds.HEAT, state.get_resource_amount(ResourceIds.HEAT) + 17.0)
			"upgrade":
				var generator: Generator = state.get_generator("atomic_friction")
				state.set_resource_amount(generator.definition.cost_resource_id, generator.get_cost(state))
				assert(simulation.buy_generator("atomic_friction", "observer_fixture"))
			"automation":
				state.generator_automation_manager.set_enabled("atomic_friction", false)
			"inventory": state.relic_manager.add_random_relic_for_tier(1)
			"register":
				added_sink = Events.new()
				added_sink.observer_instrument = observer_instrument
				added_sink.attach(simulation)
			"remove": detach()
			"replace":
				added_sink = Events.new()
				added_sink.observer_instrument = observer_instrument
				added_sink.attach(simulation)
				detach()
	if observer_instrument:
		_calls += 1
		_usec += Time.get_ticks_usec() - started
