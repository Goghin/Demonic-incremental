extends RefCounted

# The only supported signal sink. No callbacks, clock or external side effects.
var events: Array[Dictionary] = []


func attach(simulation: Simulation) -> void:
	simulation.generator_unlocked.connect(generator_unlocked)
	simulation.crystallization_completed.connect(crystallization_completed)
	simulation.critical_crystallization_completed.connect(critical_crystallization_completed)
	simulation.relic_crafting_completed.connect(relic_crafting_completed)
	simulation.generator_level_reduced.connect(generator_level_reduced)


func generator_unlocked(id: String) -> void:
	events.append({"event": "unlock", "id": id})


func crystallization_completed(amount: float) -> void:
	events.append({"event": "normal", "amount": amount})


func critical_crystallization_completed(amount: float) -> void:
	events.append({"event": "critical", "amount": amount})


func relic_crafting_completed(name: String, quantity: int, critical: bool) -> void:
	events.append({"event": "relic", "name": name, "quantity": quantity, "critical": critical})


func generator_level_reduced(id: String, previous: int, current: int) -> void:
	events.append({"event": "downlevel", "id": id, "previous": previous, "current": current})
