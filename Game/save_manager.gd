
class_name SaveManager
extends RefCounted


const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 3


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
		"offline_time": time_manager.offline_time
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
	
	return true


func state_to_dictionary(
	state: GameState
	) -> Dictionary:
	
	var data = {
		"resources": {},
		"generators": {},
		"upgrades": {},
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
		"realm_stabilized": state.realm_stabilized
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
			"cycle_progress": generator.cycle_progress
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
	
	for resource_id in resources_data:
		if not state.resources.has(resource_id):
			continue
		
		state.set_resource_amount(
			resource_id,
			float(resources_data[resource_id])
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
			
	state.realm_effects.rebuild(
	state.realm_configuration,
	state.eternal_flame_state,
	state.eternal_flame_upgrade_manager,
	state.heat_leak_threshold,
	state.matter_decay_threshold
	)
	
	
	return true
