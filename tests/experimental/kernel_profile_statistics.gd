extends ResourceStatistics
var measured_usec: Dictionary = {}
var measured_calls: Dictionary = {}


func _record(key: String, started: int) -> void:
	measured_usec[key] = int(measured_usec.get(key, 0)) + Time.get_ticks_usec() - started
	measured_calls[key] = int(measured_calls.get(key, 0)) + 1


func record_produced(resource_id: String, amount: float) -> void:
	var started: int = Time.get_ticks_usec()
	super.record_produced(resource_id, amount)
	_record("record_produced", started)


func record_consumed(resource_id: String, amount: float) -> void:
	var started: int = Time.get_ticks_usec()
	super.record_consumed(resource_id, amount)
	_record("record_consumed", started)


func record_lost(resource_id: String, amount: float) -> void:
	var started: int = Time.get_ticks_usec()
	super.record_lost(resource_id, amount)
	_record("record_lost", started)


func update_highest(resource_id: String, amount: float) -> void:
	var started: int = Time.get_ticks_usec()
	super.update_highest(resource_id, amount)
	_record("update_highest", started)


func record_overflow(amount: float) -> void:
	var started: int = Time.get_ticks_usec()
	super.record_overflow(amount)
	_record("record_overflow", started)


func record_matter_decayed(amount: float) -> void:
	var started: int = Time.get_ticks_usec()
	super.record_matter_decayed(amount)
	_record("record_matter_decayed", started)
