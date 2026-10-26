class_name EternalFlameUpgradeManager
extends RefCounted


var upgrades: Dictionary = {}


func _init() -> void:
	_initialize_upgrades()


func _initialize_upgrades() -> void:
	upgrades.clear()
	
	# Permanent brazier progression: Intensity -> Stability -> Density -> Integrity -> Resonance.
	_add_upgrade(EternalFlameUpgrade.new("brazier_intensity", "Brazier I: Intensity", "Unlocks the first brazier and the Intensity flame stat for prestige planning.", EternalFlameUpgrade.EFFECT_UNLOCK_TECHNOLOGY, 0.0, 1, 1, 1.0, "brazier_intensity"))
	_add_upgrade(EternalFlameUpgrade.new("brazier_stability", "Brazier II: Stability", "Unlocks the second brazier and the Stability flame stat.", EternalFlameUpgrade.EFFECT_UNLOCK_TECHNOLOGY, 0.0, 1, 4, 1.0, "brazier_stability", "brazier_intensity", 1))
	_add_upgrade(EternalFlameUpgrade.new("brazier_density", "Brazier III: Density", "Unlocks the third brazier and the Density flame stat.", EternalFlameUpgrade.EFFECT_UNLOCK_TECHNOLOGY, 0.0, 1, 10, 1.0, "brazier_density", "brazier_stability", 1))
	_add_upgrade(EternalFlameUpgrade.new("brazier_integrity", "Brazier IV: Integrity", "Unlocks the fourth brazier and the Integrity flame stat.", EternalFlameUpgrade.EFFECT_UNLOCK_TECHNOLOGY, 0.0, 1, 20, 1.0, "brazier_integrity", "brazier_density", 1))
	_add_upgrade(EternalFlameUpgrade.new("brazier_resonance", "Brazier V: Resonance", "Unlocks the fifth brazier and the Resonance flame stat.", EternalFlameUpgrade.EFFECT_UNLOCK_TECHNOLOGY, 0.0, 1, 35, 1.0, "brazier_resonance", "brazier_integrity", 1))

	_add_upgrade(
		EternalFlameUpgrade.new(
			"eternal_furnace",
			"Eternal Furnace",
			"An eternal flame burns beneath the realm, permanently increasing Heat production.",
			EternalFlameUpgrade.EFFECT_HEAT_PRODUCTION,
			0.15,
			10,
			1,
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
			"thermal_compressor_technology",
			"Thermal Compression",
			"Permanently unlocks the Thermal Compressor technology, making its general unlock upgrade available.",
			EternalFlameUpgrade.EFFECT_UNLOCK_TECHNOLOGY,
			0.0,
			1,
			10,
			1.0,
			EternalFlameState.THERMAL_COMPRESSOR_TECHNOLOGY_ID
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
			1.0,
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
			2,
			1.0,
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
			3,
			1.0,
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
			4,
			1.0,
			"",
			"accelerated_agitation",
			5,
			"thermal_furnace"
		)
	)
	_add_relic_progression_upgrades()

	# Generator automation. Where a starting-level upgrade exists, it must be maxed first.
	_add_generator_automation_upgrades("atomic_friction", "Atomic Friction", 8, 2, "accelerated_friction")
	_add_generator_automation_upgrades("molecular_agitation", "Molecular Agitation", 15, 3, "accelerated_agitation")
	_add_generator_automation_upgrades("thermal_furnace", "Infernal Condensation", 25, 3, "accelerated_condensation")
	_add_generator_automation_upgrades("lava_mite_colony", "Lava Mite Colony", 35, 4, "established_colony")
	_add_generator_automation_upgrades("matter_furnace", "Matter Furnace", 50, 4)
	_add_generator_automation_upgrades("thermal_compressor", "Thermal Compressor", 65, 5)

	# Upgrade autobuyers require their matching level autobuyer first.
	_add_upgrade_automation_upgrade("atomic_friction", "Atomic Friction", 15, "unlock_generator_automation_atomic_friction")
	_add_upgrade_automation_upgrade("molecular_agitation", "Molecular Agitation", 25, "unlock_generator_automation_molecular_agitation")
	_add_upgrade_automation_upgrade("thermal_furnace", "Infernal Condensation", 40, "unlock_generator_automation_thermal_furnace")
	_add_upgrade_automation_upgrade("lava_mite_colony", "Lava Mite Colony", 55, "unlock_generator_automation_lava_mite_colony")
	_add_upgrade_automation_upgrade("matter_furnace", "Matter Furnace", 75, "unlock_generator_automation_matter_furnace")
	_add_upgrade_automation_upgrade("thermal_compressor", "Thermal Compressor", 95, "unlock_generator_automation_thermal_compressor")
	_add_general_upgrade_automation_upgrade()
	# Cycle auto-run is unlocked separately for each cycle-based generator.
	_add_cycle_auto_run_upgrade("infernal_forge", "Infernal Forge", 30)
	_add_cycle_auto_run_upgrade("relic_shard_extractor", "Relic Shard Extractor", 45)
	_configure_automatic_progression_rewards()


