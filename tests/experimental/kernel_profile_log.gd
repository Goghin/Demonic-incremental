extends RefCounted
var events: Array[Dictionary] = []
var measured_usec: int = 0
var measured_calls: int = 0


func record_event(category: String, event: String, details: Dictionary = {}, source: String = "game") -> void:
	var started: int = Time.get_ticks_usec()
	events.append({"category": category, "event": event, "details": details.duplicate(true), "source": source, "tick": 0})
	measured_usec += Time.get_ticks_usec() - started
	measured_calls += 1
