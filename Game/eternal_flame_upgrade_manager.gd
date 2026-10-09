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
			0.15,
			10,
			2,
			2
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
	
	_add_upgrade(
		EternalFlameUpgrade.new(
			"essence_extraction",
			"Essence Extraction",
			"Unlocks the ability to research and extract the valuable Essence produced by Lava Mites.",
			EternalFlameUpgrade.EFFECT_UNLOCK_TECHNOLOGY,
			0.0,
			1,
			5,
			1.0,
			EternalFlameState.LAVA_MITE_ESSENCE_TECHNOLOGY_ID
		)
	)
	_add_upgrade(
		EternalFlameUpgrade.new(
			"accelerated_friction",
			"Accelerated Friction",
			"Begins each new realm with Atomic Friction at a higher level. Starting levels: 5, 10, 15, 20, and 25.",
			EternalFlameUpgrade.EFFECT_STARTING_GENERATOR_LEVEL,
			5.0,
			5,
			1,
			1.6,
			"",
			"",
			0,
			"atomic_friction"
		)
	)
	
	_add_upgrade(
		EternalFlameUpgrade.new(
			"accelerated_agitation",
			"Accelerated Agitation",
			"Begins each new realm with Molecular Agitation at a higher level. Starting levels: 5, 10, 15, 20, and 25.",
			EternalFlameUpgrade.EFFECT_STARTING_GENERATOR_LEVEL,
			5.0,
			5,
			10,
			1.5,
			"",
			"accelerated_friction",
			5,
			"molecular_agitation"
		)
	)

	_add_upgrade(
		EternalFlameUpgrade.new(
			"established_colony",
			"Established Colony",
			"Begins each new realm with an established Lava Mite Colony. Starting levels: 3, 6, 9, 12, and 15.",
			EternalFlameUpgrade.EFFECT_STARTING_GENERATOR_LEVEL,
			3.0,
			5,
			25,
			1.5,
			"",
			"accelerated_agitation",
			2,
			"lava_mite_colony"
		)
	)

	_add_upgrade(
		EternalFlameUpgrade.new(
			"accelerated_condensation",
			"Accelerated Condensation",
			"Begins each new realm with Infernal Condensation at a higher level. Starting levels: 3, 6, 9, 12, and 15.",
			EternalFlameUpgrade.EFFECT_STARTING_GENERATOR_LEVEL,
			3.0,
			5,
			40,
			1.4,
			"",
			"accelerated_agitation",
			5,
			"thermal_furnace"
		)
	)
	# --------------------------------------------------------
	# GENERATOR AUTOMATION
	# --------------------------------------------------------

	_add_generator_automation_upgrades(
		"atomic_friction",
		"Atomic Friction",
		3,
		2
	)

	_add_generator_automation_upgrades(
		"molecular_agitation",
		"Molecular Agitation",
		8,
		5
	)

	_add_generator_automation_upgrades(
		"thermal_furnace",
		"Infernal Condensation",
		12,
		8
	)

	_add_generator_automation_upgrades(
		"thermal_compressor",
		"Thermal Compressor",
		35,
		20
	)

	_add_generator_automation_upgrades(
		"lava_mite_colony",
		"Lava Mite Colony",
		25,
		15
	)

	_add_generator_automation_upgrades(
		"matter_furnace",
		"Matter Furnace",
		40,
		25
	)	
	

	# --------------------------------------------------------
	# GENERATOR UPGRADE AUTOMATION
	# --------------------------------------------------------

	_add_upgrade_automation_upgrade("atomic_friction", "Atomic Friction", 3)
	_add_upgrade_automation_upgrade("molecular_agitation", "Molecular Agitation", 8)
	_add_upgrade_automation_upgrade("thermal_furnace", "Infernal Condensation", 12)
	_add_upgrade_automation_upgrade("lava_mite_colony", "Lava Mite Colony", 25)
	_add_upgrade_automation_upgrade("matter_furnace", "Matter Furnace", 40)


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

	var upgrade = get_upgrade(upgrade_id)

	if upgrade == null:
		return false

	var current_level = state.get_upgrade_level(
		upgrade_id
	)

	if current_level >= upgrade.max_level:
		return false

	# Check prerequisite permanent upgrade.
	if upgrade.prerequisite_upgrade_id != "":
		var prerequisite = get_upgrade(
			upgrade.prerequisite_upgrade_id
		)

		if prerequisite == null:
			return false

		var prerequisite_level = state.get_upgrade_level(
			upgrade.prerequisite_upgrade_id
		)

		if prerequisite_level < upgrade.prerequisite_level:
			return false

	var cost = get_upgrade_cost(
		upgrade_id,
		state
	)

	if cost <= 0:
		return false

	return state.can_spend_flames(
		cost,
		realm_configuration
	)

func purchase(
	upgrade_id: String,
	state: EternalFlameState,
	realm_configuration: RealmConfiguration,
	game_state: GameState = null
	) -> bool:

	if not can_purchase(
		upgrade_id,
		state,
		realm_configuration,
	):
		return false

	var upgrade = get_upgrade(
		upgrade_id
	)

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

	if upgrade.effect_type == EternalFlameUpgrade.EFFECT_UNLOCK_TECHNOLOGY:
		state.unlock_technology(
			upgrade.technology_id
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
func _add_generator_automation_upgrades(
	generator_id: String,
	generator_name: String,
	unlock_cost: int,
	cooldown_cost: int
) -> void:

	var unlock_upgrade_id = (
		"unlock_generator_automation_" + generator_id
	)

	var technology_id = (
		"generator_automation_" + generator_id
	)

	# Permanent automation unlock.
	_add_upgrade(
		EternalFlameUpgrade.new(
			unlock_upgrade_id,
			generator_name + " Automation",
			"Permanently unlocks automatic purchasing for "
			+ generator_name + ".",
			EternalFlameUpgrade.EFFECT_UNLOCK_TECHNOLOGY,
			0.0,
			1,
			unlock_cost,
			1.0,
			technology_id
		)
	)

	# Permanent cooldown reduction, requiring the unlock.
	_add_upgrade(
		EternalFlameUpgrade.new(
			"generator_automation_cooldown_" + generator_id,
			generator_name + " Automation Speed",
			"Reduces the automatic purchase cooldown by 20% "
			+ "per level. Minimum cooldown: 0.5 seconds.",
			EternalFlameUpgrade.EFFECT_AUTOMATION_COOLDOWN,
			0.2,
			5,
			cooldown_cost,
			1.7,
			"",
			unlock_upgrade_id,
			1
		)
	)


func _add_upgrade_automation_upgrade(
	generator_id: String,
	generator_name: String,
	unlock_cost: int
) -> void:
	var upgrade_id: String = "unlock_upgrade_automation_" + generator_id
	var technology_id: String = "upgrade_automation_" + generator_id

	_add_upgrade(
		EternalFlameUpgrade.new(
			upgrade_id,
			generator_name + " Upgrade Automation",
			"Permanently unlocks automatic purchasing for " + generator_name + " upgrades.",
			EternalFlameUpgrade.EFFECT_UNLOCK_TECHNOLOGY,
			0.0,
			1,
			unlock_cost,
			1.0,
			technology_id
		)
	)