func _add_cycle_auto_run_upgrade(
	generator_id: String,
	generator_name: String,
	unlock_cost: int
) -> void:
	var technology_id: String = EternalFlameState.get_cycle_auto_run_technology_id(
		generator_id
	)
	_add_upgrade(
		EternalFlameUpgrade.new(
			"unlock_cycle_auto_run_" + generator_id,
			generator_name + " Auto-run",
			"Permanently unlocks automatic cycle starting and restarting for "
			+ generator_name + ".",
			EternalFlameUpgrade.EFFECT_UNLOCK_TECHNOLOGY,
			0.0,
			1,
			unlock_cost,
			1.0,
			technology_id
		)
	)


func _configure_automatic_progression_rewards() -> void:
	# Starting levels are earned by completed prestige milestones. Each array
	# entry is the prestige count required for that upgrade level.
	_set_automatic_level_prestige_requirements(
		"accelerated_friction", [1, 2, 3, 4, 5]
	)
	_set_automatic_level_prestige_requirements(
		"accelerated_agitation", [2, 3, 4, 5, 6]
	)
	_set_automatic_level_prestige_requirements(
		"established_colony", [3, 4, 5, 6, 7]
	)
	_set_automatic_level_prestige_requirements(
		"accelerated_condensation", [4, 5, 6, 7, 8]
	)

	# Automation is earned from lifetime Eternal Flames created, not from the
	# amount currently unspent. The early generator autobuyers also wait until
	# their starting-level progression is complete.
	_set_automatic_unlock_requirement(
		"unlock_generator_automation_atomic_friction", 5, 8.0
	)
	_set_automatic_unlock_requirement(
		"unlock_generator_automation_molecular_agitation", 6, 15.0
	)
	_set_automatic_unlock_requirement(
		"unlock_generator_automation_thermal_furnace", 8, 25.0
	)
	_set_automatic_unlock_requirement(
		"unlock_generator_automation_lava_mite_colony", 7, 35.0
	)
	_set_automatic_unlock_requirement(
		"unlock_generator_automation_matter_furnace", 0, 50.0
	)
	_set_automatic_unlock_requirement(
		"unlock_generator_automation_thermal_compressor", 0, 65.0
	)

	# Upgrade autobuyers require their matching generator autobuyer as before.
	_set_automatic_unlock_requirement(
		"unlock_upgrade_automation_atomic_friction", 5, 15.0
	)
	_set_automatic_unlock_requirement(
		"unlock_upgrade_automation_molecular_agitation", 6, 25.0
	)
	_set_automatic_unlock_requirement(
		"unlock_upgrade_automation_thermal_furnace", 8, 40.0
	)
	_set_automatic_unlock_requirement(
		"unlock_upgrade_automation_lava_mite_colony", 7, 55.0
	)
	_set_automatic_unlock_requirement(
		"unlock_upgrade_automation_matter_furnace", 0, 75.0
	)
	_set_automatic_unlock_requirement(
		"unlock_upgrade_automation_thermal_compressor", 0, 95.0
	)
	_set_automatic_unlock_requirement(
		"unlock_upgrade_automation_general", 0, 50.0
	)


func _set_automatic_level_prestige_requirements(
	upgrade_id: String,
	prestige_requirements: Array[int]
) -> void:
	var upgrade: EternalFlameUpgrade = get_upgrade(upgrade_id)
	if upgrade == null:
		push_warning("Missing Eternal Flame upgrade for automatic milestones: " + upgrade_id)
		return
	upgrade.automatic_level_prestige_requirements = prestige_requirements.duplicate()


