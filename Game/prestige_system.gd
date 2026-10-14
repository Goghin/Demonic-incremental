class_name PrestigeSystem
extends RefCounted


func _get_new_realm_layout_id(
	prestige_count: int
	) -> String:

	var layout_ids: Array[String] = RealmLayoutRegistry.get_layout_ids()

	if layout_ids.is_empty():
		return "default"

	# prestige_count is incremented before this is called. Starting at index
	# zero makes the first completed prestige use the first registered layout.
	var layout_index: int = posmod(
		prestige_count - 1,
		layout_ids.size()
	)

	return layout_ids[layout_index]


func calculate_eternal_flame_gain(
	state: GameState
	) -> float:

	var crystallized_flame: float = (
		state.get_resource_amount(
			ResourceIds.CRYSTALIZED_FLAME
		)
	)

	var infernal_forge = state.get_generator(
		"infernal_forge"
	)

	if infernal_forge == null:
		return 0.0

	if crystallized_flame <= 0.0:
		return 0.0

	if infernal_forge.level <= 0:
		return 0.0

	var forge_multiplier: float = sqrt(
		float(infernal_forge.level)
	)

	var overflow_multiplier: float = (
		state.get_overflow_bonus()
	)

	var gain: float = (
		crystallized_flame
		* forge_multiplier
		* overflow_multiplier
	)

	return float(floori(gain))


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

	state.gameplay_log.record_event(
		"prestige",
		"realm_smashed",
		{
			"eternal_flame_gained": eternal_flame_gain,
			"prestige_count": state.eternal_flame_state.prestige_count + 1,
			"crystallized_flame": state.get_resource_amount(ResourceIds.CRYSTALIZED_FLAME),
			"overflow": state.total_overflow_this_prestige,
			"overflow_bonus_used": state.get_overflow_bonus(),
			"layout_before_smash": state.realm_layout_id
		}
	)

	state.eternal_flame_state.eternal_flame += (
		eternal_flame_gain
	)

	state.eternal_flame_state.prestige_count += 1

	# The first prestige grants the two foundational shop upgrades for free.
	# Apply these before resetting the run so Atomic Friction starts at its
	# upgraded level in the new realm.
	if state.eternal_flame_state.prestige_count == 1:
		for upgrade_id in ["eternal_furnace", "accelerated_friction"]:
			if state.eternal_flame_state.get_upgrade_level(upgrade_id) < 1:
				state.eternal_flame_state.set_upgrade_level(upgrade_id, 1)

	# Select the physical layout for the new realm.
	state.realm_layout_id = _get_new_realm_layout_id(
		state.eternal_flame_state.prestige_count
	)

	state.realm_layout = RealmLayoutRegistry.create_layout(
		state.realm_layout_id
	)
	# Palette changes only when a new realm is created by Smash.
	state._generate_lava_palette()

	state.eternal_flame_state.total_crystallized_flame += (
		state.get_resource_amount(
			ResourceIds.CRYSTALIZED_FLAME
		)
	)

	# Preserve the current realm flame assignment.
	var realm_configuration = state.realm_configuration

	state.reset_current_run()

	# A new realm begins immediately after the smash.
	# Keep assigned flames, but make the configuration editable.
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
