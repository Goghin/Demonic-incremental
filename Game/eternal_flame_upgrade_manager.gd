class_name EternalFlameUpgradeManager
extends RefCounted


var upgrades: Dictionary = {}


func _init() -> void:
	_initialize_upgrades()


func _initialize_upgrades() -> void:
	upgrades.clear()
	
	_add_upgrade(
		EternalFlameUpgrade.new(
			"eternal_furnace",
			"Eternal Furnace",
			"An eternal flame burns beneath the realm, permanently increasing Heat production.",
			EternalFlameUpgrade.EFFECT_HEAT_PRODUCTION,
			0.05,
			10,
			2,
			1.8
		)
	)
	
	_add_upgrade(
		EternalFlameUpgrade.new(
			"realm_attunement",
			"Realm Attunement",
			"Strengthens the effects of Eternal Flames assigned to the realm.",
			EternalFlameUpgrade.EFFECT_ASSIGNED_FLAME,
			0.05,
			10,
			3,
			2.0
		)
	)
	
	_add_upgrade(
		EternalFlameUpgrade.new(
			"infernal_foundation",
			"Infernal Foundation",
			"Strengthens the latent power provided by Eternal Flames left unassigned.",
			EternalFlameUpgrade.EFFECT_UNASSIGNED_FLAME,
			0.05,
			10,
			3,
			2.0
		)
	)


func _add_upgrade(
	upgrade: EternalFlameUpgrade
	) -> void:
	
	upgrades[upgrade.id] = upgrade


func get_upgrade(
	upgrade_id: String
	) -> EternalFlameUpgrade:
	
	return upgrades.get(
		upgrade_id,
		null
	)


func get_upgrade_level(
	upgrade_id: String,
	state: EternalFlameState
	) -> int:
	
	return state.get_upgrade_level(
		upgrade_id
	)


func get_upgrade_cost(
	upgrade_id: String,
	state: EternalFlameState
	) -> int:
	
	var upgrade = get_upgrade(
		upgrade_id
	)
	
	if upgrade == null:
		return 0
	
	var level = state.get_upgrade_level(
		upgrade_id
	)
	
	if level >= upgrade.max_level:
		return 0
	
	return int(
		ceil(
			upgrade.base_cost
			* pow(
				upgrade.cost_multiplier,
				level
			)
		)
	)


func can_purchase(
	upgrade_id: String,
	state: EternalFlameState,
	realm_configuration: RealmConfiguration
	) -> bool:
	
	var upgrade = get_upgrade(
		upgrade_id
	)
	
	if upgrade == null:
		return false
	
	var current_level = state.get_upgrade_level(
		upgrade_id
	)
	
	if current_level >= upgrade.max_level:
		return false
	
	var cost = get_upgrade_cost(
		upgrade_id,
		state
	)
	
	return state.can_spend_flames(
		cost,
		realm_configuration
	)


func purchase(
	upgrade_id: String,
	state: EternalFlameState,
	realm_configuration: RealmConfiguration
	) -> bool:
	
	if not can_purchase(
		upgrade_id,
		state,
		realm_configuration
	):
		return false
	
	var cost = get_upgrade_cost(
		upgrade_id,
		state
	)
	
	if not state.spend_flames(
		cost,
		realm_configuration
	):
		return false
	
	state.increase_upgrade_level(
		upgrade_id
	)
	
	return true


func get_effective_bonus(
	upgrade_id: String,
	state: EternalFlameState
	) -> float:
	
	var upgrade = get_upgrade(
		upgrade_id
	)
	
	if upgrade == null:
		return 0.0
	
	var level = state.get_upgrade_level(
		upgrade_id
	)
	
	return (
		level
		* upgrade.effect_per_level
	)


func get_effective_multiplier(
	upgrade_id: String,
	state: EternalFlameState
	) -> float:
	
	return 1.0 + get_effective_bonus(
		upgrade_id,
		state
	)
