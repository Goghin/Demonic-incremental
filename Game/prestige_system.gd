class_name PrestigeSystem
extends RefCounted


func _get_new_realm_layout_id(
	prestige_count: int
	) -> String:

	if prestige_count % 2 == 1:
		return "test"

	return "default"


func calculate_eternal_flame_gain(
	state: GameState
	) -> float:
	
	var crystallized_flame = state.get_resource_amount(
		ResourceIds.CRYSTALIZED_FLAME
	)
	
	var infernal_forge = state.get_generator(
		"infernal_forge"
	)
	
	if infernal_forge == null:
		return 0.0
	
	return crystallized_flame * infernal_forge.level


func smash(
	state: GameState
	) -> float:
	
	if not state.realm_stabilized:
		return 0.0
	
	var eternal_flame_gain = calculate_eternal_flame_gain(
		state
	)
	
	if eternal_flame_gain <= 0.0:
		return 0.0
	
	state.eternal_flame_state.eternal_flame += (
		eternal_flame_gain
	)
	
	if not state.eternal_flame_state.is_technology_unlocked(
		EternalFlameState.THERMAL_COMPRESSOR_TECHNOLOGY_ID
	):
		state.eternal_flame_state.unlock_technology(
			EternalFlameState.THERMAL_COMPRESSOR_TECHNOLOGY_ID
		)
	
	state.eternal_flame_state.prestige_count += 1
	
	# Select the physical layout for the new realm.
	state.realm_layout_id = _get_new_realm_layout_id(
		state.eternal_flame_state.prestige_count
	)
	
	state.realm_layout = RealmLayoutRegistry.create_layout(
		state.realm_layout_id
	)
	
	state.eternal_flame_state.total_crystallized_flame += (
		state.get_resource_amount(
			ResourceIds.CRYSTALIZED_FLAME
		)
	)
	
	# Preserve the current realm flame assignment.
	var realm_configuration = state.realm_configuration
	
	state.reset_current_run()
	
	# A new realm begins immediately after the smash.
	#
	# Keep all assigned flames exactly as they were,
	# but make the configuration editable again.
	state.realm_stabilized = false
	realm_configuration.unlock()
	
	state.realm_effects.rebuild(
		realm_configuration,
		state.eternal_flame_state,
		state.eternal_flame_upgrade_manager,
		state.heat_leak_threshold,
		state.matter_decay_threshold
	)
	
	return eternal_flame_gain
