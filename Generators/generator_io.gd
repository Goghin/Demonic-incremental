class_name GeneratorIO
extends RefCounted


var resource_id: String
var amount_per_second: float
var discrete: bool
var unlocked: bool


func _init(
	io_resource_id: String,
	io_amount_per_second: float,
	io_discrete: bool = false,
	io_unlocked: bool = true
	) -> void:
	
	resource_id = io_resource_id
	amount_per_second = io_amount_per_second
	discrete = io_discrete
	unlocked = io_unlocked
