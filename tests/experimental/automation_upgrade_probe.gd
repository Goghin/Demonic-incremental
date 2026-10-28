extends UpgradeAutomationManager

# Diagnostic native execution only. No purchase decision is duplicated.
var metrics: Dictionary = {"attempts": 0, "successful": 0, "failed": 0, "waiting_checks": 0, "cooldown_decrements": 0, "ready_transitions": 0}
var _ready_at_entry: Dictionary = {}


func _attempt_purchase(id: String, simulation: Simulation) -> bool:
	metrics["attempts"] += 1
	if _ready_at_entry.has(id):
		metrics["waiting_checks"] += 1
	var success: bool = super(id, simulation)
	metrics["successful" if success else "failed"] += 1
	return success


func update(delta: float, simulation: Simulation, offline_mode: bool = false) -> void:
	var before: Dictionary = {}
	_ready_at_entry.clear()
	for id: String in automation_states:
		var cooldown: float = float(automation_states[id]["remaining_cooldown"])
		before[id] = cooldown
		if cooldown <= 0.0:
			_ready_at_entry[id] = true
	super(delta, simulation, offline_mode)
	for id: String in automation_states:
		var after: float = float(automation_states[id]["remaining_cooldown"])
		if after < float(before[id]):
			metrics["cooldown_decrements"] += 1
		if float(before[id]) > 0.0 and after == 0.0:
			metrics["ready_transitions"] += 1
