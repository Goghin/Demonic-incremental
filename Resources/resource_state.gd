class_name ResourceState
extends RefCounted


var definition: GameResource
var amount: float = 0.0


func _init(resource_definition: GameResource) -> void:
	definition = resource_definition