func _set_automatic_unlock_requirement(
	upgrade_id: String,
	minimum_prestiges: int,
	lifetime_eternal_flames: float
) -> void:
	var upgrade: EternalFlameUpgrade = get_upgrade(upgrade_id)
	if upgrade == null:
		push_warning("Missing Eternal Flame automation upgrade for automatic milestone: " + upgrade_id)
		return
	upgrade.automatic_min_prestiges = minimum_prestiges
	upgrade.automatic_total_eternal_flame_requirement = lifetime_eternal_flames


func apply_automatic_progression_rewards(
	state: EternalFlameState
) -> bool:
	if state == null:
		return false

	var any_changed: bool = false
	var changed_this_pass: bool = true
	while changed_this_pass:
		changed_this_pass = false
		for upgrade_variant in upgrades.values():
			var upgrade: EternalFlameUpgrade = upgrade_variant
			var target_level: int = _get_automatic_target_level(upgrade, state)
			if target_level <= state.get_upgrade_level(upgrade.id):
				continue

			# Preserve dependency order for automatic technology unlocks, while
			# allowing starting-level milestones to progress independently.
			if (
				upgrade.effect_type == EternalFlameUpgrade.EFFECT_UNLOCK_TECHNOLOGY
				and upgrade.prerequisite_upgrade_id != ""
				and state.get_upgrade_level(upgrade.prerequisite_upgrade_id) < upgrade.prerequisite_level
			):
				continue

			state.set_upgrade_level(upgrade.id, target_level)
			if upgrade.effect_type == EternalFlameUpgrade.EFFECT_UNLOCK_TECHNOLOGY:
				if upgrade.technology_id != "":
					state.unlock_technology(upgrade.technology_id)
			changed_this_pass = true
			any_changed = true

	return any_changed


func _get_automatic_target_level(
	upgrade: EternalFlameUpgrade,
	state: EternalFlameState
) -> int:
	if state.prestige_count < upgrade.automatic_min_prestiges:
		return 0
	if state.eternal_flame < upgrade.automatic_total_eternal_flame_requirement:
		return 0

	if not upgrade.automatic_level_prestige_requirements.is_empty():
		var target_level: int = 0
		for level_index in range(upgrade.automatic_level_prestige_requirements.size()):
			if state.prestige_count >= upgrade.automatic_level_prestige_requirements[level_index]:
				target_level = level_index + 1
		return mini(target_level, upgrade.max_level)

	if (
		upgrade.automatic_min_prestiges > 0
		or upgrade.automatic_total_eternal_flame_requirement > 0.0
	):
		return upgrade.max_level
	return 0


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




func is_automatic_progression_upgrade(upgrade_id: String) -> bool:
	var upgrade: EternalFlameUpgrade = get_upgrade(upgrade_id)
	if upgrade == null:
		return false
	return (
		not upgrade.automatic_level_prestige_requirements.is_empty()
		or upgrade.automatic_min_prestiges > 0
		or upgrade.automatic_total_eternal_flame_requirement > 0.0
	)


func get_automatic_progression_requirement_text(
	upgrade_id: String,
	state: EternalFlameState
) -> String:
	var upgrade: EternalFlameUpgrade = get_upgrade(upgrade_id)
	if upgrade == null or state == null:
		return ""

	if not upgrade.automatic_level_prestige_requirements.is_empty():
		var current_level: int = state.get_upgrade_level(upgrade_id)
		if current_level >= upgrade.automatic_level_prestige_requirements.size():
			return "All milestones reached"
		return "Prestige %d" % upgrade.automatic_level_prestige_requirements[current_level]

	var requirements: Array[String] = []
	if upgrade.automatic_min_prestiges > 0:
		requirements.append("Prestige %d" % upgrade.automatic_min_prestiges)
	if upgrade.automatic_total_eternal_flame_requirement > 0.0:
		requirements.append(
			"%d lifetime EF" % int(upgrade.automatic_total_eternal_flame_requirement)
		)
	return " + ".join(requirements)


