class_name GameResource
extends RefCounted


var id: String
var display_name: String


func _init(resource_id: String, resource_name: String) -> void:
	id = resource_id
	display_name = resource_name
