extends Modifier
var measured_usec: Dictionary = {}
var measured_calls: Dictionary = {}


func _record(key: String, started: int) -> void:
	measured_usec[key] = int(measured_usec.get(key, 0)) + Time.get_ticks_usec() - started
	measured_calls[key] = int(measured_calls.get(key, 0)) + 1


func get_effective_multiplier(state: GameState, generator: Generator) -> float:
	var started: int = Time.get_ticks_usec()
	var result: float = super.get_effective_multiplier(state, generator)
	_record("effective_dynamic" if dynamic else "effective_static", started)
	return result


func get_multiplier(state: GameState) -> float:
	var started: int = Time.get_ticks_usec()
	var result: float = super.get_multiplier(state)
	_record("raw_dynamic" if dynamic else "raw_static", started)
	return result
