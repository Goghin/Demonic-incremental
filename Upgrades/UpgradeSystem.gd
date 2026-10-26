class_name UpgradeSystem
extends RefCounted


# GameState owns this system. Keep only a weak back-reference so the two
# RefCounted objects do not keep each other alive indefinitely.
var _state_ref: WeakRef
var state: GameState:
	get:
		if _state_ref == null:
			return null
		return _state_ref.get_ref() as GameState
	set(value):
		_state_ref = weakref(value) if value != null else null


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

	# Hide upgrades tied to resources/mechanics the player has not discovered.
	if definition.discovery_id != "":
		if not _is_discovery_condition_met(definition.discovery_id):
			return false

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


func _is_discovery_condition_met(discovery_id: String) -> bool:
	# A mechanic may be discovered by obtaining a resource or purchasing the
	# upgrade that introduces it (for example, unlocking Crystallization).
	if discovery_id.begins_with("upgrade:"):
		var required_upgrade_id: String = discovery_id.trim_prefix("upgrade:")
		var required_upgrade: Upgrade = state.get_upgrade(required_upgrade_id)
		return required_upgrade != null and required_upgrade.is_purchased()
	return state.is_resource_discovered(discovery_id)