func can_purchase(
	upgrade_id: String,
	state: EternalFlameState,
	realm_configuration: RealmConfiguration
	) -> bool:

	var upgrade = get_upgrade(upgrade_id)

	if upgrade == null:
		return false

	if is_automatic_progression_upgrade(upgrade_id):
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
	#game_state: GameState = null
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
func _add_relic_progression_upgrades() -> void:
	# The Reliquary includes Atomic Friction's first slot, making the
	# relic system usable immediately after its initial purchase.
	_add_upgrade(
		EternalFlameUpgrade.new(
			"reliquary",
			"The Reliquary",
			"Unlocks relic storage and equipment. Includes one relic slot for Atomic Friction.",
			EternalFlameUpgrade.EFFECT_UNLOCK_RELIQUARY,
			1.0,
			1,
			5,
			1.0,
			"",
			"",
			0,
			"atomic_friction"
		)
	)

	# Slot unlocks are configured as data. Each upgrade adds one slot to
	# one generator and is gated behind the previous progression milestone.
	var slot_upgrades: Array[Dictionary] = [
		{
			"id": "attunement_molecular_agitation",
			"name": "Molecular Agitation Attunement",
			"generator_id": "molecular_agitation",
			"cost": 3,
			"prerequisite_id": "reliquary"
		},
		{
			"id": "attunement_lava_mite_colony",
			"name": "Lava Mite Colony Attunement",
			"generator_id": "lava_mite_colony",
			"cost": 5,
			"prerequisite_id": "attunement_molecular_agitation"
		},
		{
			"id": "attunement_thermal_furnace",
			"name": "Infernal Condensation Attunement",
			"generator_id": "thermal_furnace",
			"cost": 8,
			"prerequisite_id": "attunement_lava_mite_colony"
		},
		{
			"id": "attunement_matter_furnace",
			"name": "Matter Furnace Attunement",
			"generator_id": "matter_furnace",
			"cost": 12,
			"prerequisite_id": "attunement_thermal_furnace"
		},
		{
			"id": "attunement_thermal_compressor",
			"name": "Arcane Compressor Attunement",
			"generator_id": "thermal_compressor",
			"cost": 18,
			"prerequisite_id": "attunement_matter_furnace"
		},
		{
			"id": "attunement_infernal_forge",
			"name": "Infernal Forge Attunement",
			"generator_id": "infernal_forge",
			"cost": 25,
			"prerequisite_id": "attunement_thermal_compressor"
		}
	]

	for slot_data in slot_upgrades:
		_add_upgrade(
			EternalFlameUpgrade.new(
				str(slot_data["id"]),
				str(slot_data["name"]),
				"Unlocks one relic slot for this generator.",
				EternalFlameUpgrade.EFFECT_UNLOCK_RELIC_SLOTS,
				1.0,
				1,
				int(slot_data["cost"]),
				1.0,
				"",
				str(slot_data["prerequisite_id"]),
				1,
				str(slot_data["generator_id"])
			)
		)


func is_reliquary_unlocked(state: EternalFlameState) -> bool:
	return state.get_upgrade_level("reliquary") > 0


func get_relic_slot_count(
	generator_id: String,
	state: EternalFlameState
	) -> int:
	if not is_reliquary_unlocked(state):
		return 0

	var slot_count: int = 0
	for upgrade_id in upgrades:
		var upgrade: EternalFlameUpgrade = upgrades[upgrade_id]
		if (
			upgrade.effect_type != EternalFlameUpgrade.EFFECT_UNLOCK_RELIC_SLOTS
			and upgrade.effect_type != EternalFlameUpgrade.EFFECT_UNLOCK_RELIQUARY
		):
			continue
		if upgrade.target_generator_id != generator_id:
			continue
		slot_count += int(
			state.get_upgrade_level(upgrade.id) * upgrade.effect_per_level
		)
	return slot_count


func _add_generator_automation_upgrades(
	generator_id: String,
	generator_name: String,
	unlock_cost: int,
	cooldown_cost: int,
	starting_level_upgrade_id: String = ""
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
			technology_id,
			starting_level_upgrade_id,
			5 if starting_level_upgrade_id != "" else 0
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
			1.5,
			"",
			unlock_upgrade_id,
			1
		)
	)


func _add_upgrade_automation_upgrade(
	generator_id: String,
	generator_name: String,
	unlock_cost: int,
	level_automation_upgrade_id: String
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
			technology_id,
			level_automation_upgrade_id,
			1
		)
	)



func _add_general_upgrade_automation_upgrade() -> void:
	_add_upgrade(
		EternalFlameUpgrade.new(
			"unlock_upgrade_automation_general",
			"General Upgrade Automation",
			"Permanently unlocks automatic purchasing for general upgrades. It buys one eligible upgrade every 10 seconds, following the existing upgrade requirements and costs.",
			EternalFlameUpgrade.EFFECT_UNLOCK_TECHNOLOGY,
			0.0,
			1,
			50,
			1.0,
			"upgrade_automation_general"
		)
	)
