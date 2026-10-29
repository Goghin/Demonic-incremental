extends RefCounted

# Reviewed collector. Optional benchmark clocks write only local diagnostics.
var events: Array[Dictionary] = []
var observer_instrument: bool = false
var observer_calls: int = 0
var observer_usec: int = 0


func attach(simulation: Simulation) -> void:
	simulation.generator_unlocked.connect(generator_unlocked)
	simulation.crystallization_completed.connect(crystallization_completed)
	simulation.critical_crystallization_completed.connect(critical_crystallization_completed)
	simulation.relic_crafting_completed.connect(relic_crafting_completed)
	simulation.generator_level_reduced.connect(generator_level_reduced)


func generator_unlocked(id: String) -> void:
	var started: int = Time.get_ticks_usec() if observer_instrument else 0
	events.append({"event": "unlock", "id": id})
	if observer_instrument:
		observer_calls += 1
		observer_usec += Time.get_ticks_usec() - started


func crystallization_completed(amount: float) -> void:
	var started: int = Time.get_ticks_usec() if observer_instrument else 0
	events.append({"event": "normal", "amount": amount})
	if observer_instrument:
		observer_calls += 1
		observer_usec += Time.get_ticks_usec() - started


func critical_crystallization_completed(amount: float) -> void:
	var started: int = Time.get_ticks_usec() if observer_instrument else 0
	events.append({"event": "critical", "amount": amount})
	if observer_instrument:
		observer_calls += 1
		observer_usec += Time.get_ticks_usec() - started


func relic_crafting_completed(name: String, quantity: int, critical: bool) -> void:
	var started: int = Time.get_ticks_usec() if observer_instrument else 0
	events.append({"event": "relic", "name": name, "quantity": quantity, "critical": critical})
	if observer_instrument:
		observer_calls += 1
		observer_usec += Time.get_ticks_usec() - started


func generator_level_reduced(id: String, previous: int, current: int) -> void:
	var started: int = Time.get_ticks_usec() if observer_instrument else 0
	events.append({"event": "downlevel", "id": id, "previous": previous, "current": current})
	if observer_instrument:
		observer_calls += 1
		observer_usec += Time.get_ticks_usec() - started
