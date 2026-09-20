class_name Upgrade
extends RefCounted


var definition: UpgradeDefinition
var level: int = 0


func _init(upgrade_definition: UpgradeDefinition) -> void:
	definition = upgrade_definition


func is_purchased() -> bool:
	return level > 0


func is_maxed() -> bool:
	return level >= definition.max_level


func can_upgrade() -> bool:
	return not is_maxed()
