class_name SaveManager
extends RefCounted


const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 9


func save_game(
	state: GameState,
	time_manager: TimeManager
	) -> bool:
	
	var save_data = {
		"version": SAVE_VERSION,
		"game_state": state_to_dictionary(state),
		"last_real_timestamp": time_manager.get_current_timestamp(),
		"game_time": time_manager.game_time,
		"active_time": time_manager.active_time,
		"offline_time": time_manager.offline_time,
		"prestige_time": time_manager.prestige_time,
		"stabilization_countdown_active": (
			time_manager.stabilization_countdown_active
		),
		"stabilization_remaining": (
			time_manager.stabilization_remaining
		)
	}
	
	var file = FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)
	
	if file == null:
		return false
	
	file.store_string(
		JSON.stringify(save_data)
	)
	
	file.close()
	
	return true


func load_game(
	state: GameState,
	time_manager: TimeManager
	) -> bool:
	
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	
	var file = FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)
	
	if file == null:
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(
		json_text
	)
	
	if parse_result != OK:
		return false
	
	var save_data = json.data
	
	if not save_data is Dictionary:
		return false
	
	if not save_data.has("version"):
		return false
	
	var save_version = int(
		save_data["version"]
	)
	
	if save_version < 1:
		return false
	
	if save_version > SAVE_VERSION:
		return false
	
	if not save_data.has("game_state"):
		return false
	
	var game_state_data = save_data["game_state"]
	
	if not game_state_data is Dictionary:
		return false
	
	if not dictionary_to_state(
		state,
		game_state_data,
		save_version
	):
		return false
	
	if save_data.has("last_real_timestamp"):
		time_manager.last_real_timestamp = (
			int(save_data["last_real_timestamp"])
		)
	
	if save_data.has("game_time"):
		time_manager.game_time = float(
			save_data["game_time"]
		)
	
	if save_data.has("active_time"):
		time_manager.active_time = float(
			save_data["active_time"]
		)
	
	if save_data.has("offline_time"):
		time_manager.offline_time = float(
			save_data["offline_time"]
		)
	
	if save_data.has("prestige_time"):
		time_manager.prestige_time = float(
			save_data["prestige_time"]
		)
	
	if save_data.has("stabilization_countdown_active"):
		time_manager.stabilization_countdown_active = bool(
			save_data["stabilization_countdown_active"]
		)
	
	if save_data.has("stabilization_remaining"):
		time_manager.stabilization_remaining = max(
			0.0,
			float(
				save_data["stabilization_remaining"]
			)
		)
	
	# A stabilized realm can never have an active countdown.
	if state.realm_stabilized:
		time_manager.cancel_stabilization_countdown()
	
	return true


func state_to_dictionary(
	state: GameState
	) -> Dictionary:
	
	var data = {
		# JSON numbers cannot safely represent every 64-bit RNG value.
		"gameplay_rng": {"seed": str(state.gameplay_rng.seed), "state": str(state.gameplay_rng.state)},
		"resources": {},
		"generators": {},
		"upgrades": {},
		"resource_statistics": state.resource_statistics.to_dictionary(),
		"current_run_statistics": state.current_run_statistics.to_dictionary(),
		"discovered_resources": state.get_discovered_resources_save_data(),
		"achievements": state.achievement_manager.to_dictionary(),
		"relic_manager": state.relic_manager.get_save_data(),
		"eternal_flame_state": {
			"eternal_flame": state.eternal_flame_state.eternal_flame,
			"spent_flames": state.eternal_flame_state.spent_flames,
			"prestige_count": state.eternal_flame_state.prestige_count,
			"total_crystallized_flame": state.eternal_flame_state.total_crystallized_flame,
			"upgrade_levels": state.eternal_flame_state.upgrade_levels,
			"unlocked_technologies": state.eternal_flame_state.unlocked_technologies
		},
		"realm_configuration": {
			"stability": state.realm_configuration.stability,
			"density": state.realm_configuration.density,
			"integrity": state.realm_configuration.integrity,
			"intensity": state.realm_configuration.intensity,
			"resonance": state.realm_configuration.resonance,
			"locked": state.realm_configuration.locked
		},
		"realm_layout_id": state.realm_layout_id,
		"lava_palette": state.get_lava_palette_save_data(),
		"realm_stabilized": state.realm_stabilized,
		"prestige_planning": state.prestige_planning,
		"last_prestige_report": state.last_prestige_report,
		"total_overflow_this_prestige": state.total_overflow_this_prestige,
		"total_matter_decayed_this_prestige": state.total_matter_decayed_this_prestige,
		"generator_automation": (
			state.generator_automation_manager.get_save_data()
		),
		"upgrade_automation": (
			state.upgrade_automation_manager.get_save_data()
		),
	}
	
	for resource in state.get_resources().values():
		var resource_id = resource.definition.id
		
		data["resources"][resource_id] = (
			state.get_resource_amount(
				resource_id
			)
		)
	
	for generator in state.get_generators().values():
		var generator_id = generator.definition.id
		
		data["generators"][generator_id] = {
			"level": generator.level,
			"unlocked": generator.unlocked,
			"production_progress": generator.production_progress,
			"manually_paused": generator.manually_paused,
			"cycle_active": generator.cycle_active,
			"cycle_progress": generator.cycle_progress,
			"cycle_critical_chance_snapshot": _encode_chance_snapshot(generator.cycle_critical_chance_snapshot if generator.cycle_active else -1.0),
			"operation_mode_id": generator.operation_mode_id,
			"auto_run_cycles": generator.auto_run_cycles
		}
	
	for upgrade in state.upgrades.values():
		var upgrade_id = upgrade.definition.id
		
		data["upgrades"][upgrade_id] = {
			"level": upgrade.level
		}
	
	return data


