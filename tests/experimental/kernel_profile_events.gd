extends "res://tests/experimental/transaction_events.gd"
var handler_usec: int = 0
var handler_calls: int = 0


func generator_unlocked(id: String) -> void:
	var started: int = Time.get_ticks_usec()
	super.generator_unlocked(id)
	handler_usec += Time.get_ticks_usec() - started
	handler_calls += 1


func crystallization_completed(amount: float) -> void:
	var started: int = Time.get_ticks_usec()
	super.crystallization_completed(amount)
	handler_usec += Time.get_ticks_usec() - started
	handler_calls += 1


func critical_crystallization_completed(amount: float) -> void:
	var started: int = Time.get_ticks_usec()
	super.critical_crystallization_completed(amount)
	handler_usec += Time.get_ticks_usec() - started
	handler_calls += 1


func relic_crafting_completed(name: String, quantity: int, critical: bool) -> void:
	var started: int = Time.get_ticks_usec()
	super.relic_crafting_completed(name, quantity, critical)
	handler_usec += Time.get_ticks_usec() - started
	handler_calls += 1


func generator_level_reduced(id: String, previous: int, current: int) -> void:
	var started: int = Time.get_ticks_usec()
	super.generator_level_reduced(id, previous, current)
	handler_usec += Time.get_ticks_usec() - started
	handler_calls += 1
