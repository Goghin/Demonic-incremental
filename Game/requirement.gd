class_name Requirement
extends RefCounted


var type: String
var target_id: String
var value: float


func _init(
	requirement_type: String,
	requirement_target_id: String,
	requirement_value: float = 0.0
) -> void:
	type = requirement_type
	target_id = requirement_target_id
	value = requirement_value
