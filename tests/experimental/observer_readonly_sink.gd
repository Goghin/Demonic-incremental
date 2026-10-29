extends RefCounted

# Closed experimental receiver: primitive local writes ONLY. No Array,
# Dictionary, Object, Callable or simulation reference can alias gameplay state.
# Exact script identity excludes arbitrary overrides. This is not a trust API.
var observer_instrument: bool = false
var observer_calls: int = 0
var observer_usec: int = 0
var unlocks: int = 0
var normal: int = 0
var critical: int = 0
var relics: int = 0
var downlevels: int = 0
var last_id: String = ""
var last_amount: float = 0.0
var last_quantity: int = 0
var last_critical: bool = false

func attach(simulation: Simulation) -> void:
	simulation.generator_unlocked.connect(generator_unlocked)
	simulation.crystallization_completed.connect(crystallization_completed)
	simulation.critical_crystallization_completed.connect(critical_crystallization_completed)
	simulation.relic_crafting_completed.connect(relic_crafting_completed)
	simulation.generator_level_reduced.connect(generator_level_reduced)

func generator_unlocked(id: String) -> void:
	var started: int = Time.get_ticks_usec() if observer_instrument else 0
	unlocks += 1
	last_id = id
	_finish(started)

func crystallization_completed(amount: float) -> void:
	var started: int = Time.get_ticks_usec() if observer_instrument else 0
	normal += 1
	last_amount = amount
	_finish(started)

func critical_crystallization_completed(amount: float) -> void:
	var started: int = Time.get_ticks_usec() if observer_instrument else 0
	critical += 1
	last_amount = amount
	_finish(started)

func relic_crafting_completed(name: String, quantity: int, is_critical: bool) -> void:
	var started: int = Time.get_ticks_usec() if observer_instrument else 0
	relics += 1
	last_id = name
	last_quantity = quantity
	last_critical = is_critical
	_finish(started)

func generator_level_reduced(id: String, previous: int, current: int) -> void:
	var started: int = Time.get_ticks_usec() if observer_instrument else 0
	downlevels += 1
	last_id = id
	last_quantity = previous - current
	_finish(started)

func _finish(started: int) -> void:
	if observer_instrument:
		observer_calls += 1
		observer_usec += Time.get_ticks_usec() - started

func snapshot() -> Array:
	return [unlocks, normal, critical, relics, downlevels, last_id, last_amount, last_quantity, last_critical]
