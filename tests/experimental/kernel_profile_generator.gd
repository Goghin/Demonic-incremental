extends Generator
var measured_usec: Dictionary = {}
var measured_calls: Dictionary = {}


func _init(config: GeneratorDefinition) -> void:
	super(config)


func _record(key: String, started: int) -> void:
	measured_usec[key] = int(measured_usec.get(key, 0)) + Time.get_ticks_usec() - started
	measured_calls[key] = int(measured_calls.get(key, 0)) + 1


func get_production_rate(output: GeneratorIO, state: GameState, mode: GeneratorOperationMode = null, heat_multiplier: float = -1.0) -> float:
	var started: int = Time.get_ticks_usec()
	var result: float = super.get_production_rate(output, state, mode, heat_multiplier)
	_record("get_production_rate", started)
	return result


func get_input_consumption_per_second(input: GeneratorIO, state: GameState, throttled_override: Variant = null) -> float:
	var started: int = Time.get_ticks_usec()
	var result: float = super.get_input_consumption_per_second(input, state, throttled_override)
	_record("get_input_consumption_per_second", started)
	return result


func get_modifier_sensitivity(modifier_id: String, state: GameState) -> float:
	var started: int = Time.get_ticks_usec()
	var result: float = super.get_modifier_sensitivity(modifier_id, state)
	_record("get_modifier_sensitivity", started)
	return result


func get_production_progress(resource_id: String) -> float:
	var started: int = Time.get_ticks_usec()
	var result: float = super.get_production_progress(resource_id)
	_record("get_production_progress", started)
	return result


func set_production_progress(resource_id: String, progress: float) -> void:
	var started: int = Time.get_ticks_usec()
	super.set_production_progress(resource_id, progress)
	_record("set_production_progress", started)
