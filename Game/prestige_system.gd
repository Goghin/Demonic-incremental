class_name PrestigeSystem
extends RefCounted


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
	
	state.eternal_flame_state.total_crystallized_flame += (
		state.get_resource_amount(
			ResourceIds.CRYSTALIZED_FLAME
		)
	)
	
	state.reset_current_run()
	
	# The player now has to configure the next realm.
	state.begin_realm_configuration()
	
	return eternal_flame_gain
