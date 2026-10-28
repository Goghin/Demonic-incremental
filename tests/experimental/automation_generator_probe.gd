extends GeneratorAutomationManager

# Diagnostic native execution only. This script is refused by the kernel.
var metrics: Dictionary = {"attempts": 0, "successful": 0, "failed": 0, "waiting_checks": 0, "waiting_refreshes": 0, "cooldown_decrements": 0, "ready_transitions": 0}


func _attempt_purchase(id: String, simulation: Simulation, checked: bool = false) -> void:
	metrics["attempts"] += 1
	var mark: int = state.gameplay_log.events.size()
	super(id, simulation, checked)
	if state.gameplay_log.events.size() > mark:
		metrics["successful"] += 1
	else:
		metrics["failed"] += 1


func _waiting_cost_needs_refresh(generator: Generator, automation: Dictionary) -> bool:
	metrics["waiting_checks"] += 1
	var refresh: bool = super(generator, automation)
	if refresh:
		metrics["waiting_refreshes"] += 1
	return refresh


func update(delta: float, simulation: Simulation, offline_mode: bool = false) -> void:
	var before: Dictionary = {}
	for id: String in automation_states:
		before[id] = float(automation_states[id]["remaining_cooldown"])
	super(delta, simulation, offline_mode)
	for id: String in automation_states:
		var after: float = float(automation_states[id]["remaining_cooldown"])
		if after < float(before[id]):
			metrics["cooldown_decrements"] += 1
		if float(before[id]) > 0.0 and after == 0.0:
			metrics["ready_transitions"] += 1
