extends "res://tests/experimental/resource_flow_offline.gd"

# Investigation-only subclass: guards/integration remain unchanged. No relaxed
# eligibility is advertised as an improvement when proof obligations coexist.
const Blockers = preload("res://tests/experimental/core_blockers.gd")
var survey: bool = false
var blocker_counts: Dictionary = {}
var combinations: Dictionary = {}
var sole_blocker_counts: Dictionary = {}
var detail_counts: Dictionary = {}
var survey_usec: int = 0
var survey_calls: int = 0


func guard() -> String:
	var reason: String = super()
	if not survey:
		return reason
	var start: int = Time.get_ticks_usec()
	var report: Dictionary = Blockers.inspect(simulation)
	var keys: Array = report["blockers"].keys()
	keys.sort()
	survey_calls += 1
	var signature: String = ",".join(keys)
	combinations[signature] = int(combinations.get(signature, 0)) + 1
	for key: String in keys:
		blocker_counts[key] = int(blocker_counts.get(key, 0)) + 1
		for detail: String in report["blockers"][key]:
			var name: String = key + "/" + detail
			detail_counts[name] = int(detail_counts.get(name, 0)) + 1
	if keys.size() == 1:
		sole_blocker_counts[keys[0]] = int(sole_blocker_counts.get(keys[0], 0)) + 1
	for key: String in report["context"]:
		for detail: String in report["context"][key]:
			var name: String = key + "/" + detail
			detail_counts[name] = int(detail_counts.get(name, 0)) + 1
	survey_usec += Time.get_ticks_usec() - start
	return reason


func run(seconds: float) -> Dictionary:
	blocker_counts.clear()
	combinations.clear()
	sole_blocker_counts.clear()
	detail_counts.clear()
	survey_usec = 0
	survey_calls = 0
	var result: Dictionary = super(seconds)
	if survey:
		result["simultaneous"] = {"calls": survey_calls, "usec": survey_usec, "counts": blocker_counts, "combinations": combinations, "sole": sole_blocker_counts, "details": detail_counts}
	return result
