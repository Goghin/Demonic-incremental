class_name AchievementManager
extends RefCounted


signal achievement_unlocked(achievement_id: String)


var unlocked_achievements: Dictionary = {}
var seen_generator_ids: Dictionary = {}


func update(state: GameState) -> void:
	_record_unlocked_generators(state)

	for definition in AchievementRegistry.get_definitions():
		var achievement_id: String = str(
			definition.get("id", "")
		)

		if achievement_id == "":
			continue

		if bool(unlocked_achievements.get(achievement_id, false)):
			continue

		var progress: float = _get_progress(
			definition,
			state
		)
		var target: float = float(
			definition.get("target", 1.0)
		)

		if progress >= target:
			unlocked_achievements[achievement_id] = true
			achievement_unlocked.emit(achievement_id)


func is_unlocked(achievement_id: String) -> bool:
	return bool(
		unlocked_achievements.get(
			achievement_id,
			false
		)
	)


func get_progress(
	achievement_id: String,
	state: GameState
	) -> float:

	var definition: Dictionary = AchievementRegistry.get_definition(
		achievement_id
	)
	if definition.is_empty():
		return 0.0

	_record_unlocked_generators(state)
	return _get_progress(
		definition,
		state
	)


func get_target(achievement_id: String) -> float:
	var definition: Dictionary = AchievementRegistry.get_definition(
		achievement_id
	)
	return float(
		definition.get("target", 0.0)
	)


func get_unlocked_count() -> int:
	var count: int = 0
	for achievement_id in unlocked_achievements:
		if bool(unlocked_achievements[achievement_id]):
			count += 1
	return count


func get_total_count() -> int:
	return AchievementRegistry.get_definitions().size()


func to_dictionary() -> Dictionary:
	return {
		"unlocked_achievements": unlocked_achievements.duplicate(true),
		"seen_generator_ids": seen_generator_ids.duplicate(true)
	}


func from_dictionary(data: Dictionary) -> void:
	unlocked_achievements.clear()
	seen_generator_ids.clear()

	var unlocked_data = data.get(
		"unlocked_achievements",
		{}
	)
	if unlocked_data is Dictionary:
		for achievement_id in unlocked_data:
			if AchievementRegistry.get_definition(str(achievement_id)).is_empty():
				continue
			unlocked_achievements[str(achievement_id)] = bool(
				unlocked_data[achievement_id]
			)

	var generators_data = data.get(
		"seen_generator_ids",
		{}
	)
	if generators_data is Dictionary:
		for generator_id in generators_data:
			seen_generator_ids[str(generator_id)] = true


func _record_unlocked_generators(state: GameState) -> void:
	for generator in state.generators.values():
		if not generator.unlocked:
			continue

		seen_generator_ids[
			generator.definition.id
		] = true


func _get_progress(
	definition: Dictionary,
	state: GameState
	) -> float:

	match str(definition.get("progress_type", "")):
		"resource_produced":
			return state.resource_statistics.get_total_produced(
				str(definition.get("resource_id", ""))
			)
		"highest_resource":
			return state.resource_statistics.get_highest_amount(
				str(definition.get("resource_id", ""))
			)
		"unique_generators":
			return float(seen_generator_ids.size())
		"total_generator_levels":
			var total_levels: int = 0
			for generator in state.generators.values():
				total_levels += int(generator.level)
			return float(total_levels)
		"prestige_count":
			return float(state.eternal_flame_state.prestige_count)
		"eternal_flame":
			return state.eternal_flame_state.eternal_flame
		"total_crystallized_flame":
			return state.eternal_flame_state.total_crystallized_flame

	return 0.0
