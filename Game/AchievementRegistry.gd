class_name AchievementRegistry
extends RefCounted


const DEFINITIONS: Array[Dictionary] = [
	{
		"id": "first_spark",
		"title": "First Spark",
		"description": "Produce 1,000 Heat in total.",
		"progress_type": "resource_produced",
		"resource_id": ResourceIds.HEAT,
		"target": 1000.0
	},
	{
		"id": "matter_matters",
		"title": "Matter Matters",
		"description": "Accumulate 1,000 Matter at once.",
		"progress_type": "highest_resource",
		"resource_id": ResourceIds.MATTER,
		"target": 1000.0
	},
	{
		"id": "industrial_revolution",
		"title": "Industrial Revolution",
		"description": "Unlock five different generators across all Realms.",
		"progress_type": "unique_generators",
		"target": 5.0
	},
	{
		"id": "into_the_void",
		"title": "Into the Void",
		"description": "Smash your first Realm.",
		"progress_type": "prestige_count",
		"target": 1.0
	},
	{
		"id": "eternal_flame",
		"title": "Eternal Flame",
		"description": "Earn your first Eternal Flame.",
		"progress_type": "eternal_flame",
		"target": 1.0
	}
]


static func get_definitions() -> Array[Dictionary]:
	return DEFINITIONS.duplicate(true)


static func get_definition(achievement_id: String) -> Dictionary:
	for definition in DEFINITIONS:
		if str(definition.get("id", "")) == achievement_id:
			return definition.duplicate(true)

	return {}
