class_name GeneratorRate
extends RefCounted


var resource_id: String
var amount_per_second: float
var discrete: bool


func _init(
	rate_resource_id: String,
	rate_amount_per_second: float,
	rate_discrete: bool = false
	) -> void:
	
	resource_id = rate_resource_id
	amount_per_second = rate_amount_per_second
	discrete = rate_discrete