func dictionary_to_state(
	state: GameState,
	data: Dictionary,
	save_version: int
	) -> bool:
	
	if not data.has("resources"):
		return false
	
	if not data.has("generators"):
		return false
	
	if not data.has("upgrades"):
		return false
	
	# --------------------------------------------------------
	# RESOURCES
	# --------------------------------------------------------
	
	var resources_data = data["resources"]
	
	if not resources_data is Dictionary:
		return false
	
	# Restore before any load-time gameplay reward (such as starter backfill).
	# Legacy saves retain the stream initialized once by GameState._init().
	if data.has("gameplay_rng"):
		var rng_data: Variant = data["gameplay_rng"]
		if not rng_data is Dictionary:
			return false
		if not _is_rng_integer(rng_data.get("seed")) or not _is_rng_integer(rng_data.get("state")):
			return false
		state.gameplay_rng.seed = str(rng_data["seed"]).to_int()
		state.gameplay_rng.state = str(rng_data["state"]).to_int()
	elif save_version >= 9:
		return false

	# Migrate the old misspelled resource ID used by existing saves.
	if resources_data.has("Crystalized Flame"):
		if not resources_data.has("Crystallized Flame"):
			resources_data["Crystallized Flame"] = resources_data["Crystalized Flame"]
		resources_data.erase("Crystalized Flame")

	for resource_id in resources_data:
		if not state.resources.has(resource_id):
			continue
		
		state.set_resource_amount(
			resource_id,
			float(resources_data[resource_id])
		)
		
	var resource_statistics_data = data.get(
		"resource_statistics",
		{}
	)

	if resource_statistics_data is Dictionary:
		_migrate_crystallized_flame_statistic_id(resource_statistics_data)
		state.resource_statistics.from_dictionary(
			resource_statistics_data
		)


	var current_run_statistics_data = data.get(
		"current_run_statistics",
		{}
	)

	if current_run_statistics_data is Dictionary:
		_migrate_crystallized_flame_statistic_id(current_run_statistics_data)
		state.current_run_statistics.from_dictionary(
			current_run_statistics_data
		)

	var discovered_resources_data = data.get("discovered_resources", {})
	if discovered_resources_data is Dictionary:
		state.restore_discovered_resources(discovered_resources_data)
	state.reconcile_resource_discovery()

	# --------------------------------------------------------
	# OVERFLOW
	# --------------------------------------------------------

	state.total_overflow_this_prestige = max(
		0.0,
		float(data.get("total_overflow_this_prestige", 0.0))
	)
	state.total_matter_decayed_this_prestige = max(
		0.0,
		float(data.get("total_matter_decayed_this_prestige", 0.0))
	)

	state.overflow_bonus_from_last_realm = max(
		1.0,
		float(data.get("overflow_bonus_from_last_realm", 0.0))
	)
	# --------------------------------------------------------
	# ETERNAL FLAME
	# --------------------------------------------------------
	
	if data.has("eternal_flame_state"):
		var eternal_flame_data = data["eternal_flame_state"]
		
		if eternal_flame_data is Dictionary:
			if eternal_flame_data.has("eternal_flame"):
				state.eternal_flame_state.eternal_flame = float(
					eternal_flame_data["eternal_flame"]
				)
			
			if eternal_flame_data.has("prestige_count"):
				state.eternal_flame_state.prestige_count = int(
					eternal_flame_data["prestige_count"]
				)
			
			if eternal_flame_data.has("total_crystallized_flame"):
				state.eternal_flame_state.total_crystallized_flame = float(
					eternal_flame_data["total_crystallized_flame"]
				)
			
			if eternal_flame_data.has("spent_flames"):
				state.eternal_flame_state.spent_flames = float(
					eternal_flame_data["spent_flames"]
				)
			
			if eternal_flame_data.has("upgrade_levels"):
				var upgrade_levels_data = (
					eternal_flame_data["upgrade_levels"]
				)
				
				if upgrade_levels_data is Dictionary:
					state.eternal_flame_state.upgrade_levels.clear()
					
					for upgrade_id in upgrade_levels_data:
						state.eternal_flame_state.upgrade_levels[upgrade_id] = int(
							upgrade_levels_data[upgrade_id]
						)
			
			if eternal_flame_data.has("unlocked_technologies"):
				var unlocked_technologies_data = (
					eternal_flame_data["unlocked_technologies"]
				)
				
				if unlocked_technologies_data is Dictionary:
					state.eternal_flame_state.unlocked_technologies.clear()
					
					for technology_id in unlocked_technologies_data:
						state.eternal_flame_state.unlocked_technologies[technology_id] = bool(
							unlocked_technologies_data[technology_id]
						)
	
	# --------------------------------------------------------
	# REALM CONFIGURATION
	# --------------------------------------------------------
	
	if data.has("realm_configuration"):
		var realm_configuration_data = data["realm_configuration"]
		
		if realm_configuration_data is Dictionary:
			if realm_configuration_data.has("stability"):
				state.realm_configuration.stability = int(
					realm_configuration_data["stability"]
				)
			
			if realm_configuration_data.has("density"):
				state.realm_configuration.density = int(
					realm_configuration_data["density"]
				)
			
			if realm_configuration_data.has("integrity"):
				state.realm_configuration.integrity = int(
					realm_configuration_data["integrity"]
				)
			
			if realm_configuration_data.has("intensity"):
				state.realm_configuration.intensity = int(
					realm_configuration_data["intensity"]
				)
			
			if realm_configuration_data.has("resonance"):
				state.realm_configuration.resonance = int(
					realm_configuration_data["resonance"]
				)
			
			if realm_configuration_data.has("locked"):
				state.realm_configuration.locked = bool(
					realm_configuration_data["locked"]
				)
	
	if data.has("realm_stabilized"):
		state.realm_stabilized = bool(
			data["realm_stabilized"]
		)

	state.prestige_planning = bool(data.get("prestige_planning", false))
	var report_data = data.get("last_prestige_report", {})
	state.last_prestige_report = report_data.duplicate(true) if report_data is Dictionary else {}
		# --------------------------------------------------------
	# REALM LAYOUT
	# --------------------------------------------------------

	state.realm_layout_id = str(
		data.get(
			"realm_layout_id",
			"default"
		)
	)

	state.realm_layout = RealmLayoutRegistry.create_layout(
		state.realm_layout_id
	)
	# Older saves have no palette; retain the one generated for this load.
	var lava_palette_data = data.get("lava_palette", {})
	if lava_palette_data is Dictionary and not lava_palette_data.is_empty():
		state.set_lava_palette_from_save_data(lava_palette_data)
	# --------------------------------------------------------
	# GENERATORS
	# --------------------------------------------------------
	
	var generators_data = data["generators"]
	
	if not generators_data is Dictionary:
		return false
	
	for generator_id in generators_data:
		if not state.generators.has(generator_id):
			continue
		
		var generator_data = generators_data[generator_id]
		
		if not generator_data is Dictionary:
			continue
		
		var generator = state.generators[generator_id]
		
		if generator_data.has("level"):
			generator.level = int(
				generator_data["level"]
			)
		
		if generator_data.has("unlocked"):
			generator.unlocked = bool(
				generator_data["unlocked"]
			)
		
		if generator_data.has("production_progress"):
			var progress_data = (
				generator_data["production_progress"]
			)
			
			if progress_data is Dictionary:
				generator.production_progress.clear()
				
				for resource_id in progress_data:
					generator.production_progress[resource_id] = float(
						progress_data[resource_id]
					)
		
		if generator_data.has("manually_paused"):
			generator.manually_paused = bool(
				generator_data["manually_paused"]
			)
		
		if generator_data.has("cycle_active"):
			generator.cycle_active = bool(
				generator_data["cycle_active"]
			)
		
		if generator_data.has("cycle_progress"):
			generator.cycle_progress = float(
				generator_data["cycle_progress"]
			)
		generator.cycle_critical_chance_snapshot = -1.0
		if generator.cycle_active and generator_data.has("cycle_critical_chance_snapshot"):
			var snapshot: Variant = generator_data["cycle_critical_chance_snapshot"]
			if snapshot is String:
				if not snapshot.begins_with("f64:") or snapshot.length() != 20:
					return false
				for character in snapshot.substr(4):
					if not "0123456789abcdef".contains(character):
						return false
				snapshot = snapshot.substr(4).hex_decode().decode_double(0)
			if not (snapshot is float or snapshot is int):
				return false
			var chance_snapshot: float = float(snapshot)
			if not is_finite(chance_snapshot) or (chance_snapshot != -1.0 and (chance_snapshot < 0.0 or chance_snapshot > 1.0)):
				return false
			generator.cycle_critical_chance_snapshot = chance_snapshot
		if generator_data.has("auto_run_cycles"):
			generator.auto_run_cycles = bool(generator_data["auto_run_cycles"])
			
		if generator_data.has("operation_mode_id"):
			var operation_mode_id = str(
			generator_data["operation_mode_id"]
			)
	
			generator.load_operation_mode(
			operation_mode_id
			)
	# --------------------------------------------------------
	# UPGRADES
	# --------------------------------------------------------
	
	var upgrades_data = data["upgrades"]
	
	if not upgrades_data is Dictionary:
		return false
	
	for upgrade_id in upgrades_data:
		if not state.upgrades.has(upgrade_id):
			continue
		
		var upgrade_data = upgrades_data[upgrade_id]
		
		if not upgrade_data is Dictionary:
			continue
		
		var upgrade = state.upgrades[upgrade_id]
		
		if save_version == 1:
			# Version 1 stored a boolean called "purchased".
			# Convert it to the new level representation.
			if upgrade_data.has("purchased"):
				if bool(upgrade_data["purchased"]):
					upgrade.level = 1
				else:
					upgrade.level = 0
			
			continue
		
		if upgrade_data.has("level"):
			upgrade.level = int(
				upgrade_data["level"]
			)
	
	var achievement_data = data.get("achievements", {})
	if achievement_data is Dictionary:
		state.achievement_manager.from_dictionary(achievement_data)
	state.achievement_manager.update(state)

	var relic_manager_data: Variant = data.get("relic_manager", {})
	if relic_manager_data is Dictionary:
		state.relic_manager.load_save_data(relic_manager_data)
	if state.eternal_flame_upgrade_manager.is_reliquary_unlocked(state.eternal_flame_state):
		state.relic_manager.ensure_starter_relic()
	# Backfill milestone rewards for existing saves. This is idempotent and
	# uses lifetime progress, so spending Eternal Flames cannot revoke rewards.
	state.eternal_flame_upgrade_manager.apply_automatic_progression_rewards(
		state.eternal_flame_state
	)
	state.rebuild_relic_modifiers()

	state.rebuild_realm_effects()
	state.generator_automation_manager.load_save_data(
		data.get("generator_automation", {})
	)
	state.upgrade_automation_manager.load_save_data(
		data.get("upgrade_automation", {})
	)
	# Saved preferences cannot bypass the individual permanent shop unlocks.
	for generator in state.get_generators().values():
		if not state.eternal_flame_state.is_technology_unlocked(
			EternalFlameState.get_cycle_auto_run_technology_id(
				generator.definition.id
			)
		):
			generator.auto_run_cycles = false
	return true


func _encode_chance_snapshot(chance: float) -> String:
	# Avoid JSON decimal parsing roundoff in the activation-time probability.
	var encoded := PackedByteArray()
	encoded.resize(8)
	encoded.encode_double(0, chance)
	return "f64:" + encoded.hex_encode()


func _is_rng_integer(value: Variant) -> bool:
	# Require the canonical integer strings written above; reject overflow,
	# fractional values and already-rounded JSON numbers instead of reseeding.
	if not value is String or not value.is_valid_int():
		return false
	var digits: String = value.trim_prefix("-")
	var limit: String = "9223372036854775808" if value.begins_with("-") else "9223372036854775807"
	if digits.length() > limit.length() or (digits.length() == limit.length() and digits > limit):
		return false
	return str(value.to_int()) == value


func _migrate_crystallized_flame_statistic_id(data: Dictionary) -> void:
	# ResourceStatistics stores resource IDs as dictionary keys.
	if not data.has("Crystalized Flame"):
		return

	if not data.has("Crystallized Flame"):
		data["Crystallized Flame"] = data["Crystalized Flame"]

	data.erase("Crystalized Flame")
