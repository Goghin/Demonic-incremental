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
	
	var eternal_flame_gain = calculate_eternal_flame_gain(
		state
	)
	
	state.eternal_flame_state.eternal_flame += eternal_flame_gain
	state.eternal_flame_state.prestige_count += 1
	state.eternal_flame_state.total_crystallized_flame += state.get_resource_amount(
		ResourceIds.CRYSTALIZED_FLAME
	)
	
	state.reset_current_run()
	
	return eternal_flame_gain
