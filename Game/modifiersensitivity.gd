class_name ModifierSensitivity
extends RefCounted


var modifier_id: String
var multiplier: float
var source_upgrade_id: String


func _init(
	sensitivity_modifier_id: String,
	sensitivity_multiplier: float,
	sensitivity_source_upgrade_id: String = ""
) -> void:
	modifier_id = sensitivity_modifier_id
	multiplier = sensitivity_multiplier
	source_upgrade_id = sensitivity_source_upgrade_id
