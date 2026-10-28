extends RefCounted

const Checkpoint = preload("res://tests/experimental/transaction_checkpoint.gd")
static var _owners: Dictionary = {}
var journal: RefCounted
var simulation: Simulation
var error: String = ""
var _checkpoint: RefCounted


func _init(target: Simulation, event_journal: RefCounted = null) -> void:
	journal = event_journal
	simulation = target


func is_active() -> bool:
	return _checkpoint != null


func begin() -> bool:
	if is_active() or _owners.has(simulation.state.get_instance_id()):
		error = "Nested transactions are unsupported"
		return false
	var candidate: RefCounted = Checkpoint.new()
	if not candidate.capture(simulation, journal):
		error = candidate.error
		return false
	_owners[simulation.state.get_instance_id()] = true
	_checkpoint = candidate
	error = ""
	return true


func advance(delta: float) -> bool:
	if not is_active() or not is_finite(delta) or delta < 0.0:
		error = "Advance requires an active transaction and finite nonnegative delta"
		return false
	simulation.update(delta, true)
	return true


func commit() -> bool:
	if not is_active():
		error = "Commit requires an active transaction"
		return false
	_owners.erase(simulation.state.get_instance_id())
	_checkpoint = null
	return true


func rollback() -> bool:
	if not is_active():
		error = "Rollback requires an active transaction"
		return false
	_checkpoint.restore()
	var restored: bool = _checkpoint.matches()
	if not restored:
		error = "Restoration contract failed"
		return false
	_owners.erase(simulation.state.get_instance_id())
	_checkpoint = null
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _checkpoint != null:
		_checkpoint.restore()
		_owners.erase(simulation.state.get_instance_id())
