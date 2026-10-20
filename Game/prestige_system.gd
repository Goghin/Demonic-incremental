class_name PrestigeSystem
extends RefCounted


func _get_new_realm_layout_id(prestige_count: int) -> String:
	var layout_ids: Array[String] = RealmLayoutRegistry.get_layout_ids()
	if layout_ids.is_empty():
		return "default"
	return layout_ids[posmod(prestige_count - 1, layout_ids.size())]


func calculate_eternal_flame_gain(state: GameState) -> float:
	var crystallized_flame: float = state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME)
	var infernal_forge = state.get_generator("infernal_forge")
	if infernal_forge == null or crystallized_flame <= 0.0 or infernal_forge.level <= 0:
		return 0.0
	var forge_multiplier: float = sqrt(float(infernal_forge.level))
	return float(floori(crystallized_flame * forge_multiplier * state.get_overflow_bonus()))


# Completes the irreversible Smash without initializing the next realm.
func smash(state: GameState, run_duration: float = 0.0) -> float:
	if not state.realm_stabilized or state.prestige_planning:
		return 0.0
	var eternal_flame_gain: float = calculate_eternal_flame_gain(state)
	if eternal_flame_gain <= 0.0:
		return 0.0

	var next_prestige_count: int = state.eternal_flame_state.prestige_count + 1
	var crystallized_flame: float = state.get_resource_amount(ResourceIds.CRYSTALLIZED_FLAME)
	state.gameplay_log.record_event("prestige", "realm_smashed", {
		"eternal_flame_gained": eternal_flame_gain,
		"prestige_count": next_prestige_count,
		"crystallized_flame": crystallized_flame,
		"overflow": state.total_overflow_this_prestige,
		"overflow_bonus_used": state.get_overflow_bonus(),
		"layout_before_smash": state.realm_layout_id
	})

	var generators_reached: Array[String] = []
	for generator in state.generators.values():
		if generator.unlocked:
			generators_reached.append(generator.definition.display_name)
	state.last_prestige_report = {
		"survival_seconds": maxf(0.0, run_duration),
		"peak_heat": state.current_run_statistics.get_highest_amount(ResourceIds.HEAT),
		"peak_matter": state.current_run_statistics.get_highest_amount(ResourceIds.MATTER),
		"generators_reached": generators_reached,
		"crystallized_flame": crystallized_flame,
		"eternal_flames_gained": eternal_flame_gain,
		"prestige_count": next_prestige_count,
		"total_overflow": state.total_overflow_this_prestige
	}

	state.eternal_flame_state.eternal_flame += eternal_flame_gain
	state.eternal_flame_state.prestige_count = next_prestige_count
	if next_prestige_count == 1:
		for upgrade_id in ["eternal_furnace", "accelerated_friction"]:
			if state.eternal_flame_state.get_upgrade_level(upgrade_id) < 1:
				state.eternal_flame_state.set_upgrade_level(upgrade_id, 1)
	state.eternal_flame_state.total_crystallized_flame += crystallized_flame

	# The old realm is gone. Preserve its data only until the player chooses
	# to continue, while pausing simulation in the planning state.
	state.prestige_planning = true
	state.realm_stabilized = false
	state.realm_configuration.unlock()
	state.realm_effects.rebuild(
		state.realm_configuration,
		state.eternal_flame_state,
		state.eternal_flame_upgrade_manager,
		state.heat_leak_threshold,
		state.matter_decay_threshold
	)
	return eternal_flame_gain


func begin_next_realm(state: GameState) -> bool:
	if not state.prestige_planning:
		return false

	state.realm_layout_id = _get_new_realm_layout_id(state.eternal_flame_state.prestige_count)
	state.realm_layout = RealmLayoutRegistry.create_layout(state.realm_layout_id)
	state._generate_lava_palette()

	var realm_configuration: RealmConfiguration = state.realm_configuration
	state.reset_current_run()
	state.realm_stabilized = false
	realm_configuration.unlock()
	state.realm_effects.rebuild(
		realm_configuration,
		state.eternal_flame_state,
		state.eternal_flame_upgrade_manager,
		state.heat_leak_threshold,
		state.matter_decay_threshold
	)
	state.prestige_planning = false
	return true
