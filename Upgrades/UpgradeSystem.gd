class_name UpgradeSystem
extends RefCounted


var state: GameState


func _init(
	game_state: GameState
	) -> void:
	
	state = game_state


# -------------------------------------------------------------------
# Requirements
# -------------------------------------------------------------------

func requirement_met(
	requirement: Requirement
	) -> bool:
	
	if requirement.type == RequirementTypes.RESOURCE:
		return state.get_resource_amount(
			requirement.target_id
		) >= requirement.value
	
	if requirement.type == RequirementTypes.GENERATOR_LEVEL:
		var generator = state.get_generator(
			requirement.target_id
		)
		
		if generator == null:
			return false
		
		return generator.level >= requirement.value
	
	if requirement.type == RequirementTypes.UPGRADE_PURCHASED:
		var upgrade = state.get_upgrade(
			requirement.target_id
		)
		
		if upgrade == null:
			return false
		
		return upgrade.is_purchased()
	
	if requirement.type == RequirementTypes.UPGRADE_LEVEL:
		var upgrade = state.get_upgrade(
			requirement.target_id
		)
		
		if upgrade == null:
			return false
		
		return upgrade.level >= requirement.value
	
	return false


func requirements_met(
	requirements: Array[Requirement]
	) -> bool:
	
	for requirement in requirements:
		if not requirement_met(
			requirement
		):
			return false
	
	return true


# -------------------------------------------------------------------
# Upgrade exclusivity
# -------------------------------------------------------------------

func upgrade_exclusivity_available(
	upgrade: Upgrade
	) -> bool:
	
	var group = upgrade.definition.exclusivity_group
	
	# An empty exclusivity group means the upgrade is not exclusive.
	if group == "":
		return true
	
	for other_upgrade in state.upgrades.values():
		if other_upgrade == upgrade:
			continue
		
		if not other_upgrade.is_purchased():
			continue
		
		if other_upgrade.definition.exclusivity_group != group:
			continue
		
		# Another upgrade has already claimed this exclusivity group.
		return false
	
	return true


func get_exclusive_upgrade(
	upgrade: Upgrade
	) -> Upgrade:
	
	var group = upgrade.definition.exclusivity_group
	
	if group == "":
		return null
	
	for other_upgrade in state.upgrades.values():
		if other_upgrade == upgrade:
			continue
		
		if not other_upgrade.is_purchased():
			continue
		
		if other_upgrade.definition.exclusivity_group != group:
			continue
		
		return other_upgrade
	
	return null


# -------------------------------------------------------------------
# Visibility
# -------------------------------------------------------------------

func is_upgrade_visible(
	upgrade: Upgrade
	) -> bool:
	
	var definition = upgrade.definition
	
	# Eternal Flame technology requirement.
	if definition.technology_id != "":
		if not state.eternal_flame_state.is_technology_unlocked(
			definition.technology_id
		):
			return false
	
	# No generator association means this is a global upgrade.
	if definition.generator_id == "":
		return true
	
	var generator = state.get_generator(
		definition.generator_id
	)
	
	if generator == null:
		return false
	
	return generator.unlocked
