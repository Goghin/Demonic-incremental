class_name ResourceStatistics
extends RefCounted


var statistics: Dictionary = {}
var total_overflow: float = 0.0


func record_produced(
	resource_id: String,
	amount: float
) -> void:
	if amount <= 0.0:
		return

	_ensure_resource(resource_id)
	statistics[resource_id]["total_produced"] += amount


func record_consumed(
	resource_id: String,
	amount: float
) -> void:
	if amount <= 0.0:
		return

	_ensure_resource(resource_id)
	statistics[resource_id]["total_consumed"] += amount


func record_lost(
	resource_id: String,
	amount: float
) -> void:
	if amount <= 0.0:
		return

	_ensure_resource(resource_id)
	statistics[resource_id]["total_lost"] += amount


func record_overflow(amount: float) -> void:
	if amount <= 0.0:
		return

	total_overflow += amount


func get_total_overflow() -> float:
	return total_overflow


func update_highest(
	resource_id: String,
	amount: float
) -> void:
	_ensure_resource(resource_id)

	statistics[resource_id]["highest_amount"] = max(
		statistics[resource_id]["highest_amount"],
		amount
	)


func get_total_produced(
	resource_id: String
) -> float:
	if not statistics.has(resource_id):
		return 0.0

	return statistics[resource_id]["total_produced"]


func get_total_consumed(
	resource_id: String
) -> float:
	if not statistics.has(resource_id):
		return 0.0

	return statistics[resource_id]["total_consumed"]


func get_total_lost(
	resource_id: String
) -> float:
	if not statistics.has(resource_id):
		return 0.0

	return statistics[resource_id]["total_lost"]


func get_highest_amount(
	resource_id: String
) -> float:
	if not statistics.has(resource_id):
		return 0.0

	return statistics[resource_id]["highest_amount"]


func to_dictionary() -> Dictionary:
	var data = statistics.duplicate(true)
	data["_total_overflow"] = total_overflow

	return data


func from_dictionary(
	data: Dictionary
) -> void:
	statistics.clear()

	total_overflow = max(
		0.0,
		float(data.get("_total_overflow", 0.0))
	)

	for resource_id in data:
		if resource_id == "_total_overflow":
			continue

		var resource_data = data[resource_id]

		if not resource_data is Dictionary:
			continue

		statistics[resource_id] = {
			"total_produced": float(
				resource_data.get("total_produced", 0.0)
			),
			"total_consumed": float(
				resource_data.get("total_consumed", 0.0)
			),
			"total_lost": float(
				resource_data.get("total_lost", 0.0)
			),
			"highest_amount": float(
				resource_data.get("highest_amount", 0.0)
			)
		}


func reset() -> void:
	statistics.clear()
	total_overflow = 0.0


func _ensure_resource(
	resource_id: String
) -> void:
	if statistics.has(resource_id):
		return

	statistics[resource_id] = {
		"total_produced": 0.0,
		"total_consumed": 0.0,
		"total_lost": 0.0,
		"highest_amount": 0.0
	}
