class_name EternalFlameState
extends RefCounted


const THERMAL_COMPRESSOR_TECHNOLOGY_ID: String = "thermal_compressor"
const LAVA_MITE_ESSENCE_TECHNOLOGY_ID: String = "lava_mite_essence"


var eternal_flame: float = 0.0
var spent_flames: float = 0.0

var prestige_count: int = 0
var total_crystallized_flame: float = 0.0

var upgrade_levels: Dictionary = {}
var unlocked_technologies: Dictionary = {}


func get_spendable_flames(
	realm_configuration: RealmConfiguration
	) -> int:
	
	return max(
		0,
		int(
			eternal_flame
			- spent_flames
			- realm_configuration.get_assigned_flames()
		)
	)


func get_unassigned_flames(
	realm_configuration: RealmConfiguration
	) -> int:
	
	return get_spendable_flames(
		realm_configuration
	)


func can_spend_flames(
	amount: int,
	realm_configuration: RealmConfiguration
	) -> bool:
	
	if amount < 0:
		return false
	
	return amount <= get_spendable_flames(
		realm_configuration
	)


func spend_flames(
	amount: int,
	realm_configuration: RealmConfiguration
	) -> bool:
	
	if not can_spend_flames(
		amount,
		realm_configuration
	):
		return false
	
	spent_flames += amount
	
	return true


func get_upgrade_level(
	upgrade_id: String
	) -> int:
	
	return int(
		upgrade_levels.get(
			upgrade_id,
			0
		)
	)


func increase_upgrade_level(
	upgrade_id: String
	) -> void:
	
	upgrade_levels[upgrade_id] = (
		get_upgrade_level(upgrade_id)
		+ 1
	)


func set_upgrade_level(
	upgrade_id: String,
	level: int
	) -> void:
	
	upgrade_levels[upgrade_id] = max(
		0,
		level
	)


func is_technology_unlocked(
	technology_id: String
	) -> bool:
	
	return bool(
		unlocked_technologies.get(
			technology_id,
			false
		)
	)


func unlock_technology(
	technology_id: String
	) -> void:
	
	unlocked_technologies[technology_id] = true


func reset() -> void:
	eternal_flame = 0.0
	spent_flames = 0.0
	prestige_count = 0
	total_crystallized_flame = 0.0
	upgrade_levels.clear()
	unlocked_technologies.clear()
