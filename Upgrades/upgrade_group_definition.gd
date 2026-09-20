class_name UpgradeGroupDefinition
extends RefCounted


var id: String
var display_name: String
var description: String


func _init(
	group_id: String,
	group_name: String,
	group_description: String
	) -> void:
	
	id = group_id
	display_name = group_name
	description = group_description
